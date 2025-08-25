# Test Infrastructure Troubleshooting Guide

> **Emergency Fix**: Most issues (80%+) are resolved by: `./scripts/cache-manager.sh clean && export VOCORIZE_TEST_MODE=unit && ./test-unit.sh`

This guide provides systematic troubleshooting procedures for Vocorize's optimized test infrastructure, covering common issues and their solutions.

## 🎯 Quick Wins (Try These First)

### 90% of Issues - Basic Reset
```bash
# Clean cache and force unit test mode
./scripts/cache-manager.sh clean
export VOCORIZE_TEST_MODE=unit
./test-unit.sh  # Should complete in <30 seconds
```

### Slow Tests - Environment Check
```bash
# Verify mock providers are being used
echo $VOCORIZE_TEST_MODE  # Should be 'unit' for fast tests
./test-unit.sh --debug | head -20  # Check for MockWhisperKitProvider
```

### CI/CD Issues - Cache Check  
```bash
# Verify cache configuration
./scripts/cache-manager.sh status
ls -la ~/.cache/huggingface/hub/  # Should show cached models
```

---

## Overview

The test infrastructure includes multiple components that can encounter various issues:

- **Mock Provider System**: Unit test infrastructure with mock providers
- **Model Caching System**: Integration test model caching and management  
- **MLX Framework Integration**: Conditional MLX framework support
- **Performance Monitoring**: Benchmarking and performance validation
- **CI/CD Integration**: Automated test execution in CI environments

## Quick Diagnostic Commands

### First Steps - Health Check
```bash
# Quick system health check
./scripts/cache-manager.sh status              # Cache status
./test-unit.sh --verify                        # Mock infrastructure check
echo $VOCORIZE_TEST_MODE                       # Environment check
xcodebuild -showsdks | grep macOS              # Xcode availability
```

### Environment Verification  
```bash
# Verify test environment configuration
env | grep VOCORIZE                            # Environment variables
which xcodebuild                               # Xcode tools
swift --version                                # Swift compiler
df -h .                                        # Available disk space
```

## Mock Provider Issues

### Issue: Mock Providers Not Being Used
**Symptoms**: Unit tests taking >30 seconds, real ML models being loaded

**Diagnostic Steps**:
```bash
# Check test environment mode
echo $VOCORIZE_TEST_MODE
# Expected: 'unit' for unit tests

# Verify mock provider selection
./test-unit.sh --debug 2>&1 | grep -i provider
# Should show MockWhisperKitProvider usage

# Check for hardcoded real providers in tests
grep -r "WhisperKitProvider()" VocorizeTests/ --include="*.swift"
# Should show TestProviderFactory usage instead
```

**Solutions**:
```bash
# Force unit test mode
export VOCORIZE_TEST_MODE=unit

# Update test code to use TestProviderFactory
# Replace: let provider = WhisperKitProvider()
# With:    let provider = TestProviderFactory.createProvider(for: .whisperKit)

# Verify mock provider configuration
cat VocorizeTests/Support/TestProviderFactory.swift
```

### Issue: Mock Provider Responses Not Matching
**Symptoms**: Unexpected test failures, incorrect transcription results

**Diagnostic Steps**:
```bash
# Enable mock provider logging
export VOCORIZE_MOCK_DEBUG=true
./test-unit.sh

# Check mock configuration
grep -A 10 -B 10 "MockConfiguration" VocorizeTests/Support/MockProviders/
```

**Solutions**:
```bash
# Update mock provider configuration
# Edit VocorizeTests/Support/MockProviders/MockWhisperKitProvider.swift
# Verify expected responses match test assertions

# Reset mock provider state between tests
# Ensure proper setup/teardown in test methods
```

### Issue: Mock Provider Performance Issues
**Symptoms**: Mock providers slower than expected, high memory usage

**Diagnostic Steps**:
```bash
# Check mock provider performance
time ./test-unit.sh
# Should complete in <30 seconds

# Monitor memory usage during tests
top -o MEM -n 10 &
./test-unit.sh
kill %1
```

**Solutions**:
```bash
# Optimize mock provider configuration
# Reduce response delays in MockConfiguration
# Disable unnecessary performance simulation
# Check for memory leaks in mock implementation
```

## Model Caching Issues

### Issue: Cache Not Being Used (Always Downloading)
**Symptoms**: Integration tests taking 15-30 minutes despite cached models

**Diagnostic Steps**:
```bash
# Check cache status and integrity
./scripts/cache-manager.sh status
./scripts/cache-manager.sh verify

# Check cache directory permissions
ls -la ~/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache/

# Verify cache metadata
cat ~/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache/cache_metadata.json | jq .
```

