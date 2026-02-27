// lib/utils/input_validation.dart
// Utilities for validating user input to prevent security issues.

import 'dart:io';

import 'package:path/path.dart' as p;

import 'path_guard.dart';
import 'security_policies.dart';
import 'security_validation_result.dart';

class InputValidation {
  static final RegExp _shellMetacharacters = RegExp(r'[;&|`$()<>]');
  static final RegExp _containsControlChars = RegExp(r'[\x00-\x1F\x7F]');
  static final RegExp _usernameAllowedChars = RegExp(r'^[a-zA-Z0-9._-]+$');
  static final RegExp _hostnamePattern = RegExp(
    r'^(?=.{1,253}$)(?!-)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)(?:\.(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?))*\.?$',
  );

  static String? validateHostname(String? hostname) {
    return strictValidateHostname(hostname).formError;
  }

  static SecurityValidationResult strictValidateHostname(String? hostname) {
    if (hostname == null || hostname.trim().isEmpty) {
      return const SecurityValidationResult.blocking(
        reason: 'Enter a server host.',
        fixExample: 'Try media.example.com',
        safeDefault: 'media.example.com',
      );
    }

    final canonicalInput = _canonicalize(hostname);
    final host = _extractHost(canonicalInput);
    if (host.isEmpty) {
      return const SecurityValidationResult.blocking(
        reason: 'Host format is not valid.',
        fixExample: 'Use a host such as media.example.com',
      );
    }

    final normalizedHost = host.toLowerCase();
    if (_containsBlockedHostToken(normalizedHost)) {
      return const SecurityValidationResult.blocking(
        reason: 'Local or internal targets are blocked for safety.',
        fixExample: 'Use a public host like media.example.com',
        safeDefault: 'media.example.com',
      );
    }

    if (_looksLikeBypassNotation(normalizedHost)) {
      return const SecurityValidationResult.blocking(
        reason: 'Encoded or alternate IP notations are blocked for safety.',
        fixExample: 'Use a normal public hostname like media.example.com',
        safeDefault: 'media.example.com',
      );
    }

    final ip = InternetAddress.tryParse(normalizedHost);
    if (ip != null && _isBlockedIp(ip)) {
      return const SecurityValidationResult.blocking(
        reason: 'Private, loopback, or metadata network targets are blocked.',
        fixExample: 'Use a public endpoint instead of an internal IP',
        safeDefault: 'media.example.com',
      );
    }

    if (normalizedHost == '169.254.169.254' ||
        normalizedHost.contains('metadata.google.internal')) {
      return const SecurityValidationResult.blocking(
        reason: 'Cloud metadata endpoints are blocked for safety.',
        fixExample: 'Use your storage service host instead',
        safeDefault: 'media.example.com',
      );
    }

    if (ip == null && !_hostnamePattern.hasMatch(normalizedHost)) {
      return const SecurityValidationResult.blocking(
        reason: 'Host format is not valid.',
        fixExample: 'Use letters, numbers, dots, and hyphens only',
      );
    }

    if (hostname.trim() != host) {
      return SecurityValidationResult.warning(
        reason: 'Host was normalized to remove extra formatting.',
        fixExample: 'Use $host',
        safeDefault: host,
      );
    }

    return const SecurityValidationResult.ok();
  }

  static SecurityValidationResult? getTypingHostWarning(String? hostname) {
    if (hostname == null || hostname.trim().isEmpty) {
      return null;
    }

    final strict = strictValidateHostname(hostname);
    if (strict.isBlocking) {
      return SecurityValidationResult.warning(
        reason: strict.reason,
        fixExample: strict.fixExample,
        safeDefault: strict.safeDefault,
      );
    }
    if (strict.isWarning) {
      return strict;
    }
    return null;
  }

  static String? getPrivateIpWarning(String? hostname) {
    final warning = getTypingHostWarning(hostname);
    return warning?.reason;
  }

  static String? validatePort(String? port) {
    return strictValidatePort(port).formError;
  }

