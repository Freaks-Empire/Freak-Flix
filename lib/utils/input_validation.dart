/// lib/utils/input_validation.dart
/// Utilities for validating user input to prevent security issues

class InputValidation {
  // Private networks to prevent SSRF attacks
  static final List<String> _privateNetworks = [
    '10.',
    '172.16.',
    '172.17.',
    '172.18.',
    '172.19.',
    '172.20.',
    '172.21.',
    '172.22.',
    '172.23.',
    '172.24.',
    '172.25.',
    '172.26.',
    '172.27.',
    '172.28.',
    '172.29.',
    '172.30.',
    '172.31.',
    '192.168.',
    '127.',
    '169.254.',
    '169.254.',
    '224.', // Multicast
    '240.', // Reserved
  ];

  // Special hostnames to block
  static final List<String> _blockedHostnames = [
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
  ];

  // File path patterns to prevent directory traversal
  static final List<RegExp> _dangerousPatterns = [
    RegExp(r'\.\./', caseSensitive: false), // Directory traversal
    RegExp(r'\.\\', caseSensitive: false), // Windows traversal
    RegExp(r'^/', caseSensitive: false), // Absolute path
    RegExp(r'^\\', caseSensitive: false), // Windows UNC path
    RegExp(r'[<>:"|?*]'), // Invalid filename characters
    RegExp(r'[\x00-\x1F]'), // Control characters
  ];

  /// Validates hostname for SSRF protection
  static String? validateHostname(String? hostname) {
    if (hostname == null || hostname.trim().isEmpty) {
      return 'Host is required';
    }

    final trimmed = hostname.trim();

    // Length validation
    if (trimmed.length > 253) {
      return 'Hostname too long (max 253 characters)';
    }

    // Check for blocked hostnames
    for (final blocked in _blockedHostnames) {
      if (trimmed.toLowerCase().contains(blocked)) {
        return 'Local/internal hostnames not allowed';
      }
    }

    // Check for private IP ranges
    for (final network in _privateNetworks) {
      if (trimmed.startsWith(network)) {
        return 'Private IP addresses not allowed';
      }
    }

    // Basic hostname format validation
    if (!RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9\-\.]*[a-zA-Z0-9])?$').hasMatch(trimmed)) {
      if (!RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(trimmed)) {
        return 'Invalid hostname format';
      }
    }

    // Prevent URL injection
    if (trimmed.contains('http://') || trimmed.contains('https://') || 
        trimmed.contains('ftp://') || trimmed.contains('sftp://') ||
        trimmed.contains('://')) {
      return 'Protocol prefixes not allowed in hostname';
    }

    // Prevent path injection in hostname
    if (trimmed.contains('/') || trimmed.contains('\\')) {
      return 'Hostname cannot contain paths';
    }

    return null;
  }

  /// Validates port number
  static String? validatePort(String? port) {
    if (port == null || port.trim().isEmpty) {
      return 'Port is required';
    }

    final portNum = int.tryParse(port.trim());
    if (portNum == null) {
      return 'Invalid port number';
    }

    if (portNum < 1 || portNum > 65535) {
      return 'Port must be between 1 and 65535';
    }

    // Block common administrative ports (except for specific protocols)
    final blockedPorts = {22, 23, 25, 53, 135, 139, 445, 993, 995};
    if (blockedPorts.contains(portNum)) {
      return 'Port $portNum is not allowed for security reasons';
    }

    return null;
  }

  /// Validates username
  static String? validateUsername(String? username) {
    if (username == null || username.trim().isEmpty) {
      return 'Username is required';
    }

    final trimmed = username.trim();

    // Length validation
    if (trimmed.length < 1) {
      return 'Username cannot be empty';
    }
    if (trimmed.length > 255) {
      return 'Username too long (max 255 characters)';
    }

    // Prevent command injection
    if (RegExp(r'[;&|`$()]').hasMatch(trimmed)) {
      return 'Username contains invalid characters';
    }

    // Prevent path traversal
    if (trimmed.contains('/') || trimmed.contains('\\') || trimmed.contains('..')) {
      return 'Username cannot contain paths';
    }

    return null;
  }

  /// Validates password
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }

    // Length validation (reasonable minimum)
    if (password.length < 4) {
      return 'Password too short (minimum 4 characters)';
    }
    if (password.length > 1000) {
      return 'Password too long (max 1000 characters)';
    }

    // Prevent control characters
    if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(password)) {
      return 'Password contains invalid characters';
    }

    return null;
  }

  /// Validates file path for directory traversal
  static String? validateFilePath(String? path) {
    if (path == null || path.trim().isEmpty) {
      return 'Path is required';
    }

    final trimmed = path.trim();

    // Check for dangerous patterns
    for (final pattern in _dangerousPatterns) {
      if (pattern.hasMatch(trimmed)) {
        return 'Path contains invalid characters or patterns';
      }
    }

    // Prevent extremely long paths
    if (trimmed.isEmpty || trimmed.length > 4096) {
      return 'Path too long';
    }

    return null;
  }

  /// Validates WebDAV URL format
  static String? validateWebDavUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      return 'URL is required';
    }

    final trimmed = url.trim();

    // Basic URL format validation
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(trimmed)) {
      return 'WebDAV URL must start with http:// or https://';
    }

    // Prevent localhost in URLs
    if (RegExp(r'https?://(localhost|127\.0\.0\.1|0\.0\.0\.0|::1)', caseSensitive: false).hasMatch(trimmed)) {
      return 'Local URLs not allowed';
    }

    // Check for private IP in URL
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.host.isNotEmpty) {
      final hostnameValidation = validateHostname(uri.host);
      if (hostnameValidation != null) {
        return 'Invalid URL: $hostnameValidation';
      }
    }

    return null;
  }

  /// Sanitizes input for safe logging
  static String sanitizeForLogging(String input) {
    if (input.isEmpty) return '[empty]';
    
    // Remove sensitive patterns
    String sanitized = input;
    sanitized = sanitized.replaceAll(RegExp(r'password=.+$', caseSensitive: false), 'password=[REDACTED]');
    sanitized = sanitized.replaceAll(RegExp(r'token=.+$', caseSensitive: false), 'token=[REDACTED]');
    sanitized = sanitized.replaceAll(RegExp(r'key=.+$', caseSensitive: false), 'key=[REDACTED]');
    
    // Limit length for logging
    if (sanitized.length > 100) {
      sanitized = '${sanitized.substring(0, 100)}...[TRUNCATED]';
    }
    
    return sanitized;
  }

  /// Validates display name
  static String? validateDisplayName(String? displayName) {
    if (displayName != null && displayName.trim().isNotEmpty) {
      final trimmed = displayName.trim();
      
      if (trimmed.length > 100) {
        return 'Display name too long (max 100 characters)';
      }
      
      // Prevent HTML/script injection
      if (RegExp(r'<[^>]*>', caseSensitive: false).hasMatch(trimmed)) {
        return 'Display name contains invalid characters';
      }
    }
    return null;
  }
}