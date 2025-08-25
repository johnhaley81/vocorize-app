# Vocorize CI/CD Pipeline Guide

This document describes the optimized CI/CD pipeline configuration designed to balance speed, coverage, and resource efficiency for the Vocorize application.

## Pipeline Architecture Overview

The CI/CD system uses a **tiered testing strategy** that optimizes feedback speed while ensuring comprehensive coverage:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐    ┌──────────────────┐
│   PR Validation │    │ Main Validation  │    │ Nightly Tests   │    │ Release Pipeline │
│   < 2 minutes   │    │   < 20 minutes   │    │  < 90 minutes   │    │   < 120 minutes  │
└─────────────────┘    └──────────────────┘    └─────────────────┘    └──────────────────┘
         │                        │                        │                        │
    Unit Tests Only      Unit + Critical         Full Test Suite      Complete Validation
    (MockProviders)      Integration Tests      (Real WhisperKit)     + Performance + Build
```

## Test Categories

### 1. Unit Tests (Fast - <10 seconds)
**Purpose**: Fast feedback for core logic validation
**Uses**: `MockWhisperKitProvider` for instant responses
**Coverage**:
- Core hotkey processing logic (`VocorizeTests`)
- WhisperKit provider unit tests (`WhisperKitProviderTests`)
- Transcription client validation (`TranscriptionProviderTests`)
- Model configuration tests (`ModelConfigurationTests`)
- MLX provider registration (`MLXProviderRegistrationTests`)

### 2. Integration Tests (Slow - 5-30 minutes)
**Purpose**: Real-world validation with actual ML models
**Uses**: Real `WhisperKitProvider` with model downloads
**Coverage**:
- Actual WhisperKit model downloads (`WhisperKitIntegrationTests`)
- MLX framework compatibility (`MLXIntegrationTests`)
- Full system integration (`ProviderSystemIntegrationTests`)
- Cross-provider compatibility (`MLXSystemCompatibilityTests`)

## Pipeline Configurations

### 1. Pull Request Validation (`.github/workflows/pr-validation.yml`)

**Trigger**: Every PR to `main` or `develop`  
**Duration**: <2 minutes  
**Strategy**: Fast feedback only

```yaml
Features:
- ✅ Unit tests only (mocked providers)
- ✅ SwiftLint validation
- ✅ Build verification
- ✅ Performance regression detection
- 🚫 No model downloads
- 🚫 No network dependencies
```

**Environment Variables**:
```bash
VOCORIZE_TEST_MODE=unit
VOCORIZE_SKIP_MODEL_DOWNLOADS=true
VOCORIZE_MOCK_PROVIDERS_ONLY=true
```

### 2. Main Branch Validation (`.github/workflows/main-validation.yml`)

**Trigger**: Push to `main` branch  
**Duration**: <20 minutes  
**Strategy**: Balanced validation

```yaml
Features:
- ✅ All unit tests (fast completion)
- ✅ Critical integration tests (selective)
- ✅ Performance regression monitoring
- ✅ Security scanning
- ✅ Deployment readiness assessment
- ⚠️ Limited model downloads (tiny models only)
```

**Test Matrix**:
- **WhisperKit Tiny Model** (8min timeout): Basic integration validation
- **MLX Availability** (5min timeout): MLX compatibility check  
- **Provider Integration** (10min timeout): Cross-provider functionality

### 3. Nightly Test Suite (`.github/workflows/nightly-tests.yml`)

**Trigger**: Daily at 2 AM UTC + manual dispatch  
**Duration**: <90 minutes  
**Strategy**: Comprehensive validation

```yaml
Test Matrix:
- Unit Tests (10min): Complete unit test coverage
- WhisperKit Integration (30min): Multiple model sizes
- MLX Integration (20min): MLX framework validation
- Provider Integration (25min): Cross-provider testing
- System Integration (45min): End-to-end scenarios
- Performance Benchmarks (40min): Performance validation
```

**Model Coverage**:
- `openai_whisper-tiny`: Fast downloads, basic functionality
- `openai_whisper-base`: Balanced performance/accuracy
- `openai_whisper-small`: Better accuracy validation
- `mlx-community/whisper-tiny-mlx`: MLX framework testing

### 4. Release Validation (`.github/workflows/release-validation.yml`)

**Trigger**: Version tags (`v*.*.*`) + release branches  
**Duration**: <120 minutes  
**Strategy**: Complete validation

```yaml
Validation Steps:
1. Pre-release checks (version, format, notes)
2. Comprehensive test suite (all test categories)
3. Performance benchmarks (regression detection)
4. Build validation (archive creation)
5. Security validation (code quality, dependencies)
6. Release readiness assessment
```

## Performance Targets

### Test Duration Targets
```yaml
Unit Tests:        < 10 seconds    (Target: 5s)
Critical Integration: < 15 minutes   (Target: 10m)
Full Integration:  < 60 minutes   (Target: 45m)
Complete Release:  < 120 minutes  (Target: 90m)
```

### Pipeline Duration Targets
```yaml
PR Validation:     < 2 minutes     (Fast feedback)
Main Validation:   < 20 minutes    (Balanced)
Nightly Tests:     < 90 minutes    (Comprehensive)
Release Pipeline:  < 120 minutes   (Complete)
```

## Resource Management

### Caching Strategy
```yaml
Swift Package Manager:
  - Key: Based on Package.resolved hash
  - Shared across pipeline stages
  - 7-day retention