  static SecurityValidationResult strictValidatePort(String? port) {
    if (port == null || port.trim().isEmpty) {
      return const SecurityValidationResult.blocking(
        reason: 'Enter a port number.',
        fixExample: 'Use 22 for SFTP, 21 for FTP, or 443 for WebDAV',
        safeDefault: '22',
      );
    }

    final parsed = int.tryParse(port.trim());
    if (parsed == null) {
      return const SecurityValidationResult.blocking(
        reason: 'Port must be a number.',
        fixExample: 'Enter a numeric port like 22',
        safeDefault: '22',
      );
    }

    if (parsed < 1 || parsed > 65535) {
      return const SecurityValidationResult.blocking(
        reason: 'Port must be between 1 and 65535.',
        fixExample: 'Use a valid port such as 22',
        safeDefault: '22',
      );
    }

    if (SecurityPolicies.blockedPorts.contains(parsed)) {
      return SecurityValidationResult.blocking(
        reason: 'Port $parsed is blocked for security reasons.',
        fixExample: 'Choose a service port like 22, 21, or 443',
        safeDefault: '22',
      );
    }

    if (port.trim() != port) {
      return SecurityValidationResult.warning(
        reason: 'Port was normalized by trimming spaces.',
        fixExample: 'Use ${port.trim()}',
        safeDefault: port.trim(),
      );
    }

    return const SecurityValidationResult.ok();
  }

  static String? validateUsername(String? username) {
    return strictValidateUsername(username).formError;
  }

  static SecurityValidationResult strictValidateUsername(String? username) {
    if (username == null || username.trim().isEmpty) {
      return const SecurityValidationResult.blocking(
        reason: 'Enter a username.',
        fixExample: 'Try media_user',
        safeDefault: 'media_user',
      );
    }

    final canonical = _canonicalize(username);
    final trimmed = canonical.trim();

    if (trimmed.length > 255) {
      return const SecurityValidationResult.blocking(
        reason: 'Username is too long.',
        fixExample: 'Use 255 characters or fewer',
      );
    }

    if (_containsControlChars.hasMatch(canonical)) {
      return const SecurityValidationResult.blocking(
        reason: 'Control characters are not allowed in usernames.',
        fixExample: 'Use letters, numbers, dots, dashes, or underscores only',
        safeDefault: 'media_user',
      );
    }

    if (_containsInjectionPayload(canonical)) {
      return const SecurityValidationResult.blocking(
        reason: 'This username includes unsafe command characters.',
        fixExample: 'Use a simple username like media_user',
        safeDefault: 'media_user',
      );
    }

    if (trimmed.contains('/') || trimmed.contains('\\') || trimmed.contains('..')) {
      return const SecurityValidationResult.blocking(
        reason: 'Path-style values are not allowed in usernames.',
        fixExample: 'Use only the account name, for example media_user',
        safeDefault: 'media_user',
      );
    }

    if (!_usernameAllowedChars.hasMatch(trimmed)) {
      return SecurityValidationResult.warning(
        reason: 'Username contains unusual characters and may fail.',
        fixExample: 'Use letters, numbers, dots, dashes, or underscores',
        safeDefault: _suggestSafeUsername(trimmed),
      );
    }

    if (username != trimmed) {
      return SecurityValidationResult.warning(
        reason: 'Username was normalized by trimming spaces.',
        fixExample: 'Use $trimmed',
        safeDefault: trimmed,
      );
    }

    return const SecurityValidationResult.ok();
  }

