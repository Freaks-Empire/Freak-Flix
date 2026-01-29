/// lib/services/graph_auth_stub.dart
/// Stub for non-web platforms - web OAuth is not available.

class WebOAuthResult {
  final bool success;
  final String? accessToken;
  final String? refreshToken;
  final int? expiresIn;
  final String? error;
  final String? errorDescription;

  WebOAuthResult({
    required this.success,
    this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.error,
    this.errorDescription,
  });
}

class WebOAuthService {
  static Future<WebOAuthResult> loginWithPopup({
    required String clientId,
    String tenant = 'common',
  }) async {
    // Not available on non-web platforms
    return WebOAuthResult(
      success: false,
      error: 'not_supported',
      errorDescription: 'Web OAuth is only available on web platform.',
    );
  }
}
