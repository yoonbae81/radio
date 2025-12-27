"""
Tests for record.py program configuration parsing
Uses Python's built-in unittest framework
"""

import os
import unittest
from unittest.mock import patch
import sys

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from record import parse_programs_config, calculate_duration_from_time, parse_and_validate_args, is_today_scheduled, WEEKDAYS


class TestIsTodayScheduled(unittest.TestCase):
    """Test is_today_scheduled function"""
    
    @patch('datetime.datetime')
    def test_all_days(self, mock_datetime):
        """Test ALL / EVERY / *"""
        # Monday
        mock_datetime.now.return_value.weekday.return_value = 0
        self.assertTrue(is_today_scheduled('ALL'))
        self.assertTrue(is_today_scheduled('EVERY'))
        self.assertTrue(is_today_scheduled('*'))
        self.assertTrue(is_today_scheduled(''))
    
    @patch('datetime.datetime')
    def test_single_day(self, mock_datetime):
        """Test single day (e.g., MON)"""
        # Monday
        mock_datetime.now.return_value.weekday.return_value = 0
        self.assertTrue(is_today_scheduled('MON'))
        self.assertFalse(is_today_scheduled('TUE'))
        
        # Sunday
        mock_datetime.now.return_value.weekday.return_value = 6
        self.assertTrue(is_today_scheduled('SUN'))
        self.assertFalse(is_today_scheduled('MON'))
    
    @patch('datetime.datetime')
    def test_day_list(self, mock_datetime):
        """Test day list (e.g., MON,WED,FRI)"""
        # Monday
        mock_datetime.now.return_value.weekday.return_value = 0
        self.assertTrue(is_today_scheduled('MON,WED,FRI'))
        
        # Tuesday
        mock_datetime.now.return_value.weekday.return_value = 1
        self.assertFalse(is_today_scheduled('MON,WED,FRI'))
        
        # Wednesday
        mock_datetime.now.return_value.weekday.return_value = 2
        self.assertTrue(is_today_scheduled('MON,WED,FRI'))
    
    @patch('datetime.datetime')
    def test_day_range(self, mock_datetime):
        """Test day range (e.g., MON-FRI)"""
        # Monday
        mock_datetime.now.return_value.weekday.return_value = 0
        self.assertTrue(is_today_scheduled('MON-FRI'))
        
        # Friday
        mock_datetime.now.return_value.weekday.return_value = 4
        self.assertTrue(is_today_scheduled('MON-FRI'))
        
        # Saturday
        mock_datetime.now.return_value.weekday.return_value = 5
        self.assertFalse(is_today_scheduled('MON-FRI'))
    
    @patch('datetime.datetime')
    def test_wrap_around_range(self, mock_datetime):
        """Test wrap-around range (e.g., SAT-MON)"""
        # Saturday
        mock_datetime.now.return_value.weekday.return_value = 5
        self.assertTrue(is_today_scheduled('SAT-MON'))
        
        # Sunday
        mock_datetime.now.return_value.weekday.return_value = 6
        self.assertTrue(is_today_scheduled('SAT-MON'))
        
        # Monday
        mock_datetime.now.return_value.weekday.return_value = 0
        self.assertTrue(is_today_scheduled('SAT-MON'))
        
        # Tuesday
        mock_datetime.now.return_value.weekday.return_value = 1
        self.assertFalse(is_today_scheduled('SAT-MON'))


class TestParseProgramsConfig(unittest.TestCase):
    """Test parse_programs_config function"""
    
    @patch('record.is_today_scheduled', return_value=True)
    def test_single_program(self, mock_scheduled):
        """Test parsing single program"""
        with patch.dict(os.environ, {
            'PROGRAM1': '07:40-08:00|ALL|program1|Program Name #1|url1'
        }, clear=True):
            programs = parse_programs_config()
            
            self.assertEqual(len(programs), 1)
            self.assertIn('program1', programs)
            self.assertEqual(programs['program1']['name'], 'Program Name #1')
            self.assertEqual(programs['program1']['url'], 'url1')
            self.assertEqual(len(programs['program1']['schedule']), 1)
            self.assertEqual(programs['program1']['schedule'][0]['start'], '0740')
    
    @patch('record.is_today_scheduled', return_value=True)
    def test_multiple_programs(self, mock_scheduled):
        """Test parsing multiple programs"""
        with patch.dict(os.environ, {
            'PROGRAM1': '07:40-08:00|ALL|program1|Program Name #1|url1',
            'PROGRAM2': '08:00-08:20|MON-FRI|program2|Program Name #2|url2',
            'PROGRAM3': '20:00-20:20|SAT,SUN|program3|Program Name #3|url3'
        }, clear=True):
            programs = parse_programs_config()
            
            self.assertEqual(len(programs), 3)
            self.assertIn('program1', programs)
            self.assertIn('program2', programs)
            self.assertIn('program3', programs)
            
    def test_filtering_by_day(self):
        """Test that programs not scheduled for today are filtered out"""
        with patch.dict(os.environ, {
            'PROGRAM1': '07:40-08:00|MON|prog_mon|Monday Program',
            'PROGRAM2': '08:00-08:20|TUE|prog_tue|Tuesday Program',
            'STREAM_URL': 'http://example.com'
        }, clear=True):
            # Mock today as Monday
            with patch('record.is_today_scheduled', side_effect=lambda d: d == 'MON'):
                programs = parse_programs_config()
                self.assertEqual(len(programs), 1)
                self.assertIn('prog_mon', programs)
                self.assertNotIn('prog_tue', programs)
    
    def test_invalid_format_missing_fields(self):
        """Test invalid format with missing fields"""
        with patch.dict(os.environ, {
            'PROGRAM1': '07:40-08:00|MON|program1'  # Missing name
        }, clear=True):
            programs = parse_programs_config()
            self.assertEqual(len(programs), 0)
    
    def test_whitespace_handling(self):
        """Test that whitespace is properly trimmed"""
        with patch.dict(os.environ, {
            'PROGRAM1': ' 07:40-08:00 | MON | prog1 | Name | url '
        }, clear=True):
            with patch('record.is_today_scheduled', return_value=True):
                programs = parse_programs_config()
                self.assertIn('prog1', programs)
                self.assertEqual(programs['prog1']['name'], 'Name')
                self.assertEqual(programs['prog1']['days'], 'MON')


