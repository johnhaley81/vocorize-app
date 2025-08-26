# CI/CD Integration Guide for Test Optimization

> **Quick Start**: Jump to [GitHub Actions](#github-actions), [GitLab CI](#gitlab-ci), or [Azure DevOps](#azure-devops) for platform-specific configuration.

This guide explains how to integrate Vocorize's optimized test infrastructure into CI/CD pipelines for maximum efficiency and reliability.

## 🎯 Overview

The test optimization infrastructure provides significant benefits for CI/CD environments:

- **90%+ Faster Builds**: Reduced from 30+ minutes to 2-5 minutes
- **Reliable Caching**: Consistent performance across build agents
- **Resource Efficiency**: Minimal network and storage requirements
- **Performance Gates**: Automated performance regression detection

## 🗺️ Navigation Guide

| Section | Use Case | Time Investment |
|---------|----------|----------------|
| [Platform Configurations](#platform-specific-configurations) | Set up CI for your platform | 30-60 minutes |
| [Cache Management](#cache-management-strategies) | Optimize cache performance | 15-30 minutes |
| [Performance Gates](#performance-gates-and-validation) | Add performance validation | 15-30 minutes |
| [Troubleshooting](#troubleshooting-cicd-issues) | Fix CI/CD issues | As needed |

## CI/CD Integration Architecture

### Pipeline Stages

#### Stage 1: Environment Setup
```yaml
setup_test_environment:
  stage: setup
  script:
    - export VOCORIZE_TEST_MODE=integration
    - export CI=true
    - mkdir -p ~/.cache/huggingface/hub
    - mkdir -p ~/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache
  cache:
    paths:
      - ~/.cache/huggingface/hub/
      - ~/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache/
```

#### Stage 2: Cache Management  
```yaml
cache_warmup:
  stage: prepare
  script:
    - ./scripts/cache-manager.sh status
    - if [ $CACHE_SIZE -lt 100000000 ]; then ./scripts/cache-manager.sh warm; fi
  cache:
    policy: pull-push
    paths:
      - ~/.cache/huggingface/hub/
      - ~/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache/
```

#### Stage 3: Fast Unit Tests
```yaml
unit_tests:
  stage: test
  script:
    - export VOCORIZE_TEST_MODE=unit
    - VocorizeTests/scripts/test-unit.sh
  timeout: 5m  # Unit tests should complete in <5 minutes
```

#### Stage 4: Integration Tests
```yaml
integration_tests:
  stage: test
  script:
    - export VOCORIZE_TEST_MODE=integration
    - VocorizeTests/scripts/test-integration.sh --ci
  timeout: 10m  # Integration tests with cache should complete in <10 minutes
  cache:
    policy: pull
    paths:
      - ~/.cache/huggingface/hub/
      - ~/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache/
```

#### Stage 5: Performance Validation
```yaml
performance_validation:
  stage: validate
  script:
    - VocorizeTests/scripts/performance-measurement.sh --ci
    - if [ $PERFORMANCE_GRADE != "A" ]; then exit 1; fi
  artifacts:
    reports:
      junit: performance-reports/performance_report_*.xml
    paths:
      - performance-reports/
```

## Platform-Specific Configurations

### GitHub Actions

```yaml
name: Vocorize CI with Test Optimization

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Cache Test Models
      uses: actions/cache@v4
      with:
        path: |
          ~/.cache/huggingface/hub
          ~/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache
        key: vocorize-models-${{ hashFiles('VocorizeTests/**/*.swift') }}
        restore-keys: |
          vocorize-models-
    
    - name: Setup Test Environment
      run: |
        export VOCORIZE_TEST_MODE=integration
        export CI=true
    
    - name: Check Cache Status
      run: ./scripts/cache-manager.sh status
    
    - name: Run Unit Tests
      run: |
        export VOCORIZE_TEST_MODE=unit
        VocorizeTests/scripts/test-unit.sh
    
    - name: Run Integration Tests
      run: |
        export VOCORIZE_TEST_MODE=integration
        timeout 600 VocorizeTests/scripts/test-integration.sh --ci
    
    - name: Performance Validation
      run: VocorizeTests/scripts/performance-measurement.sh --ci
    
    - name: Upload Performance Reports
      uses: actions/upload-artifact@v4
      if: always()
      with:
        name: performance-reports
        path: performance-reports/
```

### GitLab CI

```yaml
stages:
  - setup
  - test
  - validate
  - cleanup

variables:
  VOCORIZE_TEST_MODE: "integration"
  CI: "true"

cache:
  key: vocorize-models-$CI_COMMIT_REF_SLUG
  paths:
    - ~/.cache/huggingface/hub/
    - ~/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache/

setup_environment:
  stage: setup
  script:
    - mkdir -p ~/.cache/huggingface/hub
    - mkdir -p ~/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache
    - ./scripts/cache-manager.sh status

unit_tests:
  stage: test
  script:
    - export VOCORIZE_TEST_MODE=unit
    - timeout 300 VocorizeTests/scripts/test-unit.sh
  artifacts:
    reports:
      junit: test_results_unit.xml

integration_tests:
  stage: test
  script:
    - export VOCORIZE_TEST_MODE=integration
    - timeout 600 VocorizeTests/scripts/test-integration.sh --ci
  artifacts:
    reports:
      junit: test_results_integration.xml
  cache:
    policy: pull-push

performance_validation:
  stage: validate
  script:
    - VocorizeTests/scripts/performance-measurement.sh --ci
    - |
      if [ $(grep "Performance Grade:" performance-reports/latest.md | grep -c "✅ EXCELLENT") -eq 0 ]; then
        echo "Performance validation failed"
        exit 1
      fi
  artifacts:
    paths:
      - performance-reports/
  when: always
```

### Azure DevOps

```yaml
trigger:
  - main
  - develop

pool:
  vmImage: 'macOS-latest'

variables:
  VOCORIZE_TEST_MODE: 'integration'
  CI: 'true'

stages:
- stage: Test
  jobs:
  - job: UnitTests
    steps:
    - script: |
        export VOCORIZE_TEST_MODE=unit
        VocorizeTests/scripts/test-unit.sh
      displayName: 'Run Unit Tests'
      timeoutInMinutes: 5
    
  - job: IntegrationTests
    dependsOn: []
    steps:
    - task: Cache@2
      inputs:
        key: 'vocorize-models | "$(Agent.OS)" | VocorizeTests/**/*.swift'
        path: |
          ~/.cache/huggingface/hub
          ~/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache
        restoreKeys: |
          vocorize-models | "$(Agent.OS)"
      displayName: 'Cache Test Models'
    
    - script: ./scripts/cache-manager.sh status
      displayName: 'Check Cache Status'
    
    - script: |
        export VOCORIZE_TEST_MODE=integration
        timeout 600 VocorizeTests/scripts/test-integration.sh --ci
      displayName: 'Run Integration Tests'
      timeoutInMinutes: 10
    
    - script: VocorizeTests/scripts/performance-measurement.sh --ci
      displayName: 'Performance Validation'
      condition: always()
    
    - task: PublishTestResults@2
      inputs:
        testResultsFormat: 'JUnit'
        testResultsFiles: 'test_results_*.xml'
      condition: always()
    
    - task: PublishBuildArtifacts@1
      inputs:
        pathToPublish: 'performance-reports'
        artifactName: 'performance-reports'
      condition: always()
```

## Cache Management Strategies

### Cache Persistence
Optimize cache retention across builds:

```yaml
# GitLab CI cache configuration
cache:
  key: 
    files:
      - VocorizeTests/**/*.swift
      - Package.resolved
  paths:
    - ~/.cache/huggingface/hub/
    - ~/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache/
  policy: pull-push
  when: always  # Preserve cache even on failure
```

### Cache Warm-up Strategies
Pre-populate cache for optimal performance:

```bash
# CI cache warm-up script
warmup_cache() {
    local cache_size=$(./scripts/cache-manager.sh status | grep "Total Cache Size" | awk '{print $4}')
    
    if [ "${cache_size%MB}" -lt 100 ]; then
        echo "Cache is empty or small, warming up..."
        VocorizeTests/scripts/test-integration.sh --ci --timeout 1800  # Allow 30min for first run
    else
        echo "Cache is warmed (${cache_size}), proceeding with normal tests"
    fi
}
```

### Cache Cleanup Strategies
Maintain cache health and performance:

```bash
# Scheduled cache maintenance
cache_maintenance() {
    # Run weekly cache cleanup
    if [ "$(date +%u)" = "1" ]; then  # Monday
        ./scripts/cache-manager.sh optimize
        ./scripts/cache-manager.sh verify
    fi
    
    # Clean cache if it exceeds size limits
    local cache_size=$(./scripts/cache-manager.sh status | grep -o '[0-9]*MB' | head -1)
    if [ "${cache_size%MB}" -gt 5120 ]; then  # 5GB limit
        ./scripts/cache-manager.sh clean
    fi
}
```

## Performance Gates and Validation

### Performance Thresholds
Set automatic performance validation gates:

```bash
# CI performance validation script
validate_ci_performance() {
    local unit_time=$(grep "Unit Tests:" performance-reports/latest.md | grep -o '[0-9]*s')
    local integration_time=$(grep "Integration Tests:" performance-reports/latest.md | grep -o '[0-9]*s')
    
    # Performance gates
    if [ "${unit_time%s}" -gt 60 ]; then
        echo "❌ Unit tests exceeded 60s limit: ${unit_time}"
        exit 1
    fi
    
    if [ "${integration_time%s}" -gt 300 ]; then
        echo "❌ Integration tests exceeded 5min limit: ${integration_time}"
        exit 1
    fi
    
    echo "✅ Performance validation passed"
}
```

### Performance Trend Analysis
Track performance trends across builds:

```bash
# Performance trend tracking
track_performance_trends() {
    local current_performance=$(VocorizeTests/scripts/performance-measurement.sh --json | jq '.overall_score')
    local baseline_performance=$(cat performance_baseline.json | jq '.overall_score')
    local degradation=$(echo "($baseline_performance - $current_performance) * 100 / $baseline_performance" | bc -l)
    
    if (( $(echo "$degradation > 20" | bc -l) )); then
        echo "⚠️ Performance degradation detected: ${degradation}%"
        echo "Consider investigating recent changes"
        # Could trigger alerts, block merges, etc.
    fi
}
```

### Build Quality Gates
Integrate performance validation with CI quality gates:

```yaml
# Quality gate configuration
quality_gate:
  stage: validate
  script:
    - VocorizeTests/scripts/performance-measurement.sh --ci
    - |
      PERFORMANCE_SCORE=$(cat performance-reports/latest.json | jq '.performance_score')
      if [ "$PERFORMANCE_SCORE" -lt 80 ]; then
        echo "Performance score too low: $PERFORMANCE_SCORE/100"
        exit 1
      fi
  only:
    - main
    - develop
```

## Monitoring and Alerting

### Performance Monitoring Dashboard
Integrate with monitoring systems:

```bash
# Performance metrics export for monitoring
export_performance_metrics() {
    local metrics_file="performance-reports/metrics_$(date +%s).json"
    
    cat > "$metrics_file" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "commit": "$CI_COMMIT_SHA",
    "branch": "$CI_COMMIT_REF_NAME",
    "unit_test_time": $(grep "Unit Tests:" performance-reports/latest.md | grep -o '[0-9]*'),
    "integration_test_time": $(grep "Integration Tests:" performance-reports/latest.md | grep -o '[0-9]*'),
    "cache_hit_rate": $(./scripts/cache-manager.sh status | grep "Hit Rate" | grep -o '[0-9]*'),
    "cache_size_mb": $(./scripts/cache-manager.sh status | grep "Total Cache Size" | grep -o '[0-9]*')
}
EOF
    
    # Send to monitoring system (Prometheus, DataDog, etc.)
    curl -X POST "$MONITORING_ENDPOINT" -d @"$metrics_file"
}
```

### Alert Configuration
Set up performance-based alerting:

```bash
# Performance alert configuration
configure_performance_alerts() {
    # Slack/Teams notification on performance regression
    if [ "$PERFORMANCE_REGRESSION" = "true" ]; then
        curl -X POST "$SLACK_WEBHOOK_URL" -H 'Content-type: application/json' --data '{
            "text": "🚨 Performance regression detected in '"$CI_PROJECT_NAME"'",
            "attachments": [{
                "color": "danger",
                "fields": [{
                    "title": "Branch",
                    "value": "'"$CI_COMMIT_REF_NAME"'",
                    "short": true
                }, {
                    "title": "Commit",
                    "value": "'"$CI_COMMIT_SHA"'",
                    "short": true
                }, {
                    "title": "Performance Score", 
                    "value": "'"$PERFORMANCE_SCORE"'/100",
                    "short": true
                }]
            }]
        }'
    fi
}
```

## Resource Optimization

### Build Agent Configuration
Optimize CI build agents for test performance:

```bash
# Build agent optimization
optimize_build_agent() {
    # Increase disk space for model cache
    # Minimum: 10GB available space
    # Recommended: 20GB+ for optimal caching
    
    # Use SSD storage for cache directories
    # Mount cache directories on fast storage
    
    # Allocate sufficient memory
    # Minimum: 8GB RAM
    # Recommended: 16GB+ for parallel test execution
    
    # Configure network optimization
    # High-bandwidth connection for initial model downloads
    # CDN or mirror configuration for model repositories
}
```

### Parallel Execution
Enable parallel test execution for faster builds:

```yaml
# Parallel test execution configuration
parallel_tests:
  stage: test
  parallel:
    matrix:
      - TEST_SUITE: [unit, integration_cached, integration_clean]
  script:
    - |
      case $TEST_SUITE in
        unit)
          export VOCORIZE_TEST_MODE=unit
          timeout 300 VocorizeTests/scripts/test-unit.sh
          ;;
        integration_cached)
          export VOCORIZE_TEST_MODE=integration
          timeout 600 VocorizeTests/scripts/test-integration.sh --ci
          ;;
        integration_clean)
          export VOCORIZE_TEST_MODE=integration
          timeout 1800 VocorizeTests/scripts/test-integration.sh --ci --clean-cache
          ;;
      esac
```

## Best Practices

### CI/CD Pipeline Design
1. **Fast Feedback**: Run unit tests first for rapid feedback
2. **Cache Strategy**: Implement robust caching with fallback strategies
3. **Parallel Execution**: Use parallel jobs where possible
4. **Resource Management**: Optimize build agent resources for test workloads

### Performance Monitoring
1. **Continuous Tracking**: Monitor performance metrics across all builds
2. **Trend Analysis**: Track performance trends over time
3. **Alerting**: Set up alerts for performance regressions
4. **Baseline Management**: Maintain performance baselines for different branches

### Troubleshooting
1. **Diagnostic Tools**: Include diagnostic information in CI logs
2. **Artifact Preservation**: Save performance reports and logs
3. **Rollback Strategy**: Implement automatic rollback on performance regression
4. **Support Workflow**: Provide clear troubleshooting steps for CI failures

### Security and Compliance
1. **Cache Security**: Ensure model caches don't contain sensitive data
2. **Resource Limits**: Set appropriate resource limits and timeouts
3. **Audit Logging**: Track performance metrics for compliance
4. **Access Control**: Manage access to performance data and reports

## Troubleshooting CI/CD Issues

### Common CI/CD Problems

#### Cache Misses in CI
**Symptoms**: Integration tests taking >10 minutes despite cache configuration
**Solutions**:
```bash
# Check cache configuration
- Verify cache key includes relevant files
- Ensure cache paths are correct
- Check cache retention policies
- Validate cache restore logic

# Debug cache status in CI
./scripts/cache-manager.sh status
ls -la ~/.cache/huggingface/hub/
```

#### Performance Degradation in CI
**Symptoms**: Tests slower in CI than local development
**Solutions**:
```bash
# Check build agent resources
df -h  # Disk space
free -h  # Memory usage
iostat -x 1 5  # I/O performance

# Optimize build agent configuration
# Increase allocated resources
# Use faster storage for cache
# Improve network connectivity
```

#### Test Timeouts in CI
**Symptoms**: Tests timing out despite optimization
**Solutions**:
```bash
# Increase CI timeouts appropriately
unit_tests: 5m
integration_tests: 10m  
integration_tests_clean: 30m

# Add progress monitoring
VocorizeTests/scripts/test-integration.sh --ci --verbose

# Check for CI-specific issues
# Network throttling
# Resource constraints  
# Concurrent build interference
```

## Conclusion

Integrating Vocorize's optimized test infrastructure into CI/CD pipelines provides:

- **Dramatic Performance Improvement**: 90%+ reduction in build times
- **Reliable Caching**: Consistent performance across different build environments
- **Comprehensive Monitoring**: Detailed performance tracking and regression detection
- **Resource Efficiency**: Optimal use of CI/CD infrastructure resources

This integration ensures that the performance benefits achieved in local development are maintained and extended to automated build and deployment processes.