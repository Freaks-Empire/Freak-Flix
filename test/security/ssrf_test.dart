/// test/security/ssrf_test.dart
/// 
/// Tests for Server-Side Request Forgery (SSRF) protection
import 'package:flutter_test/flutter_test.dart';
import 'package:freak_flix/utils/input_validation.dart';
import '../helpers/security_test_helpers.dart';

void main() {
  group('SSRF Protection Tests', () {
    group('Private IP Range Blocking', () {
      test('blocks IPv4 private ranges', () {
        final privateIps = [
          '10.0.0.1',
          '10.255.255.254',
          '172.16.0.1',
          '172.31.255.254',
          '192.168.0.1',
          '192.168.255.254',
          '127.0.0.1',
          '169.254.0.1',
        ];
        
        for (final ip in privateIps) {
          SecurityTestHelpers.expectSecurityBlocked(
            ip,
            (input) => InputValidation.validateHostname(input),
          );
        }
      });

      test('blocks missing private IP ranges', () {
        // These should be blocked but currently aren't in the implementation
        final missingRanges = [
          '100.64.0.1', // CGNAT range 100.64.0.0/10
          '100.127.255.254',
          '198.18.0.1', // Benchmark testing 198.18.0.0/15
          '198.19.255.254',
        ];
        
        for (final ip in missingRanges) {
          SecurityTestHelpers.expectSecurityBlocked(
            ip,
            (input) => InputValidation.validateHostname(input),
            customMessage: 'Missing private IP range should be blocked: $ip',
          );
        }
      });

      test('allows public IP ranges', () {
        final publicIps = [
          '8.8.8.8', // Google DNS
          '1.1.1.1', // Cloudflare DNS
          '208.67.222.222', // OpenDNS
          '9.9.9.9', // Quad9 DNS
          '64.233.191.255', // Google
        ];
        
        for (final ip in publicIps) {
          SecurityTestHelpers.expectSecurityAllowed(
            ip,
            (input) => InputValidation.validateHostname(input),
          );
        }
      });
    });

    group('IPv6 Address Validation', () {
      test('blocks IPv6 localhost variations', () {
        final ipv6Localhost = [
          '::1',
          '::ffff:127.0.0.1',
          '0:0:0:0:0:ffff:7f00:1',
          '::ffff:0:0',
          '0:0:0:0:0:0:0:1',
        ];
        
        for (final ipv6 in ipv6Localhost) {
          SecurityTestHelpers.expectSecurityBlocked(
            ipv6,
            (input) => InputValidation.validateHostname(input),
            customMessage: 'IPv6 localhost should be blocked: $ipv6',
          );
        }
      });

      test('blocks IPv6 private ranges', () {
        final ipv6Private = [
          'fc00::1', // Unique local
          'fd00::1', // Unique local
          'fe80::1', // Link-local
        ];
        
        for (final ipv6 in ipv6Private) {
          SecurityTestHelpers.expectSecurityBlocked(
            ipv6,
            (input) => InputValidation.validateHostname(input),
          );
        }
      });
    });

    group('IP Notation Bypass Protection', () {
      test('blocks decimal IP notation', () {
        final decimalIps = [
          '2130706433', // 127.0.0.1 decimal
          '3221225472', // 192.0.2.0 decimal (RFC 5737)
          '2886729728', // 172.16.0.0 decimal
          '16843009', // 1.1.1.1 decimal
        ];
        
        for (final decimalIp in decimalIps) {
          SecurityTestHelpers.expectSecurityBlocked(
            decimalIp,
            (input) => InputValidation.validateHostname(input),
            customMessage: 'Decimal IP notation should be blocked: $decimalIp',
          );
        }
      });

      test('blocks hexadecimal IP notation', () {
        final hexIps = [
          '0x7F000001', // 127.0.0.1 hex
          '0x7F000002', // 127.0.0.2 hex
          '0xAC100001', // 172.16.0.1 hex
          '0xC0A80101', // 192.168.1.1 hex
        ];
        
        for (final hexIp in hexIps) {
          SecurityTestHelpers.expectSecurityBlocked(
            hexIp,
            (input) => InputValidation.validateHostname(input),
            customMessage: 'Hexadecimal IP notation should be blocked: $hexIp',
          );
        }
      });

      test('blocks octal IP notation', () {
        final octalIps = [
          '017700000001', // 127.0.0.1 octal
          '037777777777', // 255.255.255.255 octal
          '025400000001', // 172.64.0.1 octal
        ];
        
        for (final octalIp in octalIps) {
          SecurityTestHelpers.expectSecurityBlocked(
            octalIp,
            (input) => InputValidation.validateHostname(input),
            customMessage: 'Octal IP notation should be blocked: $octalIp',
          );
        }
      });
    });

    group('DNS Rebinding Protection', () {
      test('blocks DNS rebinding attempts', () {
        final rebindingAttempts = [
          '127.0.0.1.example.com',
          'localhost.example.com',
          '127-0-0-1.example.com',
          '00000000.example.com', // Resolves to 0.0.0.0
          'localhost.org',
          '127.0.0.1.nip.io',
          'localhost.sslip.io',
        ];
        
        for (final hostname in rebindingAttempts) {
          SecurityTestHelpers.expectSecurityBlocked(
            hostname,
            (input) => InputValidation.validateHostname(input),
            customMessage: 'DNS rebinding attempt should be blocked: $hostname',
          );
        }
      });

      test('blocks internal hostnames', () {
        final internalHostnames = [
          'localhost',
          '127.0.0.1',
          '0.0.0.0',
          '::1',
          'local',
          'internal',
          'gateway',
          'router',
          'modem',
          'dhcp',
          'broadcasthost',
          'ip6-localhost',
          'ip6-loopback',
        ];
        
        for (final hostname in internalHostnames) {
          SecurityTestHelpers.expectSecurityBlocked(
            hostname,
            (input) => InputValidation.validateHostname(input),
          );
        }
      });
    });

    group('URL Encoding Bypass Protection', () {
      test('blocks URL encoded bypass attempts', () {
        final encodedAttempts = [
          '12%37.0.0.1', // %37 = 7, resolves to 127.0.0.1
          '127%2E0%2E0%2E1', // %2E = .
          '192%2E168%2E1%2E1', // 192.168.1.1
          '10%2E0%2E0%2E1', // 10.0.0.1
        ];
        
        for (final encoded in encodedAttempts) {
          SecurityTestHelpers.expectSecurityBlocked(
            encoded,
            (input) => InputValidation.validateHostname(input),
            customMessage: 'URL encoded bypass should be blocked: $encoded',
          );
        }
      });

      test('blocks double URL encoding', () {
        final doubleEncoded = [
          '12%2537.0.0.1', // %2537 = %37 = 7
          '127%252E0%252E0%252E1', // %252E = %2E = .
        ];
        
        for (final doubleEncoded in doubleEncoded) {
          SecurityTestHelpers.expectSecurityBlocked(
            doubleEncoded,
            (input) => InputValidation.validateHostname(input),
            customMessage: 'Double URL encoded bypass should be blocked: $doubleEncoded',
          );
        }
      });
    });

    group('Cloud Provider Metadata Protection', () {
      test('blocks cloud metadata endpoints', () {
        final metadataEndpoints = [
          'metadata.google.internal',
          '169.254.169.254',
          'metadata.google.internal:80',
          '169.254.169.254/latest/api/token',
          '169.254.169.254/latest/user-data',
          '169.254.169.254/latest/meta-data/iam/security-credentials',
        ];
        
        for (final endpoint in metadataEndpoints) {
          SecurityTestHelpers.expectSecurityBlocked(
            endpoint,
            (input) => InputValidation.validateHostname(input),
            customMessage: 'Cloud metadata endpoint should be blocked: $endpoint',
          );
        }
      });
    });

    group('Comprehensive SSRF Test Cases', () {
      test('covers all identified SSRF bypass techniques', () {
        final testCases = SecurityTestHelpers.generateSsrffTestCases();
        
        for (final testCase in testCases) {
          SecurityTestHelpers.expectSecurityBlocked(
            testCase,
            (input) => InputValidation.validateHostname(input),
            customMessage: 'SSRF bypass technique should be blocked: $testCase',
          );
        }
      });
    });

    group('Legitimate Hostnames', () {
      test('allows legitimate domain names', () {
        final legitimateDomains = [
          'google.com',
          'github.com',
          'themoviedb.org',
          'anilist.co',
          'stashdb.cc',
          'example.com',
          'api.themoviedb.org',
          'graph.microsoft.com',
          'dl.dropboxusercontent.com',
        ];
        
        for (final domain in legitimateDomains) {
          SecurityTestHelpers.expectSecurityAllowed(
            domain,
            (input) => InputValidation.validateHostname(input),
          );
        }
      });

      test('allows legitimate subdomains', () {
        final legitimateSubdomains = [
          'api.themoviedb.org',
          'graph.microsoft.com',
          'dl.dropboxusercontent.com',
          'cdn.example.com',
          'static.github.com',
        ];
        
        for (final subdomain in legitimateSubdomains) {
          SecurityTestHelpers.expectSecurityAllowed(
            subdomain,
            (input) => InputValidation.validateHostname(input),
          );
        }
      });
    });
  });
}