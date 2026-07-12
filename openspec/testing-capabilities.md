## Testing Capabilities

**Strict TDD Mode**: enabled
**Detected**: 2026-06-23

### Test Runner

- Command: `flutter test`
- Framework: flutter_test

### Test Layers

| Layer       | Available | Tool          |
| ----------- | --------- | ------------- |
| Unit        | ✅        | flutter_test  |
| Integration | ❌        | —             |
| E2E         | ❌        | —             |

### Coverage

- Available: ❌
- Command: —

### Quality Tools

| Tool         | Available | Command         |
| ------------ | --------- | --------------- |
| Linter       | ✅        | flutter_lints   |
| Type checker | ✅        | dart analyze    |
| Formatter    | ✅        | dart format     |

### Notes

- No `test/` directory exists yet — must create before first test run.
- Drift code generation via `build_runner` is available (`dart run build_runner build`).
- `flutter_test` provides widget testing, unit testing, and golden file testing.
- Integration tests require `integration_test/` directory and `flutter drive` or `patrol`.
