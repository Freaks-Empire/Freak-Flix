/// test/security/directory_traversal_test.dart
/// 
/// Tests for directory traversal attack prevention
import 'package:flutter_test/flutter_test.dart';
import 'package:freak_flix/services/data_backup_service.dart';
import 'package:freak_flix/utils/input_validation.dart';
import 'package:freak_flix/utils/path_guard.dart';
import 'package:path/path.dart' as p;
import '../helpers/security_test_helpers.dart';

void main() {
  group('Directory Traversal Protection Tests', () {
    group('Basic Directory Traversal', () {
      test('blocks forward slash traversal', () {
        final traversalAttempts = [
          '../../../etc/passwd',
          '../../etc/shadow',
          '../../../windows/system32/config/sam',
          '../.env',
          '../../config/database.yml',
        ];
        
        for (final attempt in traversalAttempts) {
          SecurityTestHelpers.expectSecurityBlocked(
            attempt,
            (input) => InputValidation.validateFilePath(input),
            customMessage: 'Forward slash traversal should be blocked: $attempt',
          );
        }
      });

      test('blocks backslash traversal', () {
        final windowsTraversal = [
          '..\\..\\..\\windows\\system32',
          '..\\..\\boot.ini',
          '..\\..\\..\\windows\\system32\\drivers\\etc\\hosts',
          '..\\.htaccess',
          '..\\..\\config.ini',
        ];
        
        for (final attempt in windowsTraversal) {
          SecurityTestHelpers.expectSecurityBlocked(
            attempt,
            (input) => InputValidation.validateFilePath(input),
            customMessage: 'Backslash traversal should be blocked: $attempt',
          );
        }
      });

      test('blocks mixed traversal patterns', () {
        final mixedTraversal = [
          '..\\../etc/passwd', // Mixed slashes
          '../..\\windows\\system32',
          '..\\..\\../config',
          '../..\\..\\.ssh',
        ];
        
        for (final attempt in mixedTraversal) {
          SecurityTestHelpers.expectSecurityBlocked(
            attempt,
            (input) => InputValidation.validateFilePath(input),
            customMessage: 'Mixed traversal should be blocked: $attempt',
          );
        }
      });
    });

    group('Multiple Traversal Sequences', () {
      test('blocks multiple dot sequences', () {
        final multipleDots = [
          '.../.../.../etc/passwd',
          '....\\....\\windows\\system32',
          '.../....\\.env',
          '....\\...\\...\\config',
        ];
        
        for (final attempt in multipleDots) {
          SecurityTestHelpers.expectSecurityBlocked(
            attempt,
            (input) => InputValidation.validateFilePath(input),
            customMessage: 'Multiple dot sequences should be blocked: $attempt',
          );
        }
      });

      test('blocks nested traversal attempts', () {
        final nestedTraversal = [
          '../a/../b/../c/../etc/passwd',
          '..\\a\\..\\b\\..\\c\\..\\windows',
          '../../a/b/../../../etc/shadow',
          '..\\..\\a\\..\\..\\b\\..\\..\\system32',
        ];
        
        for (final attempt in nestedTraversal) {
          SecurityTestHelpers.expectSecurityBlocked(
            attempt,
            (input) => InputValidation.validateFilePath(input),
            customMessage: 'Nested traversal should be blocked: $attempt',
          );
        }
      });
    });

    group('Unicode and Encoding Bypass Protection', () {
      test('blocks Unicode encoded traversal', () {
        final unicodeTraversal = [
          '/u002e/u002e/u002fetc/passwd', // Unicode dots and slash
          '/u002e/u002e/u002eu002fetc/passwd',
          '..%u002fetc/passwd', // Unicode slash
          '..%u002e%u002e%u002fetc/passwd',
        ];
        
        for (final attempt in unicodeTraversal) {
          SecurityTestHelpers.expectSecurityBlocked(
            attempt,
            (input) => InputValidation.validateFilePath(input),
            customMessage: 'Unicode traversal should be blocked: $attempt',
          );
        }
      });

      test('blocks URL encoded traversal', () {
        final urlEncoded = [
          '/%2e%2e%2fetc/passwd', // URL encoded ../
          '/%2e%2e%5cetc/passwd', // URL encoded ..\\
          '..%2f..%2f..%2fetc/passwd', // Multiple encoded traversal
          '..%5c..%5c..%5cwindows%5csystem32', // Windows backslash encoded
        ];
        
        for (final attempt in urlEncoded) {
          SecurityTestHelpers.expectSecurityBlocked(
            attempt,
            (input) => InputValidation.validateFilePath(input),
            customMessage: 'URL encoded traversal should be blocked: $attempt',
          );
        }
      });

      test('blocks UTF-8 overlong encoding', () {
        final utf8Overlong = [
          '/..%c0%afetc/passwd', // UTF-8 overlong /
          '/..%e0%80%afetc/passwd', // Another UTF-8 overlong variant
          '/..%c1%9cetc/passwd', // UTF-8 overlong backslash
        ];
        
        for (final attempt in utf8Overlong) {
          SecurityTestHelpers.expectSecurityBlocked(
            attempt,
            (input) => InputValidation.validateFilePath(input),
            customMessage: 'UTF-8 overlong traversal should be blocked: $attempt',
          );
        }
      });
    });

    group('Null Byte Injection Protection', () {
      test('blocks null byte injection in file paths', () {
        final nullByteAttacks = [
          'safe.txt\x00evil.exe',
          '/path\x00',
          'filename.txt\x00\x00malware.exe',
          'config.ini\x00malicious.bat',
          '.env\x00dangerous.php',
        ];
        
        for (final attack in nullByteAttacks) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateFilePath(input),
            customMessage: 'Null byte injection should be blocked: $attack',
          );
        }
      });

      test('blocks null byte at end of path', () {
        final nullByteEnd = [
          '/etc/passwd\x00',
          'C:\\Windows\\System32\\config\\sam\x00',
          '/home/user/.ssh/id_rsa\x00',
          '/var/log/auth.log\x00',
        ];
        
        for (final attack in nullByteEnd) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateFilePath(input),
            customMessage: 'Null byte end should be blocked: $attack',
          );
        }
      });
    });

    group('Path Normalization Bypass Protection', () {
      test('blocks current directory reference', () {
        final currentDirAttacks = [
          'foo/./bar/../../etc/passwd',
          '././../../etc/passwd',
          './config/../.env',
          './current/../../windows/system32',
        ];
        
        for (final attack in currentDirAttacks) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateFilePath(input),
            customMessage: 'Current directory bypass should be blocked: $attack',
          );
        }
      });

      test('blocks complex path normalization', () {
        final complexNormalization = [
          'foo/bar/../../../etc/passwd',
          'foo\\bar\\..\\..\\windows',
          '/var/www/./../../etc/passwd',
          'current/./.././../../windows/system32',
          'a/b/c/../../../root/.ssh',
        ];
        
        for (final attack in complexNormalization) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateFilePath(input),
            customMessage: 'Complex normalization should be blocked: $attack',
          );
        }
      });

      test('blocks case-based bypass attempts', () {
        final caseBypass = [
          '../ETC/passwd', // Uppercase
          '../Windows/System32', // Uppercase drive
          '../Etc/PASSWD', // All uppercase
          '../WINDOWS/system32/config', // Mixed case
        ];
        
        for (final bypass in caseBypass) {
          SecurityTestHelpers.expectSecurityBlocked(
            bypass,
            (input) => InputValidation.validateFilePath(input),
            customMessage: 'Case-based bypass should be blocked: $bypass',
          );
        }
      });
    });

    group('Platform-Specific Path Attacks', () {
      test('blocks Windows-specific attacks', () {
        final windowsAttacks = [
          '..\\..\\..\\windows\\system32\\config\\sam',
          '..\\..\\boot.ini',
          '..\\..\\..\\program files\\malware.exe',
          '..\\..\\..\\documents and settings\\all users\\desktop\\virus.exe',
        ];
        
        for (final attack in windowsAttacks) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateFilePath(input),
            customMessage: 'Windows-specific attack should be blocked: $attack',
          );
        }
      });

      test('blocks Unix-specific attacks', () {
        final unixAttacks = [
          '../../../etc/passwd',
          '../../../etc/shadow',
          '../../../etc/hosts',
            '../../../root/.ssh/id_rsa',
          '../../../home/user/.bashrc',
        ];
        
        for (final attack in unixAttacks) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateFilePath(input),
            customMessage: 'Unix-specific attack should be blocked: $attack',
          );
        }
      });
    });

    group('Comprehensive Directory Traversal Test Cases', () {
      test('covers all identified traversal techniques', () {
        final testCases = SecurityTestHelpers.generateDirectoryTraversalTestCases();
        
        for (final testCase in testCases) {
          SecurityTestHelpers.expectSecurityBlocked(
            testCase,
            (input) => InputValidation.validateFilePath(input),
            customMessage: 'Directory traversal technique should be blocked: $testCase',
          );
        }
      });
    });

    group('Service-level containment guard behavior', () {
      test('blocks encoded traversal before backup import path resolution', () {
        expect(
          () => DataBackupService.resolveBackupPathWithinRoot(
            '..%2f..%2fetc/passwd',
            allowedRoot: '/safe/exports',
            style: p.Style.posix,
          ),
          throwsA(isA<PathGuardException>()),
        );
      });

      test('blocks mixed separator traversal before backup export path resolution', () {
        expect(
          () => DataBackupService.resolveBackupPathWithinRoot(
            r'C:\safe\exports\..\..\Windows/System32/config/sam',
            allowedRoot: r'C:\safe\exports',
            style: p.Style.windows,
          ),
          throwsA(isA<PathGuardException>()),
        );
      });

      test('allows legitimate in-root backup file path', () {
        final resolved = DataBackupService.resolveBackupPathWithinRoot(
          r'C:\safe\exports\daily\backup.json',
          allowedRoot: r'C:\safe\exports',
          style: p.Style.windows,
        );

        expect(resolved, r'C:\safe\exports\daily\backup.json');
      });
    });

    group('Legitimate File Paths', () {
      test('allows legitimate file paths', () {
        final legitimatePaths = [
          'videos/movie.mp4',
          'document.pdf',
          'image.jpg',
          'music/song.mp3',
          'config/settings.json',
          'data/export.csv',
          'screenshots/screenshot.png',
          'logs/app.log',
          'temp/cache.db',
        ];
        
        for (final path in legitimatePaths) {
          SecurityTestHelpers.expectSecurityAllowed(
            path,
            (input) => InputValidation.validateFilePath(input),
            customMessage: 'Legitimate path should be allowed: $path',
          );
        }
      });

      test('allows legitimate subdirectory paths', () {
        final legitimateSubdirs = [
          'media/movies/action/film.mp4',
          'documents/important/report.pdf',
          'projects/code/main.dart',
          'downloads/software/installer.exe',
          'user_data/profile.json',
          'cache/images/thumbnails/photo.jpg',
        ];
        
        for (final path in legitimateSubdirs) {
          SecurityTestHelpers.expectSecurityAllowed(
            path,
            (input) => InputValidation.validateFilePath(input),
            customMessage: 'Legitimate subdirectory should be allowed: $path',
          );
        }
      });

      test('allows relative paths within current directory', () {
        final safeRelative = [
          './current_file.txt',
          './subdir/file.mp4',
          'subdir/document.pdf',
          '././double_current.jpg',
        ];
        
        for (final path in safeRelative) {
          SecurityTestHelpers.expectSecurityAllowed(
            path,
            (input) => InputValidation.validateFilePath(input),
            customMessage: 'Safe relative path should be allowed: $path',
          );
        }
      });
    });
  });
}
