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

from record import parse_programs_config, calculate_duration_from_time, parse_and_validate_args


class TestParseProgramsConfig(unittest.TestCase):
    """Test parse_programs_config function"""
    
    def test_single_program(self):
        """Test parsing single program"""
        with patch.dict(os.environ, {
            'PROGRAM1': 'program1|Program Name #1|07:40-08:00|url1'
        }, clear=True):
            programs = parse_programs_config()
            
            self.assertEqual(len(programs), 1)
            self.assertIn('program1', programs)
            self.assertEqual(programs['program1']['name'], 'Program Name #1')
            self.assertEqual(programs['program1']['url'], 'url1')
            self.assertEqual(len(programs['program1']['schedule']), 1)
            self.assertEqual(programs['program1']['schedule'][0]['start'], '0740')
            self.assertEqual(programs['program1']['schedule'][0]['end'], '0800')
    
    def test_multiple_programs(self):
        """Test parsing multiple programs"""
        with patch.dict(os.environ, {
            'PROGRAM1': 'program1|Program Name #1|07:40-08:00|url1',
            'PROGRAM2': 'program2|Program Name #2|08:00-08:20|url2',
            'PROGRAM3': 'program3|Program Name #3|20:00-20:20|url3'
        }, clear=True):
            programs = parse_programs_config()
            
            self.assertEqual(len(programs), 3)
            self.assertIn('program1', programs)
            self.assertIn('program2', programs)
            self.assertIn('program3', programs)
    
    def test_no_programs(self):
        """Test when no programs are configured"""
        with patch.dict(os.environ, {}, clear=True):
            programs = parse_programs_config()
            
            self.assertEqual(len(programs), 0)
    
    def test_invalid_format_missing_fields(self):
        """Test invalid format with missing fields"""
        with patch.dict(os.environ, {
            'PROGRAM1': 'program1|Program Name #1'  # Missing schedule
        }, clear=True):
            programs = parse_programs_config()
            
            self.assertEqual(len(programs), 0)
    
    def test_invalid_format_no_separator(self):
        """Test invalid format without pipe separator"""
        with patch.dict(os.environ, {
            'PROGRAM1': 'program1 Program Name #1 07:40-08:00'
        }, clear=True):
            programs = parse_programs_config()
            
            self.assertEqual(len(programs), 0)
    
    def test_invalid_schedule_no_dash(self):
        """Test invalid schedule format without dash"""
        with patch.dict(os.environ, {
            'PROGRAM1': 'program1|Program Name #1|0740'
        }, clear=True):
            programs = parse_programs_config()
            
            self.assertEqual(len(programs), 0)
    
    def test_empty_fields(self):
        """Test with empty fields"""
        with patch.dict(os.environ, {
            'PROGRAM1': '07:40-08:00|||'
        }, clear=True):
            programs = parse_programs_config()
            
            self.assertEqual(len(programs), 0)
    
    def test_time_format_conversion(self):
        """Test time format conversion from HH:MM to HHMM"""
        with patch.dict(os.environ, {
            'PROGRAM1': '09:30-10:15|test|Test Program|url'
        }, clear=True):
            programs = parse_programs_config()
            
            self.assertEqual(programs['test']['schedule'][0]['start'], '0930')
            self.assertEqual(programs['test']['schedule'][0]['end'], '1015')
    
    def test_whitespace_handling(self):
        """Test that whitespace is properly trimmed"""
        with patch.dict(os.environ, {
            'PROGRAM1': '  07:40 - 08:00  |  program1  |  Program Name #1  |  url  '
        }, clear=True):
            programs = parse_programs_config()
            
            self.assertIn('program1', programs)
            self.assertEqual(programs['program1']['name'], 'Program Name #1')
            self.assertEqual(programs['program1']['schedule'][0]['start'], '0740')
            self.assertEqual(programs['program1']['schedule'][0]['end'], '0800')


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
        'PROGRAM1': '07:40-08:00|program1|Program Name #1|url1'
    }, clear=True)
    @patch('time.strftime', return_value='0740')
    def test_auto_duration_exact_match(self, mock_time):
        """Test auto duration with exact time match"""
        duration, start_time, url = parse_and_validate_args()
        self.assertEqual(duration, 1200)  # 20 minutes
        self.assertEqual(url, 'url1')
    
    @patch('sys.argv', ['record.py'])
    @patch.dict(os.environ, {
        'PROGRAM1': '07:40-08:00|program1|Program Name #1|url1'
    }, clear=True)
    @patch('time.strftime', return_value='0742')
    def test_auto_duration_within_tolerance(self, mock_time):
        """Test auto duration within 5-minute tolerance"""
        duration, start_time, url = parse_and_validate_args()
        self.assertEqual(duration, 1200)  # 20 minutes
    
    @patch('sys.argv', ['record.py'])
    @patch.dict(os.environ, {
        'PROGRAM1': '07:40-08:00|program1|Program Name #1|url1'
    }, clear=True)
    @patch('time.strftime', return_value='0750')
    def test_auto_duration_outside_tolerance(self, mock_time):
        """Test auto duration outside 5-minute tolerance"""
        with self.assertRaises(SystemExit):
            parse_and_validate_args()
    
    @patch('sys.argv', ['record.py'])
    @patch.dict(os.environ, {}, clear=True)
    def test_no_programs_configured(self):
        """Test when no programs are configured"""
        duration = parse_and_validate_args()
        self.assertEqual(duration, 1200)  # Default 20 minutes
    
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
        'PROGRAM1': '06:00-07:00|morning|Morning Show|url1',
        'PROGRAM2': '07:40-08:00|program1|Program Name #1|url2',
        'PROGRAM3': '18:00-19:00|evening|Evening Show|url3'
    }, clear=True)
    @patch('time.strftime', return_value='0740')
    def test_multiple_programs_correct_match(self, mock_time):
        """Test matching correct program among multiple"""
        duration, start_time, url = parse_and_validate_args()
        self.assertEqual(duration, 1200)  # Matches PROGRAM2 (20 minutes)
        self.assertEqual(url, 'url2')


if __name__ == '__main__':
    unittest.main()
