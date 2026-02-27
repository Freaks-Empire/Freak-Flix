/// test/security/path_guard_test.dart
///
/// Unit tests for canonical path containment logic.
import 'package:flutter_test/flutter_test.dart';
import 'package:freak_flix/utils/path_guard.dart';
import 'package:path/path.dart' as p;

void main() {
  group('PathGuard', () {
    test('allows in-root POSIX relative path', () {
      final decision = PathGuard.evaluateContainedPath(
        candidatePath: 'exports/backup.json',
        allowedRoot: '/safe/root',
        style: p.Style.posix,
      );

      expect(decision.isAllowed, isTrue);
      expect(decision.resolvedPath, '/safe/root/exports/backup.json');
    });

    test('blocks normalized traversal escaping POSIX root', () {
      final decision = PathGuard.evaluateContainedPath(
        candidatePath: 'exports/../../etc/passwd',
        allowedRoot: '/safe/root',
        style: p.Style.posix,
      );

      expect(decision.isAllowed, isFalse);
      expect(decision.reason, contains('escapes'));
    });

    test('blocks URL-encoded traversal escaping POSIX root', () {
      final decision = PathGuard.evaluateContainedPath(
        candidatePath: '..%2f..%2fetc/passwd',
        allowedRoot: '/safe/root',
        style: p.Style.posix,
      );

      expect(decision.isAllowed, isFalse);
      expect(decision.reason, contains('escapes'));
    });

    test('blocks overlong-encoded traversal escaping POSIX root', () {
      final decision = PathGuard.evaluateContainedPath(
        candidatePath: '..%c0%af..%c0%afetc/passwd',
        allowedRoot: '/safe/root',
        style: p.Style.posix,
      );

      expect(decision.isAllowed, isFalse);
      expect(decision.reason, contains('escapes'));
    });

    test('allows in-root Windows mixed separator path', () {
      final decision = PathGuard.evaluateContainedPath(
        candidatePath: r'exports/subdir\\backup.json',
        allowedRoot: r'C:\Safe\Root',
        style: p.Style.windows,
      );

      expect(decision.isAllowed, isTrue);
      expect(decision.resolvedPath, r'C:\Safe\Root\exports\subdir\backup.json');
    });

    test('blocks Windows traversal that escapes root', () {
      final decision = PathGuard.evaluateContainedPath(
        candidatePath: r'..\..\Windows\System32\config\sam',
        allowedRoot: r'C:\Safe\Root',
        style: p.Style.windows,
      );

      expect(decision.isAllowed, isFalse);
      expect(decision.reason, contains('escapes'));
    });

    test('blocks absolute path when absolute candidates are disabled', () {
      final decision = PathGuard.evaluateContainedPath(
        candidatePath: '/safe/root/backup.json',
        allowedRoot: '/safe/root',
        style: p.Style.posix,
        allowAbsoluteCandidate: false,
      );

      expect(decision.isAllowed, isFalse);
      expect(decision.reason, contains('Absolute paths'));
    });
  });
}
