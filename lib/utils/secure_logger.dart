import 'package:flutter/foundation.dart';

/// lib/utils/secure_logger.dart
/// 
/// Secure logging utility that sanitizes sensitive information
/// Prevents information disclosure in debug output

/// Secure logger that sanitizes sensitive information from debug output
class SecureLogger {
  /// Log a debug message with sanitized content
  static void debug(String message, [String? tag]) {
    if (kDebugMode) {
      final sanitized = _sanitizeMessage(message);
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('$prefix$sanitized');
    }
  }

  /// Log an error with sanitized details
  static void error(String message, dynamic error, [String? tag]) {
    if (kDebugMode) {
      final sanitizedMessage = _sanitizeMessage(message);
      final sanitizedError = _sanitizeError(error);
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('${prefix}ERROR: $sanitizedMessage - $sanitizedError');
    }
  }

  /// Log a warning with sanitized details
  static void warning(String message, [String? tag]) {
    if (kDebugMode) {
      final sanitized = _sanitizeMessage(message);
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('${prefix}WARNING: $sanitized');
    }
  }

  /// Sanitize message content to remove sensitive information
  static String _sanitizeMessage(String message) {
    String sanitized = message;
    
    // Remove file paths (Windows and Unix)
    sanitized = sanitized.replaceAll(RegExp(r'[A-Za-z]:\\[^\\s]*'), '[path]');
    sanitized = sanitized.replaceAll(RegExp(r'\/[^\s]*\/[^\\s]*'), '[path]');
    
    // Remove potential API keys or tokens
    sanitized = sanitized.replaceAll(RegExp(r'[a-zA-Z0-9_-]{20,}'), '[token]');
    
    // Remove email addresses
    sanitized = sanitized.replaceAll(RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'), '[email]');
    
    // Remove IP addresses
    sanitized = sanitized.replaceAll(RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'), '[ip]');
    
    // Remove password patterns
    sanitized = sanitized.replaceAll(RegExp(r'password[=:]\s*[^\s]+', caseSensitive: false), 'password=[hidden]');
    
    return sanitized;
  }

  /// Sanitize error objects to remove sensitive information
  static String _sanitizeError(dynamic error) {
    if (error == null) return 'null';
    
    String errorString = error.toString();
    
    // Remove stack traces and file paths from exceptions
    errorString = _sanitizeMessage(errorString);
    
    // Limit error length to prevent information leakage
    if (errorString.length > 200) {
      errorString = '${errorString.substring(0, 197)}...';
    }
    
    return errorString;
  }

  /// Check if logging should be enabled (debug mode only)
  static bool get isEnabled => kDebugMode;
}