**Solutions**:
```bash
# Clean and rebuild cache if corrupted
./scripts/cache-manager.sh clean
./test-integration.sh  # Repopulate cache

# Fix permissions if needed
chmod -R 755 ~/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache/

# Check for disk space issues
df -h ~/Library/Developer/Xcode/DerivedData/
```

### Issue: Cache Corruption
**Symptoms**: Checksum verification failures, cache verification errors

**Diagnostic Steps**:
```bash
# Run comprehensive cache verification
./scripts/cache-manager.sh verify

# Check for corrupted files
find ~/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache/ -name "*.tar.gz" -exec gzip -t {} \;

# Verify metadata integrity
python3 -c "
import json
with open('~/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache/cache_metadata.json', 'r') as f:
    data = json.load(f)
print('Metadata valid, contains', len(data), 'entries')
" 2>/dev/null || echo "Metadata corrupted"
```

**Solutions**:
```bash
# Nuclear option: complete cache rebuild
./scripts/cache-manager.sh clean
./test-integration.sh --clean-cache

# Selective model removal
# Edit cache_metadata.json to remove corrupted entries
# Remove corresponding cached files
# Let cache manager rebuild missing entries
```

### Issue: Cache Growing Too Large
**Symptoms**: Disk space warnings, cache exceeding configured limits

**Diagnostic Steps**:
```bash
# Check cache size and limits
./scripts/cache-manager.sh status
du -sh ~/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache/

# Check for temporary files and cleanup failures
find ~/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache/ -name "*.tmp" -o -name "*.incomplete"
```

**Solutions**:
```bash
# Run cache optimization
./scripts/cache-manager.sh optimize

# Adjust cache limits in ModelCacheManager configuration
# Edit maxCacheSize in CacheConfiguration

# Schedule regular cleanup
crontab -e
# Add: 0 2 * * 1 /path/to/scripts/cache-manager.sh optimize
```

## MLX Framework Issues

### Issue: MLX Framework Not Detected
**Symptoms**: MLX providers not being used on Apple Silicon, fallback to standard providers

**Diagnostic Steps**:
```bash
# Check MLX framework availability
./test-mlx-integration.sh --dry-run

# Verify Apple Silicon architecture
uname -m
# Expected: arm64

# Check MLX framework installation
find /System/Library/Frameworks -name "*MLX*" 2>/dev/null
find /opt/homebrew -name "*mlx*" 2>/dev/null
```

**Solutions**:
```bash
# Install MLX framework if available
# Check Apple developer documentation for MLX availability
# Ensure macOS version supports MLX

# Update MLXAvailability detection logic
# Check VocorizeTests/Support/MLXAvailability.swift
# Verify framework linking in project configuration
```

### Issue: MLX Framework Crashes
**Symptoms**: Application crashes when attempting to use MLX providers

**Diagnostic Steps**:
```bash
# Check crash logs
ls -la ~/Library/Logs/DiagnosticReports/Vocorize*

# Run with MLX debugging
export MLX_DEBUG=1
./test-integration.sh

# Verify conditional loading
grep -n "MLXAvailability" VocorizeTests/Support/TestProviderFactory.swift
```

**Solutions**:
```bash
# Implement proper conditional loading
# Ensure MLX providers are only created when framework is available
# Add runtime checks before MLX API calls
# Implement graceful fallback to non-MLX providers
```

## Performance Issues

### Issue: Tests Running Slower Than Expected
**Symptoms**: Performance targets not being met despite optimization

**Diagnostic Steps**:
```bash
# Run comprehensive performance measurement
./performance-measurement.sh

# Check for resource constraints
top -o CPU -n 10
iostat -x 1 5
df -h

# Verify test infrastructure is working correctly
./test-unit.sh --debug
./test-integration.sh --cache-info
```

**Solutions**:
```bash
# Identify bottlenecks using performance reports
cat performance-reports/latest.md

# Check for background processes consuming resources
# Verify SSD vs HDD for cache storage
# Increase allocated memory for test execution
# Consider parallel test execution
```

### Issue: Performance Regression
**Symptoms**: Tests significantly slower than baseline measurements  

**Diagnostic Steps**:
```bash
# Compare against baseline
cat performance-reports/performance_baseline.json
./performance-measurement.sh --compare-baseline

# Check for recent changes
git log --oneline -10
git diff HEAD~5 -- VocorizeTests/

# Verify test infrastructure integrity
./scripts/cache-manager.sh verify
./test-unit.sh --verify
```

