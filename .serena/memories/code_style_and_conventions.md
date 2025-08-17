# Code Style and Conventions for Vocorize

## Swift Language & Version
- Swift 5.9 (Xcode 15.x required)
- **Critical**: Do NOT use Xcode 16/Swift 6.0 due to macro compatibility issues

## SwiftLint Configuration
The project uses SwiftLint with custom configuration in `.swiftlint.yml`:

### Disabled Rules
- `trailing_whitespace`
- `line_length` (custom limits applied)
- `force_cast`
- `identifier_name`
- `type_name`

### Enabled Optional Rules
- `empty_count`
- `closure_spacing`
- `collection_alignment`
- `contains_over_first_not_nil`
- `empty_string`
- `first_where`
- `force_unwrapping`
- `implicitly_unwrapped_optional`
- `last_where`
- `multiline_function_chains`
- `multiline_parameters`
- `operator_usage_whitespace`
- `overridden_super_call`
- `prefer_self_type_over_type_of_self`
- `redundant_nil_coalescing`
- `sorted_first_last`
- `trailing_closure`
- `unneeded_parentheses_in_closure_argument`
- `vertical_parameter_alignment_on_call`
- `yoda_condition`

### Custom Limits
- Line length: 150 warning, 200 error
- Function body: 60 warning, 100 error
- File length: 500 warning, 1000 error
- Type body: 300 warning, 500 error
- Function parameters: 6 warning, 8 error
- Cyclomatic complexity: 15 warning, 20 error

### Custom Rules
- TCA Reducer Protocol: Suggests using `ReducerProtocol` for TCA reducers

## Architecture Patterns

### The Composable Architecture (TCA)
- All features should use TCA pattern
- Reducers should conform to `ReducerProtocol`
- State management via `@Dependencies`
- Feature structure: State, Action, Reducer

### Dependency Injection
- Use TCA's `@Dependencies` for dependency injection
- Create client protocols for external dependencies
- Implement live and test versions of clients

### File Organization
```
Features/
├── FeatureName/
│   ├── FeatureNameView.swift
│   ├── FeatureNameFeature.swift
│   └── FeatureNameModels.swift
```

## Naming Conventions

### Files
- Features: `FeatureNameFeature.swift`
- Views: `FeatureNameView.swift`
- Clients: `ServiceNameClient.swift`
- Models: Descriptive names ending in model type

### Types
- Features: `FeatureNameFeature`
- Clients: `ServiceNameClient`
- Enums: PascalCase with descriptive names
- Protocols: Often end with `Client` for dependency protocols

### Variables and Functions
- camelCase for properties and methods
- Descriptive names preferred over abbreviations
- Boolean properties: `isEnabled`, `hasData`, etc.

## Code Organization

### Imports
- Foundation and system frameworks first
- Third-party dependencies next
- Internal imports last
- Alphabetical within each group

### Access Control
- Prefer `private` and `fileprivate` when possible
- Use `internal` as default
- `public` only when necessary for framework boundaries

### Comments and Documentation
- Minimal comments - prefer self-documenting code
- Use `// MARK: -` for section organization
- Document complex business logic and algorithms
- Avoid obvious comments

## Testing Conventions

### Test Structure
- Uses Swift Testing framework (not XCTest)
- Test files: `FeatureNameTests.swift`
- Use `@Test` attribute for test functions
- Descriptive test names: `testFeature_whenCondition_thenExpectedResult`

### Test Organization
- Group related tests in structs
- Use `#expect` for assertions
- Create helper functions for complex test scenarios
- Mock dependencies using TCA's dependency system

## Git Conventions

### Commit Messages
- Use conventional commit format
- Start with type: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`
- Keep first line under 50 characters
- Use imperative mood: "Add feature" not "Added feature"

### Branch Naming
- `feature/description`
- `fix/issue-description`
- `refactor/component-name`

## Error Handling
- Use Swift's `Result` type for failable operations
- Custom error types when appropriate
- Graceful degradation preferred over crashes
- Log errors appropriately for debugging