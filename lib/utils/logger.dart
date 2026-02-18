/// lib/utils/logger.dart
/// Production-safe logging utility with file support

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'input_validation.dart';

class AppLogger {
  static File? _logFile;
  static IOSink? _logSink;
  static final _logBuffer = StringBuffer();
  static const int _maxLogSize = 10 * 1024 * 1024; // 10MB max

  /// Initialize file logging
  static Future<void> initializeFileLogging() async {
    if (kIsWeb) return;
    
    try {
      final appDir = await getApplicationSupportDirectory();
      _logFile = File(p.join(appDir.path, 'freakflix.log'));
      
      // Rotate if too large
      if (await _logFile!.exists() && await _logFile!.length() > _maxLogSize) {
        await _rotateLog();
      }
      
      _logSink = _logFile!.openWrite(mode: FileMode.append);
      _logSink!.writeln('=== Freak-Flix Started at ${DateTime.now()} ===');
      _logSink!.writeln('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
      _logSink!.writeln('');
      await _logSink!.flush();
      
      // Write any buffered logs
      if (_logBuffer.isNotEmpty) {
        _logSink!.write(_logBuffer.toString());
        await _logSink!.flush();
        _logBuffer.clear();
      }
    } catch (e) {
      debugPrint('Failed to initialize file logging: $e');
    }
  }

  /// Rotate old log file
  static Future<void> _rotateLog() async {
    if (_logFile == null) return;
    final backupPath = '${_logFile!.path}.old';
    try {
      if (await File(backupPath).exists()) {
        await File(backupPath).delete();
      }
      await _logFile!.rename(backupPath);
    } catch (e) {
      debugPrint('Failed to rotate log: $e');
    }
  }

  /// Write to log file
  static void _writeToFile(String level, String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (kIsWeb) return;
    
    final timestamp = DateTime.now().toIso8601String();
    final tagStr = tag != null ? '[$tag] ' : '';
    final logLine = '[$timestamp] $level $tagStr$message';
    
    if (_logSink != null) {
      _logSink!.writeln(logLine);
      if (error != null) {
        _logSink!.writeln('  ERROR: $error');
      }
      if (stackTrace != null) {
        _logSink!.writeln('  STACK: $stackTrace');
      }
      _logSink!.flush();
    } else {
      // Buffer until file is ready
      _logBuffer.writeln(logLine);
    }
  }

  /// Get log file path
  static String? get logFilePath => _logFile?.path;

  /// Log debug messages (disabled in release, but written to file)
  static void d(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    final sanitizedMessage = InputValidation.sanitizeForLogging(message);
    final tagStr = tag != null ? '[$tag] ' : '';
    
    // Always write to file
    _writeToFile('DEBUG', sanitizedMessage, tag: tag, error: error, stackTrace: stackTrace);
    
    if (kDebugMode) {
      debugPrint('$tagStr$sanitizedMessage');
      if (error != null && kDebugMode) {
        debugPrint('$tagStr Error: $error');
      }
    }
  }

  /// Log info messages
  static void i(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    final sanitizedMessage = InputValidation.sanitizeForLogging(message);
    final tagStr = tag != null ? '[$tag] ' : '';
    
    _writeToFile('INFO', sanitizedMessage, tag: tag, error: error, stackTrace: stackTrace);
    
    if (kDebugMode) {
      debugPrint('$tagStr$sanitizedMessage');
    }
  }

  /// Log warning messages
  static void w(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    final sanitizedMessage = InputValidation.sanitizeForLogging(message);
    final tagStr = tag != null ? '[$tag] ' : '';
    
    _writeToFile('WARN', sanitizedMessage, tag: tag, error: error, stackTrace: stackTrace);
    
    if (kDebugMode) {
      debugPrint('$tagStr⚠️ $sanitizedMessage');
    } else {
      // In production, warnings should be sent to logging service
      print('WARNING: $tagStr$sanitizedMessage');
    }
  }

  /// Log error messages
  static void e(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    final sanitizedMessage = InputValidation.sanitizeForLogging(message);
    final tagStr = tag != null ? '[$tag] ' : '';
    
    _writeToFile('ERROR', sanitizedMessage, tag: tag, error: error, stackTrace: stackTrace);
    
    if (kDebugMode) {
      debugPrint('$tagStr❌ ERROR: $sanitizedMessage');
      if (error != null) {
        debugPrint('$tagStr❌ Error details: $error');
      }
      if (stackTrace != null && kDebugMode) {
        debugPrint('$tagStr❌ Stack trace: $stackTrace');
      }
    } else {
      // In production, errors should always be reported
      print('ERROR: $tagStr$sanitizedMessage');
    }
  }

  /// Log security events (always logged, even in production)
  static void security(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    final sanitizedMessage = InputValidation.sanitizeForLogging(message);
    final tagStr = tag != null ? '[$tag] ' : '';
    
    _writeToFile('SECURITY', sanitizedMessage, tag: tag, error: error, stackTrace: stackTrace);
    
    if (kDebugMode) {
      debugPrint('$tagStr🔒 SECURITY: $sanitizedMessage');
    } else {
      // Security events should always be logged, even in production
      print('SECURITY: $tagStr$sanitizedMessage');
    }
  }

  /// Log performance metrics
  static void performance(String message, {String? tag}) {
    final sanitizedMessage = InputValidation.sanitizeForLogging(message);
    final tagStr = tag != null ? '[$tag] ' : '';
    
    _writeToFile('PERF', sanitizedMessage, tag: tag);
    
    if (kDebugMode) {
      debugPrint('$tagStr⏱️ $sanitizedMessage');
    }
  }

  /// Log network requests (sanitized)
  static void network(String method, String url, {int? statusCode, String? tag}) {
    final sanitizedUrl = _sanitizeUrl(url);
    final tagStr = tag != null ? '[$tag] ' : '';
    
    _writeToFile('NETWORK', '$method $sanitizedUrl${statusCode != null ? ' -> $statusCode' : ''}', tag: tag);
    
    if (kDebugMode) {
      debugPrint('$tagStr🌐 $method $sanitizedUrl${statusCode != null ? ' -> $statusCode' : ''}');
    } else {
      // Log network requests in production without sensitive data
      print('NETWORK: $tagStr$method ${_maskUrl(url)}${statusCode != null ? ' -> $statusCode' : ''}');
    }
  }

  /// Log user actions (privacy-conscious)
  static void userAction(String action, {String? tag, Map<String, String>? params}) {
    final sanitizedParams = params?.map((key, value) => 
        MapEntry(key, InputValidation.sanitizeForLogging(value)));
    final tagStr = tag != null ? '[$tag] ' : '';
    final message = '$action${sanitizedParams != null ? ' with params: $sanitizedParams' : ''}';
    
    _writeToFile('USER', message, tag: tag);
    
    if (kDebugMode) {
      debugPrint('$tagStr👤 $message');
    } else {
      // In production, log actions without parameters for privacy
      print('USER_ACTION: $tagStr$action');
    }
  }

  /// Log configuration changes
  static void config(String setting, String value, {String? tag, bool isSensitive = false}) {
    final sanitizedValue = isSensitive ? '[REDACTED]' : InputValidation.sanitizeForLogging(value);
    final tagStr = tag != null ? '[$tag] ' : '';
    
    _writeToFile('CONFIG', '$setting = $sanitizedValue', tag: tag);
    
    if (kDebugMode) {
      debugPrint('$tagStr⚙️ $setting = $sanitizedValue');
    } else {
      print('CONFIG: $tagStr$setting = $sanitizedValue');
    }
  }

  /// Sanitize URLs for logging (remove sensitive parameters)
  static String _sanitizeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      // Remove sensitive query parameters
      final sanitizedParams = <String, String>{};
      uri.queryParameters.forEach((key, value) {
        if (!_isSensitiveParam(key)) {
          sanitizedParams[key] = value;
        }
      });
      
      final sanitizedUri = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.port,
        path: uri.path,
        queryParameters: sanitizedParams.isEmpty ? null : sanitizedParams,
        fragment: uri.fragment,
      );
      return sanitizedUri.toString();
    } catch (e) {
      return '[invalid_url]';
    }
  }

  /// Check if query parameter is sensitive
  static bool _isSensitiveParam(String param) {
    final sensitiveParams = {
      'api_key',
      'apikey',
      'token',
      'password',
      'pass',
      'secret',
      'key',
      'authorization',
      'auth',
      'session',
      'cookie',
      'credentials',
    };
    return sensitiveParams.contains(param.toLowerCase());
  }

  /// Mask URL for production logging
  static String _maskUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return '${uri.scheme}://${uri.host}${uri.path}';
    } catch (e) {
      return '[masked_url]';
    }
  }

  /// Create a structured log entry
  static Map<String, dynamic> createLogEntry(
    String level,
    String message, {
    String? tag,
    String? timestamp,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    return {
      'timestamp': timestamp ?? DateTime.now().toIso8601String(),
      'level': level,
      'tag': tag,
      'message': InputValidation.sanitizeForLogging(message),
      'error': error?.toString(),
      'stackTrace': stackTrace?.toString(),
      'extra': extra,
    };
  }

  /// Log critical errors that should always be reported
  static void critical(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    final sanitizedMessage = InputValidation.sanitizeForLogging(message);
    final tagStr = tag != null ? '[$tag] ' : '';
    
    _writeToFile('CRITICAL', sanitizedMessage, tag: tag, error: error, stackTrace: stackTrace);
    
    if (kDebugMode) {
      debugPrint('$tagStr🚨 CRITICAL: $sanitizedMessage');
    } else {
      // Critical errors should always be reported
      print('CRITICAL: $tagStr$sanitizedMessage');
    }
  }

  /// Legacy debugPrint alias for gradual migration
  static void debugPrintLegacy(String message, {String? tag}) {
    d(message, tag: tag);
  }

  /// Close file logging
  static Future<void> dispose() async {
    _writeToFile('INFO', '=== Application closing ===');
    await _logSink?.close();
    _logSink = null;
  }
}