class TestCalculateDurationFromTime(unittest.TestCase):
    """Test calculate_duration_from_time function"""
    
    def test_basic_duration(self):
        """Test basic duration calculation"""
        duration = calculate_duration_from_time('0740', '0800')
        self.assertEqual(duration, 1200)  # 20 minutes * 60 seconds
    
    def test_one_hour_duration(self):
        """Test one hour duration"""
        duration = calculate_duration_from_time('0900', '1000')
        self.assertEqual(duration, 3600)  # 60 minutes * 60 seconds
    
    def test_overnight_duration(self):
        """Test duration spanning midnight"""
        duration = calculate_duration_from_time('2350', '0010')
        self.assertEqual(duration, 1200)  # 20 minutes * 60 seconds
    
    def test_same_time(self):
        """Test when start and end are the same"""
        duration = calculate_duration_from_time('0800', '0800')
        self.assertEqual(duration, 0)
    
    def test_short_duration(self):
        """Test short duration (1 minute)"""
        duration = calculate_duration_from_time('0800', '0801')
        self.assertEqual(duration, 60)


class TestParseAndValidateArgs(unittest.TestCase):
    """Test parse_and_validate_args function"""
    
    @patch('sys.argv', ['record.py', '30'])
    @patch.dict(os.environ, {'STREAM_URL': 'default_url'})
    def test_manual_duration(self):
        """Test manual duration from command line"""
        duration, start_time, url = parse_and_validate_args()
        self.assertEqual(duration, 1800)  # 30 minutes * 60 seconds
        self.assertEqual(url, 'default_url')
    
    @patch('sys.argv', ['record.py'])
    @patch.dict(os.environ, {
        'PROGRAM1': '07:40-08:00|ALL|program1|Program Name #1|url1'
    }, clear=True)
    @patch('time.strftime', return_value='0740')
    @patch('record.is_today_scheduled', return_value=True)
    def test_auto_duration_exact_match(self, mock_scheduled, mock_time):
        """Test auto duration with exact time match"""
        duration, start_time, url = parse_and_validate_args()
        self.assertEqual(duration, 1200)  # 20 minutes
        self.assertEqual(url, 'url1')
    
    @patch('sys.argv', ['record.py'])
    @patch.dict(os.environ, {
        'PROGRAM1': '07:40-08:00|ALL|program1|Program Name #1|url1'
    }, clear=True)
    @patch('time.strftime', return_value='0742')
    @patch('record.is_today_scheduled', return_value=True)
    def test_auto_duration_within_tolerance(self, mock_scheduled, mock_time):
        """Test auto duration within 5-minute tolerance"""
        duration, start_time, url = parse_and_validate_args()
        self.assertEqual(duration, 1200)  # 20 minutes
    
    @patch('sys.argv', ['record.py'])
    @patch.dict(os.environ, {
        'PROGRAM1': '07:40-08:00|ALL|program1|Program Name #1|url1'
    }, clear=True)
    @patch('time.strftime', return_value='0750')
    @patch('record.is_today_scheduled', return_value=True)
    def test_auto_duration_outside_tolerance(self, mock_scheduled, mock_time):
        """Test auto duration outside 5-minute tolerance"""
        with self.assertRaises(SystemExit):
            parse_and_validate_args()
    
    @patch('sys.argv', ['record.py'])
    @patch.dict(os.environ, {}, clear=True)
    def test_no_programs_configured(self):
        """Test when no programs are configured"""
        with self.assertRaises(SystemExit):
            parse_and_validate_args()
    
    @patch('sys.argv', ['record.py', 'invalid'])
    def test_invalid_duration_argument(self):
        """Test invalid duration argument"""
        with self.assertRaises(SystemExit):
            parse_and_validate_args()
    
    @patch('sys.argv', ['record.py', '-10'])
    def test_negative_duration(self):
        """Test negative duration argument"""
        with self.assertRaises(SystemExit):
            parse_and_validate_args()
    
    @patch('sys.argv', ['record.py'])
    @patch.dict(os.environ, {
        'PROGRAM1': '06:00-07:00|ALL|morning|Morning Show|url1',
        'PROGRAM2': '07:40-08:00|ALL|program1|Program Name #1|url2',
        'PROGRAM3': '18:00-19:00|ALL|evening|Evening Show|url3'
    }, clear=True)
    @patch('time.strftime', return_value='0740')
    @patch('record.is_today_scheduled', return_value=True)
    def test_multiple_programs_correct_match(self, mock_scheduled, mock_time):
        """Test matching correct program among multiple"""
        duration, start_time, url = parse_and_validate_args()
        self.assertEqual(duration, 1200)  # Matches PROGRAM2 (20 minutes)
        self.assertEqual(url, 'url2')


if __name__ == '__main__':
    unittest.main()
