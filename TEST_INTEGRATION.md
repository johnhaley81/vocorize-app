# Integration Test Documentation

This document describes the comprehensive integration test execution for Vocorize using real WhisperKit providers.

## Overview

The integration test suite (`test-integration.sh`) runs comprehensive tests using actual WhisperKit models and network operations. These tests are designed for thorough validation of the ML pipeline, model downloads, and transcription accuracy.

## Quick Start

```bash
# Interactive execution with warnings
./test-integration.sh

# CI/automated execution  
./test-integration.sh --ci

# Preview execution plan
./test-integration.sh --dry-run

# Clean model cache and run
./test-integration.sh --clean
```

## Test Coverage

### WhisperKit Integration Tests
- Real model downloads from Hugging Face Hub
- ML inference with sample audio files
- Transcription accuracy validation
- Model management functionality
- Provider lifecycle testing

### Provider System Integration Tests
- End-to-end provider registration
- Audio processing pipeline
- Error handling and recovery
- Resource cleanup validation

### MLX Integration Tests (Apple Silicon)
- MLX framework availability detection
- MLX-accelerated inference testing
- Performance comparison validation
- Fallback behavior verification

## Requirements

### System Requirements
- macOS with Apple Silicon (recommended)
- Xcode Command Line Tools
- Stable internet connection (500MB+ bandwidth)
- Available disk space (1GB+ recommended)

### Network Dependencies
- Access to Hugging Face Hub (huggingface.co)
- Model download endpoints
- GitHub Package Registry (for dependencies)

### Environment Variables
```bash
export VOCORIZE_TEST_MODE=integration  # Enables real provider mode
export CI=true                         # Disables interactive prompts
```

## Execution Time

**Expected Duration:** 5-30 minutes

Time varies based on:
- Model download speed (network bandwidth)
- Model cache status (cached vs. fresh download)
- Hardware performance (ML inference speed)
- Test coverage selection

## Storage Usage

### Model Cache Location
```
~/.cache/huggingface/hub/
```

### Typical Storage Requirements
- Fresh install: 500MB-1GB (model downloads)
- Cached models: Minimal additional storage
- Test artifacts: 10-50MB (logs, results)

## Script Options

```bash
Usage: ./test-integration.sh [options]

Options:
  -h, --help     Show this help message
  --ci           Run in CI mode (no interactive prompts)
  --timeout N    Set timeout in seconds (default: 1800)
  --clean        Clean model cache before running
  --dry-run      Show what would be executed without running tests

Environment Variables:
  CI=true        Automatically run in CI mode
  VOCORIZE_TEST_MODE=integration  Set integration test mode
```

## Pre-flight Checks

The script performs comprehensive validation before execution:

### System Validation
- [ ] Xcode project structure verification
- [ ] xcodebuild availability check
- [ ] Integration test file existence

### Network Connectivity
- [ ] Internet connectivity (ping test)
- [ ] Hugging Face Hub accessibility
- [ ] Download endpoint availability

### Resource Availability
- [ ] Disk space requirements (1GB minimum)
- [ ] Model cache status inspection
- [ ] Temporary directory permissions

## Success Criteria

### Successful Execution Indicators
- ✅ All pre-flight checks pass
- ✅ Model downloads complete successfully
- ✅ Transcription tests pass accuracy thresholds
- ✅ Provider lifecycle tests complete
- ✅ Resource cleanup verification

### Test Result Artifacts
- `integration_test_YYYYMMDD_HHMMSS.log` - Detailed execution log
- `integration_test_results/` - Xcode test results bundle
- `integration_test_results_YYYYMMDD_HHMMSS.tar.gz` - Archived results

## Troubleshooting

### Common Issues

#### Network-Related Failures
```bash
# Symptoms
- Model download timeouts
- Connection refused errors
- Partial download failures

# Solutions
- Verify internet connectivity
- Check firewall/proxy settings
- Retry with --clean option
- Increase timeout: --timeout 3600
```

#### Disk Space Issues
```bash
# Symptoms
- "No space left on device" errors
- Model cache write failures
- Temporary file creation errors

# Solutions
- Free up disk space (1GB+ recommended)
- Clean model cache: rm -rf ~/.cache/huggingface/hub/
- Monitor space during execution
```

#### MLX Framework Issues
```bash
# Symptoms
- MLX not available warnings
- Framework loading errors
- Apple Silicon detection failures

# Solutions
- Verify running on Apple Silicon Mac
- Check MLX framework installation
- Update to latest macOS version
- Install missing MLX dependencies
```

### Debug Mode

For detailed troubleshooting, examine the test log:

```bash
# Monitor live execution
tail -f integration_test_YYYYMMDD_HHMMSS.log

# Search for specific errors
grep -i "error\|fail\|timeout" integration_test_YYYYMMDD_HHMMSS.log

# Check network-related issues
grep -i "network\|download\|connection" integration_test_YYYYMMDD_HHMMSS.log
```

## CI/CD Integration

### Nightly Pipeline Usage
```yaml
# Example GitHub Actions integration
- name: Run Integration Tests
  run: ./test-integration.sh --ci --timeout 3600
  env:
    CI: true
    VOCORIZE_TEST_MODE: integration
```

### Release Validation
```bash
# Pre-release validation
./test-integration.sh --clean --ci

# Verify all models and providers
VOCORIZE_TEST_MODE=integration ./test-integration.sh --ci
```

## Performance Expectations

### Baseline Performance (Apple Silicon M1/M2)
- Model download: 2-5 minutes (depending on cache)
- ML inference tests: 1-3 minutes per model
- Provider system tests: 2-5 minutes
- Total execution: 10-20 minutes typical

### Performance Monitoring
The script reports execution timing and provides performance insights:
- Model download speeds
- Inference timing per test
- Overall execution duration
- Resource usage statistics

## Support

For issues with integration tests:

1. **Check Prerequisites:** Ensure all system requirements are met
2. **Review Logs:** Examine detailed execution logs for error patterns
3. **Test Isolation:** Run unit tests first with `./test.sh`
4. **Clean State:** Try with `--clean` option to reset model cache
5. **Network Debugging:** Verify connectivity to all required endpoints

The integration test suite is designed to provide comprehensive validation while being resilient to common network and system issues.