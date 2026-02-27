// lib/utils/security_policies.dart
// Centralized security policy constants used by validators.

class SecurityPolicies {
  static const Set<String> blockedHostTokens = {
    'localhost',
    'local',
    'internal',
    'gateway',
    'router',
    'modem',
    'dhcp',
    'broadcasthost',
    'ip6-localhost',
    'ip6-loopback',
  };

  static const Set<String> blockedMetadataHosts = {
    'metadata.google.internal',
    'metadata.google.internal.',
  };

  static const Set<String> blockedExactHosts = {
    '0.0.0.0',
    '127.0.0.1',
    '::1',
  };

  static const Set<int> blockedPorts = {
    23,
    25,
    53,
    135,
    139,
    445,
    993,
    995,
  };

  static const String securityHelpUrl =
      'https://owasp.org/www-community/attacks/Server_Side_Request_Forgery';
}