**Solutions**:
```bash
# Identify regression source
git bisect start
git bisect bad HEAD
git bisect good HEAD~10
# Test performance at each step

# Revert problematic changes or optimize
# Update performance baseline if changes are intentional
```

## CI/CD Issues

### Issue: CI Tests Failing Due to Timeout
**Symptoms**: Tests timing out in CI environment despite working locally

**Diagnostic Steps**:
```bash
# Check CI environment configuration
echo $CI
echo $VOCORIZE_TEST_MODE
env | grep VOCORIZE

# Verify cache configuration in CI
cat .github/workflows/ci.yml  # or equivalent CI config
```

**Solutions**:
```bash
# Increase CI timeouts
# unit_tests: 5m → 10m
# integration_tests: 10m → 15m  

# Optimize CI cache configuration
# Verify cache key includes all relevant files
# Ensure cache paths are correctly configured

# Add CI-specific optimizations
export VOCORIZE_CI_MODE=true
# Implement faster CI-specific test configurations
```

### Issue: CI Cache Not Persisting
**Symptoms**: CI builds always download models, no cache benefits

**Diagnostic Steps**:
```bash
# Check CI cache configuration
# Verify cache paths match actual usage
# Check cache key generation logic

# Debug cache in CI environment
./scripts/cache-manager.sh status
ls -la ~/.cache/huggingface/hub/
```

**Solutions**:
```bash
# Update CI cache configuration
# Ensure cache paths are correct
# Verify cache key includes relevant dependencies
# Check cache retention policies

# Example GitHub Actions cache fix:
# - uses: actions/cache@v4
#   with:
#     path: |
#       ~/.cache/huggingface/hub
#       ~/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache
```

## Network and Connectivity Issues

### Issue: Model Download Failures
**Symptoms**: Integration tests failing with network errors, model download timeouts

**Diagnostic Steps**:
```bash
# Test network connectivity
ping -c 3 huggingface.co
curl -I https://huggingface.co/openai/whisper-tiny

# Check DNS resolution
nslookup huggingface.co

# Test from integration test context
./test-integration.sh --clean-cache --debug
```

**Solutions**:
```bash
# Configure network timeouts and retries
# Check firewall/proxy settings
# Consider using mirror repositories
# Implement exponential backoff for downloads

# Corporate network workarounds
# Configure proxy settings if needed
export https_proxy=http://proxy.company.com:8080
export http_proxy=http://proxy.company.com:8080
```

### Issue: Slow Model Downloads
**Symptoms**: Model downloads taking excessive time, affecting test performance

**Diagnostic Steps**:
```bash
# Test download speeds
curl -o /tmp/test_download -w "%{speed_download}\n" https://huggingface.co/openai/whisper-tiny/resolve/main/model.safetensors

# Check available bandwidth
speedtest-cli  # if available
```

**Solutions**:
```bash
# Use geographically closer mirrors
# Implement parallel downloads where possible
# Cache models in CI infrastructure
# Consider pre-warming cache in CI setup steps
```

## System Resource Issues

### Issue: Insufficient Disk Space
**Symptoms**: Cache operations failing, temporary file creation errors

**Diagnostic Steps**:
```bash
# Check available disk space
df -h
df -h ~/Library/Developer/Xcode/DerivedData/

# Identify large files and directories
du -sh ~/Library/Developer/Xcode/DerivedData/* | sort -hr
```

**Solutions**:
```bash
# Clean up old build artifacts
rm -rf ~/Library/Developer/Xcode/DerivedData/Vocorize-*/
xcrun simctl delete unavailable

# Optimize cache size limits
# Reduce maxCacheSize in ModelCacheManager
# Implement more aggressive cleanup policies

# Add disk space monitoring
# Alert when space falls below threshold
```

### Issue: Memory Pressure
**Symptoms**: System slowdown during tests, memory warnings, test crashes

**Diagnostic Steps**:
```bash
# Monitor memory usage during tests
top -o MEM &
./test-integration.sh
kill %1

# Check for memory leaks
instruments -t Leaks -D /tmp/leaks_trace.trace ./test-integration.sh
```

**Solutions**:
```bash
# Optimize memory usage in tests
# Reduce concurrent test execution
# Implement memory cleanup in test teardown
# Add memory monitoring and limits

# System-level solutions
# Increase swap space if possible
# Close unnecessary applications during testing
# Consider running tests on machines with more RAM
```

## Advanced Troubleshooting

### Debug Mode and Logging
Enable comprehensive debugging:

