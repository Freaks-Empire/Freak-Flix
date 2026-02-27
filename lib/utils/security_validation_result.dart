// lib/utils/security_validation_result.dart
// Typed result model for security validation outcomes.

enum SecurityValidationSeverity { ok, warning, blocking }

class SecurityValidationResult {
  final SecurityValidationSeverity severity;
  final String reason;
  final String fixExample;
  final String? safeDefault;

  const SecurityValidationResult({
    required this.severity,
    required this.reason,
    required this.fixExample,
    this.safeDefault,
  });

  const SecurityValidationResult.ok({
    this.reason = '',
    this.fixExample = '',
    this.safeDefault,
  }) : severity = SecurityValidationSeverity.ok;

  const SecurityValidationResult.warning({
    required this.reason,
    required this.fixExample,
    this.safeDefault,
  }) : severity = SecurityValidationSeverity.warning;

  const SecurityValidationResult.blocking({
    required this.reason,
    required this.fixExample,
    this.safeDefault,
  }) : severity = SecurityValidationSeverity.blocking;

  bool get isOk => severity == SecurityValidationSeverity.ok;
  bool get isWarning => severity == SecurityValidationSeverity.warning;
  bool get isBlocking => severity == SecurityValidationSeverity.blocking;

  String? get formError => isBlocking ? reason : null;
}
