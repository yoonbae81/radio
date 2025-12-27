"""
Tests for feed.py program configuration parsing
Uses Python's built-in unittest framework
"""

import os
import unittest
from unittest.mock import patch
import sys

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from feed import parse_programs, extract_time_from_filename


class TestParsePrograms(unittest.TestCase):
    """Test parse_programs function"""
    
    def test_single_program(self):
        """Test parsing single program"""
        with patch.dict(os.environ, {
            'PROGRAM1': '07:40-08:00|ALL|program1|Program Name #1|url1'
        }, clear=True):
            programs = parse_programs('')
            
            self.assertEqual(len(programs), 1)
            self.assertIn('program1', programs)
            self.assertEqual(programs['program1']['name'], 'Program Name #1')
            self.assertEqual(len(programs['program1']['schedule']), 1)
            self.assertEqual(programs['program1']['schedule'][0], '0740')
    
    def test_multiple_programs(self):
        """Test parsing multiple programs"""
        with patch.dict(os.environ, {
            'PROGRAM1': '07:40-08:00|ALL|program1|Program Name #1|url1',
            'PROGRAM2': '08:00-08:20|MON-FRI|program2|Program Name #2|url2',
            'PROGRAM3': '08:20-08:40|SAT,SUN|program3|Program Name #3|url3'
        }, clear=True):
            programs = parse_programs('')
            
            self.assertEqual(len(programs), 3)
            self.assertIn('program1', programs)
            self.assertIn('program2', programs)
            self.assertIn('program3', programs)
    
    def test_no_programs(self):
        """Test when no programs are configured"""
        with patch.dict(os.environ, {}, clear=True):
            programs = parse_programs('')
            
            self.assertEqual(len(programs), 0)
    
    def test_invalid_format_missing_fields(self):
        """Test invalid format with missing fields"""
        with patch.dict(os.environ, {
            'PROGRAM1': '07:40-08:00|MON|program1'  # Missing name
        }, clear=True):
            programs = parse_programs('')
            
            self.assertEqual(len(programs), 0)
    
    def test_invalid_format_no_separator(self):
        """Test invalid format without pipe separator"""
        with patch.dict(os.environ, {
            'PROGRAM1': '07:40-08:00 program1 Program Name #1 url'
        }, clear=True):
            programs = parse_programs('')
            
            self.assertEqual(len(programs), 0)
    
    def test_invalid_schedule_no_dash(self):
        """Test invalid schedule format without dash"""
        with patch.dict(os.environ, {
            'PROGRAM1': '0740|ALL|program1|Program Name #1|url'
        }, clear=True):
            programs = parse_programs('')
            
            self.assertEqual(len(programs), 0)
    
    def test_empty_fields(self):
        """Test with empty fields"""
        with patch.dict(os.environ, {
            'PROGRAM1': '07:40-08:00|||'
        }, clear=True):
            programs = parse_programs('')
            
            self.assertEqual(len(programs), 0)
    
    def test_time_format_conversion(self):
        """Test time format conversion from HH:MM to HHMM"""
        with patch.dict(os.environ, {
            'PROGRAM1': '09:30-10:15|ALL|test|Test Program|url'
        }, clear=True):
            programs = parse_programs('')
            
            self.assertEqual(programs['test']['schedule'][0], '0930')
    
    def test_whitespace_handling(self):
        """Test that whitespace is properly trimmed"""
        with patch.dict(os.environ, {
            'PROGRAM1': '  07:40 - 08:00  |  ALL  |  program1  |  Program Name #1  |  url  '
        }, clear=True):
            programs = parse_programs('')
            
            self.assertIn('program1', programs)
            self.assertEqual(programs['program1']['name'], 'Program Name #1')
            self.assertEqual(programs['program1']['schedule'][0], '0740')
    
    def test_generic_program_names(self):
        """Test generic program names are handled correctly"""
        with patch.dict(os.environ, {
            'PROGRAM1': '08:00-08:20|ALL|program2|Program Name #2|url'
        }, clear=True):
            programs = parse_programs('')
            
            self.assertIn('program2', programs)
            self.assertEqual(programs['program2']['name'], 'Program Name #2')
    
    def test_special_characters_in_alias(self):
        """Test special characters in alias"""
        with patch.dict(os.environ, {
            'PROGRAM1': '07:40-08:00|ALL|test-program|Program Name|url'
        }, clear=True):
            programs = parse_programs('')
            
            self.assertIn('test-program', programs)
    def test_schedule_extraction_only_start_time(self):
        """Test that only start time is extracted from schedule"""
        with patch.dict(os.environ, {
            'PROGRAM1': '07:40-08:00|ALL|program1|Program Name #1|url'
        }, clear=True):
            programs = parse_programs('')
            
            # Feed only needs start time for filtering
            self.assertEqual(programs['program1']['schedule'][0], '0740')
    
    def test_multiple_programs_same_alias_different_times(self):
        """Test multiple entries with same alias but different times"""
        with patch.dict(os.environ, {
            'PROGRAM1': '08:00-08:20|ALL|program1|Program Name #1|url1',
            'PROGRAM2': '20:00-20:20|ALL|program1|Program Name #1|url2'
        }, clear=True):
            programs = parse_programs('')
            
            # Last one wins (PROGRAM2 overwrites PROGRAM1)
            self.assertEqual(len(programs), 1)
            self.assertIn('program1', programs)
            # Only the last schedule is kept
            self.assertEqual(programs['program1']['schedule'][0], '2000')
    
    def test_edge_case_midnight(self):
        """Test edge case with midnight time"""
        with patch.dict(os.environ, {
            'PROGRAM1': '00:00-01:00|ALL|midnight|Midnight Show|url'
        }, clear=True):
            programs = parse_programs('')
            
            self.assertEqual(programs['midnight']['schedule'][0], '0000')
    
    def test_edge_case_late_night(self):
        """Test edge case with late night time"""
        with patch.dict(os.environ, {
            'PROGRAM1': '23:30-00:30|ALL|latenight|Late Night Show|url'
        }, clear=True):
            programs = parse_programs('')
            
            self.assertEqual(programs['latenight']['schedule'][0], '2330')

class TestExtractTimeFromFilename(unittest.TestCase):
    """Test extract_time_from_filename function"""
    
    def test_extract_with_space(self):
        """Test extraction from filename with spaces (legacy format)"""
        filename = "20251222 0740 5f3a2b1c.m4a"
        time_part = extract_time_from_filename(filename)
        self.assertEqual(time_part, "0740")
    
    def test_extract_with_hyphen(self):
        """Test extraction from filename with hyphens (new format)"""
        filename = "20251222-0740-5f3a2b1c.m4a"
        time_part = extract_time_from_filename(filename)
        self.assertEqual(time_part, "0740")
    
    def test_invalid_filename(self):
        """Test with invalid filename"""
        self.assertIsNone(extract_time_from_filename("invalid.m4a"))
        self.assertIsNone(extract_time_from_filename("2025122 0740.m4a")) # Date too short


if __name__ == '__main__':
    unittest.main()
