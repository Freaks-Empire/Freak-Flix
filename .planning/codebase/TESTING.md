# Testing Patterns

**Analysis Date:** 2026-02-27

## Test Framework

**Runner:**
- Flutter test runner via `package:flutter_test/flutter_test.dart`.
- Config: Not detected (`dart_test.yaml`, `jest.config.*`, `vitest.config.*` are absent).

**Assertion Library:**
- Built-in matcher/assertion APIs from `flutter_test` (`expect`, `isNull`, `isNotNull`) in `test/security/*.dart` and `test/helpers/security_test_helpers.dart`.

**Run Commands:**
```bash
flutter test                                  # Run all tests
flutter test test/security/command_injection_test.dart  # Run one suite file
flutter test --coverage                       # Generate coverage in coverage/
```

## Test File Organization

**Location:**
- Tests live under `test/` with domain subfolders.
- Current layout is security-focused:
  - `test/security/ssrf_test.dart`
  - `test/security/directory_traversal_test.dart`
  - `test/security/command_injection_test.dart`
  - shared helpers in `test/helpers/security_test_helpers.dart`

**Naming:**
- Use `*_test.dart` naming.
- Use suite names that match threat category in `group()` descriptions.

**Structure:**
```
test/
├── helpers/
│   └── security_test_helpers.dart
└── security/
    ├── command_injection_test.dart
    ├── directory_traversal_test.dart
    └── ssrf_test.dart
```

## Test Structure

**Suite Organization:**
```typescript
void main() {
  group('Command Injection Protection Tests', () {
    group('Basic Command Injection', () {
      test('blocks semicolon injection', () {
        final semicolonAttacks = [
          'user; rm -rf /',
          'username; cat /etc/passwd',
        ];

        for (final attack in semicolonAttacks) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateUsername(input),
            customMessage: 'Semicolon injection should be blocked: $attack',
          );
        }
      });
    });
  });
}
```

**Patterns:**
- Use nested `group()` blocks by vulnerability class and sub-technique (`test/security/*.dart`).
- Use table-driven loops (`for (final attack in attacks)`) for broad input coverage.
- Use helper assertions from `SecurityTestHelpers` to keep tests concise and consistent.

## Mocking

**Framework:**
- No Mockito/mocktail framework detected.
- Lightweight manual mock type is used for HTTP-style payloads.

**Patterns:**
```typescript
class MockHttpResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;

  const MockHttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });
}
```

**What to Mock:**
- Mock external response shapes when validating parsing/sanitization behavior (pattern in `test/helpers/security_test_helpers.dart`).
- Keep mocks deterministic and static (`const` responses like `ok`, `unauthorized`, `serverError`).

**What NOT to Mock:**
- Do not mock pure validation functions in `lib/utils/input_validation.dart`; call them directly with attack/safe inputs.
- Avoid network calls in security tests; all current tests are pure input/output assertions.

## Fixtures and Factories

**Test Data:**
```typescript
static List<String> generateDirectoryTraversalTestCases() {
  return [
    '../../../etc/passwd',
    '..\\..\\..\\windows\\system32',
    '/%2e%2e%2fetc/passwd',
    'safe.txt\x00evil.exe',
  ];
}
```

**Location:**
- Centralized generators and fixture-like helpers live in `test/helpers/security_test_helpers.dart`.

## Coverage

**Requirements:**
- No enforced threshold detected in repo config or CI workflows.
- Coverage command exists in developer guidance (`AGENTS.md`) but CI workflows under `.github/workflows/` build only and do not run tests.

**View Coverage:**
```bash
flutter test --coverage
```

## Test Types

**Unit Tests:**
- Predominant pattern; tests target pure validators in `lib/utils/input_validation.dart`.
- Inputs are exhaustive attack vectors and expected safe samples.

**Integration Tests:**
- Not detected (`integration_test/` directory not present).

**E2E Tests:**
- Not used (no `integration_test`, Patrol, or device automation framework detected).

## Common Patterns

**Async Testing:**
```typescript
// Current suites are synchronous; async/await usage is not a common pattern in test/security/*.dart.
```

**Error Testing:**
```typescript
SecurityTestHelpers.expectSecurityBlocked(
  input,
  (value) => InputValidation.validateHostname(value),
  customMessage: 'SSRF bypass technique should be blocked: $input',
);
```

---

*Testing analysis: 2026-02-27*
