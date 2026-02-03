/// lib/utils/url_validator.dart
/// 
/// Secure URL validation utilities to prevent SSRF attacks
/// and ensure only safe video URLs are processed

import '../utils/input_validation.dart';

class UrlValidator {
  /// Allowed protocols for video streaming
  static const List<String> _allowedProtocols = [
    'http',
    'https',
    'file',
    'ftp',
    'sftp',
    'blob',
  ];

  /// Allowed file extensions for video content
  static const List<String> _allowedExtensions = [
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 
    'm4v', '3gp', 'ogv', 'ts', 'mts', 'm2ts'
  ];

  /// Whitelisted domains for external streaming (if any)
  static const List<String> _whitelistedDomains = [
    // Add any approved streaming domains here
  ];

  /// Validate a URL for security and allowlist compliance
  static ValidationResult validateUrl(String url) {
    if (url.isEmpty) {
      return const ValidationResult(false, 'URL cannot be empty');
    }

    try {
      final uri = Uri.parse(url);
      
      // Check protocol
      if (!_allowedProtocols.contains(uri.scheme.toLowerCase())) {
        return ValidationResult(false, 'Protocol ${uri.scheme} is not allowed');
      }

      // For network protocols, perform additional checks
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        // SSRF protection - block private/internal networks
        if (uri.host.isNotEmpty) {
          final hostValidation = InputValidation.validateHostname(uri.host);
          if (hostValidation != null) {
            return ValidationResult(false, 'Host validation failed: $hostValidation');
          }
        }

        // Domain whitelist check (if configured)
        if (_whitelistedDomains.isNotEmpty && uri.host.isNotEmpty) {
          if (!_whitelistedDomains.contains(uri.host.toLowerCase())) {
            return ValidationResult(false, 'Domain ${uri.host} is not whitelisted');
          }
        }
      }

      // File path security checks
      if (uri.scheme == 'file' || uri.scheme == 'ftp' || uri.scheme == 'sftp') {
        final pathValidation = validateFilePath(uri.path);
        if (pathValidation != null) {
          return ValidationResult(false, pathValidation);
        }
      }

      return const ValidationResult(true, 'URL is valid');
    } catch (e) {
      return ValidationResult(false, 'Invalid URL format: $e');
    }
  }

  /// Validate file path for directory traversal and other attacks
  static String? validateFilePath(String path) {
    if (path.isEmpty) return null;

    // Directory traversal protection
    if (path.contains('../') || path.contains('..\\') || 
        path.startsWith('../') || path.startsWith('..\\')) {
      return 'Directory traversal detected';
    }

    // Null byte injection protection
    if (path.contains('\x00')) {
      return 'Null byte injection detected';
    }

    // Excessive path length (possible buffer overflow)
    if (path.length > 4096) {
      return 'Path too long';
    }

    // Check for suspicious patterns
    final suspiciousPatterns = [
      RegExp(r'<script[^>]*>', caseSensitive: false),
      RegExp(r'javascript:', caseSensitive: false),
      RegExp(r'data:', caseSensitive: false),
      RegExp(r'vbscript:', caseSensitive: false),
    ];

    for (final pattern in suspiciousPatterns) {
      if (pattern.hasMatch(path)) {
        return 'Suspicious content detected in path';
      }
    }

    return null;
  }

  /// Validate file extension against allowed video formats
  static bool isAllowedExtension(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    return _allowedExtensions.contains(extension);
  }

  /// Sanitize a file path by removing dangerous elements
  static String sanitizePath(String path) {
    // Remove directory traversal attempts
    String sanitized = path.replaceAll(RegExp(r'\.\./g'), '').replaceAll(RegExp(r'\.\.\\/g'), '');
    
    // Remove null bytes
    sanitized = sanitized.replaceAll('\x00', '');
    
    // Normalize path separators
    sanitized = sanitized.replaceAll('\\', '/');
    
    // Remove multiple consecutive slashes
    sanitized = sanitized.replaceAll(RegExp(r'/+'), '/');
    
    // Remove leading/trailing slashes
    sanitized = sanitized.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    
    return sanitized;
  }

  /// Check if a URL is for local content (file://, blob:)
  static bool isLocalUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.scheme == 'file' || uri.scheme == 'blob';
    } catch (e) {
      return false;
    }
  }

  /// Check if a URL is for remote content (http://, https://, ftp://, sftp://)
  static bool isRemoteUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return ['http', 'https', 'ftp', 'sftp'].contains(uri.scheme.toLowerCase());
    } catch (e) {
      return false;
    }
  }
}

/// Result of URL validation
class ValidationResult {
  final bool isValid;
  final String message;
  
  const ValidationResult(this.isValid, this.message);
}