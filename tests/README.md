# Radio Recording Service - Test Suite

## Running Tests

### Run All Tests

```bash
python -m unittest discover tests
```

### Run Specific Test File

```bash
python -m unittest tests.test_record
python -m unittest tests.test_feed
```

### Run Specific Test Class

```bash
python -m unittest tests.test_record.TestParseProgramsConfig
```

### Run Specific Test Method

```bash
python -m unittest tests.test_record.TestParseProgramsConfig.test_single_program
```

### Verbose Output

```bash
python -m unittest discover tests -v
```

## Test Structure

```
tests/
├── __init__.py
├── test_record.py    # Tests for record.py
└── test_feed.py      # Tests for feed.py
```

## Test Coverage

### test_record.py

Tests for `record.py`:
- `TestParseProgramsConfig`: Program configuration parsing
  - Single and multiple programs
  - Invalid formats and edge cases
  - Time format conversion
  - Whitespace handling
  
- `TestCalculateDurationFromTime`: Duration calculation
  - Basic duration
  - Overnight duration (spanning midnight)
  - Edge cases (same time, short duration)
  
- `TestParseAndValidateArgs`: Command line argument parsing
  - Manual duration input
  - Auto duration calculation
  - Time matching with tolerance
  - Multiple programs selection

### test_feed.py

Tests for `feed.py`:
- `TestParsePrograms`: Program configuration parsing for feed
  - Single and multiple programs
  - Invalid formats
  - Korean program names
  - Special characters
  - Edge cases (midnight, late night)
  - Schedule extraction (start time only)

## Mocking

Tests use `unittest.mock` to:
- Mock environment variables (`patch.dict(os.environ, ...)`)
- Mock time functions (`patch('time.strftime', ...)`)
- Mock command line arguments (`patch('sys.argv', ...)`)

## Example Test Run

```bash
$ python -m unittest discover tests -v

test_basic_duration (tests.test_record.TestCalculateDurationFromTime) ... ok
test_one_hour_duration (tests.test_record.TestCalculateDurationFromTime) ... ok
test_overnight_duration (tests.test_record.TestCalculateDurationFromTime) ... ok
test_auto_duration_exact_match (tests.test_record.TestParseAndValidateArgs) ... ok
test_manual_duration (tests.test_record.TestParseAndValidateArgs) ... ok
test_single_program (tests.test_record.TestParseProgramsConfig) ... ok
test_multiple_programs (tests.test_record.TestParseProgramsConfig) ... ok
test_single_program (tests.test_feed.TestParsePrograms) ... ok
test_multiple_programs (tests.test_feed.TestParsePrograms) ... ok

----------------------------------------------------------------------
Ran 30 tests in 0.15s

OK
```

## Running Individual Test Files

You can also run test files directly:

```bash
python tests/test_record.py
python tests/test_feed.py
```

## CI/CD Integration

Add to your CI pipeline:

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-python@v2
        with:
          python-version: '3.11'
      - run: pip install -r requirements.txt
      - run: python -m unittest discover tests -v
```

## No External Dependencies

These tests use only Python's built-in `unittest` framework and `unittest.mock` module. No external testing libraries (pytest, nose, etc.) are required.
