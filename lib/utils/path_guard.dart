// lib/utils/path_guard.dart
//
// Canonical path containment helpers for local filesystem operations.
import 'package:path/path.dart' as p;

class PathGuardException implements Exception {
  final String message;

  const PathGuardException(this.message);

  @override
  String toString() => message;
}

class PathGuardDecision {
  final bool isAllowed;
  final String? resolvedPath;
  final String? reason;

  const PathGuardDecision._({
    required this.isAllowed,
    this.resolvedPath,
    this.reason,
  });

  factory PathGuardDecision.allow(String resolvedPath) {
    return PathGuardDecision._(isAllowed: true, resolvedPath: resolvedPath);
  }

  factory PathGuardDecision.deny(String reason) {
    return PathGuardDecision._(isAllowed: false, reason: reason);
  }
}

class PathGuard {
  static PathGuardDecision evaluateContainedPath({
    required String candidatePath,
    required String allowedRoot,
    p.Style? style,
    bool allowAbsoluteCandidate = true,
    bool allowRootPath = true,
  }) {
    if (candidatePath.trim().isEmpty) {
      return PathGuardDecision.deny('Path is required');
    }
    if (allowedRoot.trim().isEmpty) {
      return PathGuardDecision.deny('Allowed root is required');
    }

    final resolvedStyle = style ?? p.Style.platform;
    final context = p.Context(style: resolvedStyle);
    final decodedRoot = _decodeAndNormalizeInput(allowedRoot, context);
    final decodedCandidate = _decodeAndNormalizeInput(candidatePath, context);

    if (decodedRoot == null || decodedCandidate == null) {
      return PathGuardDecision.deny('Path contains invalid encoded characters');
    }
    if (_hasUnsafeControlChars(decodedCandidate)) {
      return PathGuardDecision.deny('Path contains unsafe control characters');
    }

    final canonicalRoot = context.normalize(context.absolute(decodedRoot));

    if (!allowAbsoluteCandidate && context.isAbsolute(decodedCandidate)) {
      return PathGuardDecision.deny('Absolute paths are not allowed here');
    }

    final candidateAbsolute = context.normalize(
      context.isAbsolute(decodedCandidate)
          ? context.absolute(decodedCandidate)
          : context.absolute(context.join(canonicalRoot, decodedCandidate)),
    );

    final candidateComparable = _toComparable(candidateAbsolute, resolvedStyle);
    final rootComparable = _toComparable(canonicalRoot, resolvedStyle);
    final isSamePath = candidateComparable == rootComparable;
    final isWithinRoot = context.isWithin(canonicalRoot, candidateAbsolute);

    if (!allowRootPath && isSamePath) {
      return PathGuardDecision.deny('Path must point to a file inside the selected directory');
    }
    if (!isSamePath && !isWithinRoot) {
      return PathGuardDecision.deny('Path escapes the allowed directory root');
    }

    return PathGuardDecision.allow(candidateAbsolute);
  }

  static String requireContainedPath({
    required String candidatePath,
    required String allowedRoot,
    p.Style? style,
    bool allowAbsoluteCandidate = true,
    bool allowRootPath = true,
    String operation = 'filesystem operation',
  }) {
    final decision = evaluateContainedPath(
      candidatePath: candidatePath,
      allowedRoot: allowedRoot,
      style: style,
      allowAbsoluteCandidate: allowAbsoluteCandidate,
      allowRootPath: allowRootPath,
    );

    if (!decision.isAllowed || decision.resolvedPath == null) {
      throw PathGuardException(
        'Blocked $operation: ${decision.reason ?? 'Path is outside allowed root'}',
      );
    }

    return decision.resolvedPath!;
  }

  static String? _decodeAndNormalizeInput(String value, p.Context context) {
    var decoded = value.trim().replaceAll('\\u2215', '/').replaceAll('\\u2216', '\\');

    for (var i = 0; i < 3; i++) {
      final normalizedUnicode = _replacePercentUnicode(decoded);
      final normalizedOverlong = _replaceKnownOverlongUtf8(normalizedUnicode);

      String uriDecoded;
      try {
        uriDecoded = Uri.decodeFull(normalizedOverlong);
      } on FormatException {
        return null;
      }

      if (uriDecoded == decoded) {
        decoded = uriDecoded;
        break;
      }

      decoded = uriDecoded;
    }

    return context.normalize(decoded);
  }

  static String _replacePercentUnicode(String input) {
    return input.replaceAllMapped(RegExp(r'%u([0-9a-fA-F]{4})'), (match) {
      final codeUnit = int.tryParse(match.group(1)!, radix: 16);
      if (codeUnit == null) {
        return match.group(0)!;
      }
      return String.fromCharCode(codeUnit);
    });
  }

  static String _replaceKnownOverlongUtf8(String input) {
    return input
        .replaceAll(RegExp('%c0%af', caseSensitive: false), '/')
        .replaceAll(RegExp('%e0%80%af', caseSensitive: false), '/')
        .replaceAll(RegExp('%c1%9c', caseSensitive: false), r'\');
  }

  static bool _hasUnsafeControlChars(String value) {
    for (final rune in value.runes) {
      if (rune == 0 || rune < 32 || rune == 127) {
        return true;
      }
    }
    return false;
  }

  static String _toComparable(String value, p.Style style) {
    if (style == p.Style.windows) {
      return value.toLowerCase();
    }
    return value;
  }
}
