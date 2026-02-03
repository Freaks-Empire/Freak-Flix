/// lib/utils/retry_handler.dart
/// 
/// Retry mechanisms for video player operations
/// Provides exponential backoff and configurable retry strategies

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import '../utils/secure_logger.dart';

enum RetryStrategy {
  exponential,
  linear,
  fixed,
}

class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final RetryStrategy strategy;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.strategy = RetryStrategy.exponential,
  });
}

class RetryResult<T> {
  final bool success;
  final T? result;
  final String? error;
  final int attemptsUsed;

  const RetryResult({
    required this.success,
    this.result,
    this.error,
    required this.attemptsUsed,
  });
}

class RetryHandler {
  /// Execute a function with retry logic
  static Future<RetryResult<T>> executeWithRetry<T>(
    Future<T> Function() operation,
    RetryConfig config, {
    bool Function(dynamic error)? shouldRetry,
    String? operationName,
  }) async {
    dynamic lastError;
    Exception? lastException;
    
    for (int attempt = 1; attempt <= config.maxAttempts; attempt++) {
      try {
        final result = await operation();
        
        if (attempt > 1) {
          SecureLogger.debug(
            'Operation "${operationName ?? 'Unknown'}" succeeded on attempt $attempt',
            'RetryHandler'
          );
        }
        
        return RetryResult<T>(
          success: true,
          result: result,
          attemptsUsed: attempt,
        );
      } catch (error) {
        lastError = error;
        lastException = error is Exception ? error : Exception(error.toString());
        
        // Check if we should retry this error
        final shouldRetryError = shouldRetry?.call(error) ?? _shouldRetryByDefault(error);
        
        if (!shouldRetryError || attempt == config.maxAttempts) {
          SecureLogger.error(
            'Operation "${operationName ?? 'Unknown'}" failed permanently after $attempt attempts',
            lastException,
            'RetryHandler'
          );
          
          return RetryResult<T>(
            success: false,
            error: error.toString(),
            attemptsUsed: attempt,
          );
        }
        
        // Calculate delay for next attempt
        final delay = _calculateDelay(attempt - 1, config);
        SecureLogger.debug(
          'Operation "${operationName ?? 'Unknown'}" failed on attempt $attempt, retrying in ${delay.inMilliseconds}ms',
          'RetryHandler'
        );
        
        await Future.delayed(delay);
      }
    }
    
    return RetryResult<T>(
      success: false,
      error: lastError.toString(),
      attemptsUsed: config.maxAttempts,
    );
  }

  /// Default retry logic based on error types
  static bool _shouldRetryByDefault(dynamic error) {
    // Retry on network errors
    if (error is SocketException) return true;
    if (error is HttpException) return true;
    if (error is TimeoutException) return true;
    
    // Retry on temporary errors
    final errorString = error.toString().toLowerCase();
    final retryablePatterns = [
      'connection refused',
      'connection timed out',
      'network is unreachable',
      'temporary failure',
      'service unavailable',
      'too many requests',
      'rate limited',
    ];
    
    return retryablePatterns.any((pattern) => errorString.contains(pattern));
  }

  /// Calculate delay based on retry strategy
  static Duration _calculateDelay(int attemptNumber, RetryConfig config) {
    int delayMs;
    
    switch (config.strategy) {
      case RetryStrategy.exponential:
        delayMs = (config.initialDelay.inMilliseconds * 
                   math.pow(config.backoffMultiplier, attemptNumber)).round();
        break;
      case RetryStrategy.linear:
        delayMs = config.initialDelay.inMilliseconds * (attemptNumber + 1);
        break;
      case RetryStrategy.fixed:
        delayMs = config.initialDelay.inMilliseconds;
        break;
    }
    
    // Clamp to max delay
    delayMs = delayMs.clamp(
      config.initialDelay.inMilliseconds,
      config.maxDelay.inMilliseconds,
    );
    
    // Add jitter to prevent thundering herd
    final jitter = (delayMs * 0.1 * (1 - attemptNumber % 2)).round();
    return Duration(milliseconds: delayMs + jitter);
  }

  /// Network-aware retry configuration
  static RetryConfig forNetworkOperations({
    int maxAttempts = 3,
    Duration? timeout,
  }) {
    return RetryConfig(
      maxAttempts: maxAttempts,
      initialDelay: const Duration(milliseconds: 500),
      maxDelay: timeout ?? const Duration(seconds: 10),
      backoffMultiplier: 1.5,
      strategy: RetryStrategy.exponential,
    );
  }

  /// Quick retry configuration for temporary issues
  static RetryConfig forQuickOperations({
    int maxAttempts = 2,
  }) {
    return RetryConfig(
      maxAttempts: maxAttempts,
      initialDelay: const Duration(milliseconds: 200),
      maxDelay: const Duration(seconds: 2),
      backoffMultiplier: 2.0,
      strategy: RetryStrategy.exponential,
    );
  }

  /// Slow retry configuration for heavy operations
  static RetryConfig forHeavyOperations({
    int maxAttempts = 5,
  }) {
    return RetryConfig(
      maxAttempts: maxAttempts,
      initialDelay: const Duration(seconds: 2),
      maxDelay: const Duration(minutes: 2),
      backoffMultiplier: 1.8,
      strategy: RetryStrategy.exponential,
    );
  }
}