ML Models:
  - Separate cache for each model type
  - Persistent across nightly runs
  - Cleanup after release tests

Build Artifacts:
  - DerivedData caching
  - Incremental build optimization
  - 30-day retention for release builds
```

### Model Management
```yaml
Unit Tests:
  - No model downloads
  - Mock providers only
  
Integration Tests:
  - Selective model downloads
  - Cache-first strategy
  - Cleanup on failure

Release Tests:
  - Complete model validation
  - Integrity checks
  - Cleanup after completion
```

## Failure Handling

### Fast Failure Strategy
```yaml
PR Validation:
  - Fail fast on any error
  - Block merge on failure
  
Main Branch:
  - Continue on integration failures
  - Deploy to staging if unit tests pass
  
Nightly:
  - Continue all tests regardless
  - Create issues for failures
  
Release:
  - Fail on critical errors
  - Allow warnings for non-critical issues
```

### Error Classification
```yaml
Critical Errors (Block deployment):
  - Unit test failures
  - Build failures  
  - Security vulnerabilities
  
Warnings (Log but continue):
  - Integration test failures
  - Performance regressions
  - Non-critical security issues
```

## Usage Examples

### Local Development
```bash
# Fast unit tests (development)
VOCORIZE_TEST_MODE=unit ./test.sh

# Mixed testing (pre-commit)
VOCORIZE_TEST_MODE=mixed ./test.sh

# Integration testing (feature validation)
VOCORIZE_TEST_MODE=integration ./test.sh

# Verbose debugging
VOCORIZE_VERBOSE=true VOCORIZE_TEST_MODE=unit ./test.sh
```

### Manual Pipeline Triggers
```bash
# Trigger nightly tests with specific scope
gh workflow run nightly-tests.yml -f test_scope=whisperkit-only

# Trigger release validation
gh workflow run release-validation.yml -f release_version=v1.2.3

# Debug integration issues
gh workflow run main-validation.yml -f run_integration_tests=all
```

## Monitoring and Alerts

### Performance Monitoring
- Unit test duration tracking
- Integration test timing
- Model download performance
- Memory usage during tests

### Failure Notifications
- Automatic GitHub issue creation for nightly failures
- Performance regression alerts
- Security vulnerability detection

### Success Metrics
- PR merge time (target: <5 minutes from submission)
- Main branch confidence (target: >95% success rate)
- Release readiness (target: <24 hours validation time)

## Deployment Gates

### Staging Deployment
```yaml
Required:
  ✅ Unit tests pass
  ✅ Security scan clean
  
Optional:
  ⚠️ Critical integration tests (can deploy with warnings)
```

### Production Deployment
```yaml
Required:
  ✅ All unit tests pass
  ✅ Critical integration tests pass
  ✅ Security validation clean
  ✅ Performance benchmarks within limits
  ✅ Build validation successful
  
Blocking:
  ❌ Active security vulnerabilities
  ❌ Performance regressions
  ❌ Critical test failures
```

## Best Practices

### For Developers
1. **Run unit tests locally** before pushing
2. **Use `VOCORIZE_TEST_MODE=unit`** for fastest feedback
3. **Check performance metrics** in test output
4. **Review integration test results** on main branch

### For CI/CD Maintenance
1. **Monitor cache hit rates** and adjust retention
2. **Track pipeline duration trends** and optimize
3. **Review nightly test failures** weekly
4. **Update model lists** as new versions become available

### For Release Management
1. **Always run release validation** before tagging
2. **Review security scan results** carefully
3. **Check performance benchmarks** for regressions
4. **Validate model compatibility** across versions

This pipeline architecture ensures rapid developer feedback while maintaining comprehensive validation for production releases, optimizing the balance between speed and confidence in a fast-paced development environment.