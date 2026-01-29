/// lib/services/graph_auth_web.dart
/// Web-specific OAuth popup implementation for Microsoft Graph authentication.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Result of web OAuth popup flow.
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

/// Performs OAuth login via popup window for web platform.
class WebOAuthService {
  static const _scopes = [
    'User.Read',
    'Files.Read',
    'Files.ReadWrite',
    'offline_access',
  ];

  /// Generates a cryptographically secure random string for PKCE.
  static String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(64, (_) => random.nextInt(256));
    return base64Url.encode(values).replaceAll('=', '').substring(0, 64);
  }

  /// Generates code challenge from verifier using "plain" method.
  /// Note: For maximum security, S256 should be used, but that requires
  /// SubtleCrypto which has compatibility issues. Microsoft also accepts plain.
  static String _generateCodeChallenge(String verifier) {
    // Use plain method - the challenge equals the verifier
    // This is less secure than S256 but works across all browsers
    return verifier;
  }

  /// Opens Microsoft login popup and returns tokens.
  static Future<WebOAuthResult> loginWithPopup({
    required String clientId,
    String tenant = 'common',
  }) async {
    final completer = Completer<WebOAuthResult>();
    
    // Generate PKCE values
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);
    final state = _generateCodeVerifier().substring(0, 16);
    
    // Determine redirect URI based on current origin
    final origin = html.window.location.origin;
    final redirectUri = '$origin/auth-callback.html';
    
    // Build authorization URL - using plain method for code challenge
    final authUrl = Uri.https('login.microsoftonline.com', '/$tenant/oauth2/v2.0/authorize', {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'scope': _scopes.join(' '),
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'plain',
      'prompt': 'select_account',
    });
    
    // Open popup
    final html.WindowBase? popup = html.window.open(
      authUrl.toString(),
      'Microsoft Login',
      'width=500,height=700,left=100,top=100',
    );
    
    // ignore: unnecessary_null_comparison
    if (popup == null) {
      return WebOAuthResult(
        success: false,
        error: 'popup_blocked',
        errorDescription: 'Please allow popups for this site and try again.',
      );
    }
    
    // Listen for messages from popup
    late html.EventListener messageListener;
    Timer? pollTimer;
    
    void cleanup() {
      html.window.removeEventListener('message', messageListener);
      pollTimer?.cancel();
    }
    
    messageListener = (html.Event event) async {
      final messageEvent = event as html.MessageEvent;
      
      // Verify origin
      if (messageEvent.origin != origin) return;
      
      final data = messageEvent.data;
      if (data is! Map) return;
      
      final type = data['type'];
      
      if (type == 'oauth-success') {
        cleanup();
        
        final code = data['code'] as String?;
        final returnedState = data['state'] as String?;
        
        // Verify state
        if (returnedState != state) {
          completer.complete(WebOAuthResult(
            success: false,
            error: 'state_mismatch',
            errorDescription: 'Security validation failed. Please try again.',
          ));
          return;
        }
        
        if (code == null) {
          completer.complete(WebOAuthResult(
            success: false,
            error: 'no_code',
            errorDescription: 'No authorization code received.',
          ));
          return;
        }
        
        // Exchange code for tokens via Netlify function
        try {
          final tokenResult = await _exchangeCodeForTokens(
            code: code,
            codeVerifier: codeVerifier,
            redirectUri: redirectUri,
            clientId: clientId,
            tenant: tenant,
          );
          completer.complete(tokenResult);
        } catch (e) {
          completer.complete(WebOAuthResult(
            success: false,
            error: 'token_exchange_failed',
            errorDescription: e.toString(),
          ));
        }
      } else if (type == 'oauth-error') {
        cleanup();
        completer.complete(WebOAuthResult(
          success: false,
          error: data['error'] as String? ?? 'unknown_error',
          errorDescription: data['errorDescription'] as String?,
        ));
      }
    };
    
    html.window.addEventListener('message', messageListener);
    
    // Poll to check if popup was closed without completing
    pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (popup.closed == true && !completer.isCompleted) {
        cleanup();
        completer.complete(WebOAuthResult(
          success: false,
          error: 'popup_closed',
          errorDescription: 'Login window was closed before completing authentication.',
        ));
      }
    });
    
    // Timeout after 5 minutes
    Future.delayed(const Duration(minutes: 5), () {
      if (!completer.isCompleted) {
        cleanup();
        popup.close();
        completer.complete(WebOAuthResult(
          success: false,
          error: 'timeout',
          errorDescription: 'Login timed out. Please try again.',
        ));
      }
    });
    
    return completer.future;
  }
  
  /// Exchange authorization code for tokens via Netlify function.
  static Future<WebOAuthResult> _exchangeCodeForTokens({
    required String code,
    required String codeVerifier,
    required String redirectUri,
    required String clientId,
    required String tenant,
  }) async {
    final origin = html.window.location.origin;
    final functionUrl = '$origin/.netlify/functions/oauth-token';
    
    final response = await http.post(
      Uri.parse(functionUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'code': code,
        'code_verifier': codeVerifier,
        'redirect_uri': redirectUri,
        'client_id': clientId,
        'tenant': tenant,
      }),
    );
    
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    
    if (response.statusCode != 200) {
      return WebOAuthResult(
        success: false,
        error: data['error'] as String? ?? 'token_exchange_failed',
        errorDescription: data['error_description'] as String?,
      );
    }
    
    return WebOAuthResult(
      success: true,
      accessToken: data['access_token'] as String?,
      refreshToken: data['refresh_token'] as String?,
      expiresIn: (data['expires_in'] as num?)?.toInt(),
    );
  }
}