  static String _suggestSafeUsername(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return cleaned.isEmpty ? 'media_user' : cleaned;
  }

  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < 4) {
      return 'Password too short (minimum 4 characters)';
    }
    if (password.length > 1000) {
      return 'Password too long (max 1000 characters)';
    }

    if (_containsControlChars.hasMatch(password)) {
      return 'Password contains invalid characters';
    }

    return null;
  }

  static String? validateFilePath(String? path) {
    if (path == null || path.trim().isEmpty) {
      return 'Path is required';
    }

    final trimmed = path.trim();
    final canonical = _canonicalize(trimmed);

    final posixDecision = PathGuard.evaluateContainedPath(
      candidatePath: canonical,
      allowedRoot: '/allowed-root',
      style: p.Style.posix,
      allowAbsoluteCandidate: false,
    );
    final windowsDecision = PathGuard.evaluateContainedPath(
      candidatePath: canonical,
      allowedRoot: r'C:\allowed-root',
      style: p.Style.windows,
      allowAbsoluteCandidate: false,
    );

    if (!posixDecision.isAllowed || !windowsDecision.isAllowed) {
      return 'Path contains invalid characters or patterns';
    }

    final dangerousPatterns = <RegExp>[
      RegExp(r'\.\./', caseSensitive: false),
      RegExp(r'\.\.\\', caseSensitive: false),
      RegExp(r'\.{3,}[\\/]', caseSensitive: false),
      RegExp(r'%u[0-9a-f]{4}', caseSensitive: false),
      RegExp(r'^/', caseSensitive: false),
      RegExp(r'^\\', caseSensitive: false),
      RegExp(r'[<>:"|?*]'),
      RegExp(r'[\x00-\x1F]'),
    ];

    for (final pattern in dangerousPatterns) {
      if (pattern.hasMatch(trimmed)) {
        return 'Path contains invalid characters or patterns';
      }
    }

    if (trimmed.isEmpty || trimmed.length > 4096) {
      return 'Path too long';
    }

    return null;
  }

  static String? validateWebDavUrl(String? url) {
    return strictValidateWebDavUrl(url).formError;
  }

  static SecurityValidationResult strictValidateWebDavUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      return const SecurityValidationResult.blocking(
        reason: 'Enter a WebDAV URL.',
        fixExample: 'Use https://cloud.example.com/remote.php/dav',
      );
    }

    final normalized = _canonicalize(url).trim();
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.isEmpty) {
      return const SecurityValidationResult.blocking(
        reason: 'URL format is not valid.',
        fixExample: 'Use https://cloud.example.com/remote.php/dav',
      );
    }

    if (uri.scheme.toLowerCase() != 'https') {
      return const SecurityValidationResult.blocking(
        reason: 'WebDAV must use HTTPS.',
        fixExample: 'Use a URL that starts with https://',
      );
    }

    final hostValidation = strictValidateHostname(uri.host);
    if (hostValidation.isBlocking) {
      return SecurityValidationResult.blocking(
        reason: hostValidation.reason,
        fixExample: hostValidation.fixExample,
      );
    }

    if (url != normalized) {
      return SecurityValidationResult.warning(
        reason: 'URL was normalized by decoding and trimming.',
        fixExample: 'Use $normalized',
        safeDefault: normalized,
      );
    }

    return const SecurityValidationResult.ok();
  }

  static String sanitizeForLogging(String input) {
    if (input.isEmpty) return '[empty]';

    var sanitized = input;
    sanitized = sanitized.replaceAll(
      RegExp(r'password=.+$', caseSensitive: false),
      'password=[REDACTED]',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'token=.+$', caseSensitive: false),
      'token=[REDACTED]',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'key=.+$', caseSensitive: false),
      'key=[REDACTED]',
    );

    if (sanitized.length > 100) {
      sanitized = '${sanitized.substring(0, 100)}...[TRUNCATED]';
    }

    return sanitized;
  }

  static String? validateDisplayName(String? displayName) {
    if (displayName != null && displayName.trim().isNotEmpty) {
      final trimmed = displayName.trim();

      if (trimmed.length > 100) {
        return 'Display name too long (max 100 characters)';
      }

      if (RegExp(r'<[^>]*>', caseSensitive: false).hasMatch(trimmed)) {
        return 'Display name contains invalid characters';
      }
    }
    return null;
  }

  static bool _containsInjectionPayload(String input) {
    final lowered = input.toLowerCase();
    if (_shellMetacharacters.hasMatch(lowered)) {
      return true;
    }
    if (lowered.contains('&&') || lowered.contains('||')) {
      return true;
    }
    if (lowered.contains(r'${') || lowered.contains(r'$(')) {
      return true;
    }
    return false;
  }

  static String _canonicalize(String input) {
    var output = input.trim();
    for (var i = 0; i < 2; i++) {
      output = _decodeUriSafely(output);
    }
    output = _decodeHtmlEntities(output);
    return output;
  }

  static String _decodeUriSafely(String value) {
    try {
      return Uri.decodeFull(value);
    } catch (_) {
      return value;
    }
  }

  static String _decodeHtmlEntities(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }

  static String _extractHost(String input) {
    var candidate = input.trim();
    if (candidate.isEmpty) {
      return '';
    }

    final parsedUri = Uri.tryParse(candidate);
    if (parsedUri != null && parsedUri.host.isNotEmpty) {
      return parsedUri.host.trim().toLowerCase();
    }

    candidate = candidate.split(RegExp(r'[/?#]')).first;
    if (candidate.contains('@')) {
      candidate = candidate.split('@').last;
    }

    final colonCount = ':'.allMatches(candidate).length;
    if (!candidate.startsWith('[') && colonCount == 1) {
      candidate = candidate.split(':').first;
    }

    if (candidate.startsWith('[') && candidate.endsWith(']')) {
      candidate = candidate.substring(1, candidate.length - 1);
    }

    return candidate.trim().toLowerCase();
  }

  static bool _containsBlockedHostToken(String host) {
    for (final exact in SecurityPolicies.blockedExactHosts) {
      if (host == exact || host.contains(exact)) {
        return true;
      }
    }

    for (final metadataHost in SecurityPolicies.blockedMetadataHosts) {
      if (host == metadataHost || host.contains(metadataHost)) {
        return true;
      }
    }

    for (final token in SecurityPolicies.blockedHostTokens) {
      if (host == token || host.contains(token)) {
        return true;
      }
    }

    if (RegExp(r'(^|\.)127-0-0-1(\.|$)').hasMatch(host)) {
      return true;
    }
    if (RegExp(r'(^|\.)0{8}(\.|$)').hasMatch(host)) {
      return true;
    }

    return false;
  }

  static bool _looksLikeBypassNotation(String host) {
    if (host.contains('%')) {
      return true;
    }
    if (RegExp(r'^\d{8,10}$').hasMatch(host)) {
      return true;
    }
    if (RegExp(r'^0x[0-9a-f]+$').hasMatch(host)) {
      return true;
    }
    if (RegExp(r'^0[0-7]{7,}$').hasMatch(host)) {
      return true;
    }
    return false;
  }

  static bool _isBlockedIp(InternetAddress ip) {
    if (ip.isLoopback || ip.isLinkLocal || ip.isMulticast) {
      return true;
    }

    if (ip.type == InternetAddressType.IPv4) {
      final parts = ip.address.split('.').map(int.parse).toList();
      if (_isBlockedIpv4Octets(parts)) {
        return true;
      }
    }

    if (ip.type == InternetAddressType.IPv6) {
      final addr = ip.address.toLowerCase();
      final raw = ip.rawAddress;

      final isIpv4Mapped = raw.length == 16 &&
          raw.sublist(0, 10).every((byte) => byte == 0) &&
          raw[10] == 0xff &&
          raw[11] == 0xff;
      if (isIpv4Mapped) {
        final mapped = raw.sublist(12, 16);
        if (_isBlockedIpv4Octets(mapped)) {
          return true;
        }
      }

      if (addr.startsWith('fc') || addr.startsWith('fd')) {
        return true;
      }
      if (addr.startsWith('fe8') || addr.startsWith('fe9') ||
          addr.startsWith('fea') || addr.startsWith('feb')) {
        return true;
      }
      if (addr == '::1' || addr.startsWith('::ffff:127.')) {
        return true;
      }
    }

    return false;
  }

  static bool _isBlockedIpv4Octets(List<int> parts) {
    if (parts[0] == 0 && parts[1] == 0 && parts[2] == 0 && parts[3] == 0) {
      return true;
    }

    final isPrivate = parts[0] == 10 ||
        (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) ||
        (parts[0] == 192 && parts[1] == 168) ||
        (parts[0] == 127) ||
        (parts[0] == 169 && parts[1] == 254);
    if (isPrivate) {
      return true;
    }

    final isCarrierGradeNat = parts[0] == 100 && parts[1] >= 64 && parts[1] <= 127;
    if (isCarrierGradeNat) {
      return true;
    }

    final isBenchmark = parts[0] == 198 && (parts[1] == 18 || parts[1] == 19);
    if (isBenchmark) {
      return true;
    }

    if (parts[0] >= 224) {
      return true;
    }

    return false;
  }
}
