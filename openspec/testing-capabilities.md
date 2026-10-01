## Testing Capabilities

**Strict TDD Mode**: enabled
**Detected**: 2026-09-30

### Test Runner

- Command: `flutter test`
- Framework: flutter_test (Flutter 3.44.8 / Dart 3.12.2)

### Test Layers

| Layer       | Available | Tool            |
| ----------- | --------- | --------------- |
| Unit        | ✅        | flutter_test    |
| Widget      | ✅        | flutter_test (testWidgets) |
| Integration | ❌        | — (no `integration_test/`) |
| E2E         | ❌        | —               |

### Coverage

- Available: ✅
- Command: `flutter test --coverage` (no `coverage/` artifacts currently generated)

### Quality Tools

| Tool         | Available | Command             |
| ------------ | --------- | ------------------- |
| Linter       | ✅        | `flutter analyze` (flutter_lints) |
| Type checker | ✅        | `dart analyze`      |
| Formatter    | ✅        | `dart format`       |

### Notes

- **Known baseline**: `flutter test` → 189 passing, **7 pre-existing failures** in
  `test/core/database/schema_v14_test.dart` and `test/core/database/schema_v14_additional_tables_test.dart`
  (Drift/schema drift, unrelated to current work). Baseline capture:
  `%TEMP%\opencode\baseline_flutter_test.txt`. Do NOT treat these 7 as new failures.
- Test suite: 20 `*_test.dart` files (unit, provider, route-guard, widget tests).
- Drift code generation available via `dart run build_runner build`.
- Integration tests require an `integration_test/` directory plus `flutter drive` or patrol.