```bash
# Enable all debug modes
export VOCORIZE_TEST_MODE=integration
export VOCORIZE_MOCK_DEBUG=true
export VOCORIZE_CACHE_DEBUG=true
export VOCORIZE_PERFORMANCE_DEBUG=true

# Run with maximum logging
./test-integration.sh --debug --verbose > debug_output.log 2>&1
```

### Performance Profiling
Profile test infrastructure performance:

```bash
# Profile unit tests
instruments -t "Time Profiler" ./test-unit.sh

# Profile integration tests
instruments -t "Time Profiler" ./test-integration.sh

# Profile memory usage
instruments -t "Allocations" ./test-integration.sh
```

### System Diagnostics
Comprehensive system diagnostics:

```bash
# System information
system_profiler SPHardwareDataType
system_profiler SPSoftwareDataType

# Network diagnostics
netstat -rn
ifconfig

# Storage diagnostics
diskutil list
diskutil info /
```

## Recovery Procedures

### Complete Test Infrastructure Reset
When all else fails, complete reset:

```bash
# Clean all caches and temporary files
./scripts/cache-manager.sh clean
rm -rf ~/Library/Developer/Xcode/DerivedData/Vocorize-*
rm -rf ~/Library/Caches/com.apple.dt.Xcode/

# Reset environment variables
unset VOCORIZE_TEST_MODE
unset VOCORIZE_CACHE_DIR
unset VOCORIZE_MOCK_DEBUG

# Rebuild from scratch
./test-unit.sh                    # Should work with mocks
./test-integration.sh --clean-cache  # Rebuild cache
./performance-measurement.sh      # Verify performance
```

### Restore from Backup
If available, restore from known good state:

```bash
# Restore cache from backup
cp -r /path/to/cache/backup/* ~/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache/

# Restore baseline performance data
cp /path/to/performance_baseline_backup.json performance-reports/performance_baseline.json

# Verify restoration
./scripts/cache-manager.sh verify
./performance-measurement.sh --baseline-check
```

## Prevention Strategies

### Regular Maintenance
Implement regular maintenance procedures:

```bash
# Weekly maintenance script
#!/bin/bash
# weekly_maintenance.sh

# Cache maintenance
./scripts/cache-manager.sh optimize
./scripts/cache-manager.sh verify

# Performance monitoring
./performance-measurement.sh --report-only

# System cleanup
rm -rf /tmp/vocorize_test_*
find ~/Library/Developer/Xcode/DerivedData/Vocorize-* -name "*.log" -mtime +7 -delete

# Report generation
echo "Maintenance completed at $(date)" >> maintenance.log
```

### Monitoring and Alerts
Set up proactive monitoring:

```bash
# Performance monitoring script
#!/bin/bash
# monitor_performance.sh

PERFORMANCE_SCORE=$(./performance-measurement.sh --json | jq '.performance_score')

if [ "$PERFORMANCE_SCORE" -lt 80 ]; then
    echo "Performance degradation detected: $PERFORMANCE_SCORE/100"
    # Send alert via email, Slack, etc.
fi

# Schedule in crontab
# 0 */6 * * * /path/to/monitor_performance.sh
```

### Documentation Updates
Keep troubleshooting documentation current:

```bash
# Document new issues and solutions
# Update troubleshooting guide with new findings
# Maintain knowledge base of common problems
# Share solutions with team through documentation
```

## Getting Help

### Information to Collect
When seeking help, collect this information:

```bash
# System information
uname -a
sw_vers
xcodebuild -version

# Environment information
env | grep VOCORIZE
echo $PATH

# Test infrastructure status
./scripts/cache-manager.sh status
./performance-measurement.sh --status

# Error logs and outputs
# Include relevant log files and error messages
# Provide steps to reproduce the issue
# Include any recent changes that might be related
```

### Support Channels
- **Internal Documentation**: Check existing documentation and guides
- **Team Knowledge Base**: Consult team-specific troubleshooting resources
- **Issue Tracking**: Create detailed issue reports with reproduction steps
- **Performance Monitoring**: Check performance dashboards for trends and patterns

## Conclusion

This troubleshooting guide covers the most common issues with Vocorize's test infrastructure. The key to effective troubleshooting is:

1. **Systematic Approach**: Follow diagnostic steps methodically
2. **Comprehensive Information**: Collect relevant system and environment information  
3. **Prevention Focus**: Implement monitoring and maintenance to prevent issues
4. **Documentation**: Keep troubleshooting knowledge updated and accessible

Most issues can be resolved by following these procedures, but don't hesitate to escalate complex problems or performance regressions that affect development productivity.