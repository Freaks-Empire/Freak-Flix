import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:auth0_flutter/auth0_flutter.dart' as auth0_native;
import 'package:auth0_flutter/auth0_flutter_web.dart' as auth0_web;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class Auth0UserProfile {
  final String? name;
  final String? email;
  final String? picture;

  const Auth0UserProfile({this.name, this.email, this.picture});
}

class Auth0Service {
  final String domain;
  final String clientId;
  final String? audience;
  final String? callbackUrl;
  final String? logoutUrl;

  auth0_native.Auth0? _auth0;
  auth0_web.Auth0Web? _auth0Web;
  bool _webInitialized = false;

  // Window-specific state
  static const _windowsTokenKey = 'auth0_windows_token';
  static const _windowsIdTokenKey = 'auth0_windows_id_token';
  String? _windowsAccessToken;
  HttpServer? _windowsServer;
  
  bool get _isWindows => !kIsWeb && Platform.isWindows;

  Auth0Service({
    required this.domain,
    required this.clientId,
    this.audience,
    this.callbackUrl,
    this.logoutUrl,
  }) {
    if (kIsWeb) {
      _auth0Web = auth0_web.Auth0Web(domain, clientId);
    } else if (Platform.isWindows) {
      // No native SDK for Windows, logic handled manually below
    } else {
      _auth0 = auth0_native.Auth0(domain, clientId);
    }
  }

  Future<void> cancelLogin() async {
    if (_isWindows && _windowsServer != null) {
      await _windowsServer!.close(force: true);
      _windowsServer = null;
    }
  }

  Future<void> login({bool signup = false}) async {
    _ensureConfig();
    
    if (_isWindows) {
      await _loginWindows(signup);
      return;
    }

    final redirect = _effectiveCallbackUrlForWeb();
    debugPrint(
        'Auth0 login start (web=$kIsWeb) domain=$domain clientId=$clientId redirect=$redirect audience=skipped');
    if (kIsWeb) {
      await _ensureWebInitialized();
      if (_auth0Web == null) {
        debugPrint('Auth0Web instance is null; aborting login');
        return;
      }
      try {
        await _auth0Web?.loginWithRedirect(
          redirectUrl: redirect,
          scopes: {'openid', 'profile', 'email'},
          parameters: signup ? {'screen_hint': 'signup'} : const {},
        );
      } catch (e, st) {
        debugPrint('Auth0Web loginWithRedirect failed: $e');
        debugPrintStack(stackTrace: st);
        rethrow;
      }
      return;
    }

    await _auth0?.webAuthentication().login(
          audience: audience,
          scopes: {'openid', 'profile', 'email'},
          redirectUrl: 'freakflix://$domain/android/com.freak.freakflix/callback',
          parameters: signup ? {'screen_hint': 'signup'} : const {},
        );
  }

  Future<void> logout() async {
    _ensureConfig();
    
    if (_isWindows) {
      await _logoutWindows();
      return;
    }

    if (kIsWeb) {
      await _ensureWebInitialized();
      await _auth0Web?.logout();
      return;
    }

    await _auth0?.webAuthentication().logout(
          returnTo: 'freakflix://$domain/android/com.freak.freakflix/callback',
        );
  }

  Future<Auth0UserProfile?> getUser() async {
    try {
      _ensureConfig();

      if (_isWindows) {
        return await _getUserWindows();
      }

      if (kIsWeb) {
        await _ensureWebInitialized();
        if (_auth0Web == null) {
          debugPrint('Auth0Web instance is null; getUser aborted');
          return null;
        }
        final creds = await _auth0Web?.credentials();
        final user = creds?.user;
        if (creds == null || user == null) return null;
        return Auth0UserProfile(
          name: user.name,
          email: user.email,
          picture: user.pictureUrl?.toString(),
        );
      }

      final creds = await _auth0?.credentialsManager.credentials();
      if (creds == null ||
          (creds.accessToken == null && creds.idToken == null)) {
        return null;
      }
      return const Auth0UserProfile(); // Native SDK handles profile differently, often just JWT claims?
      // Actually native SDK 'credentials' object usually has a 'user' property too, 
      // but let's stick to the interface. The previous code returned empty profile for native?
      // Let's improve it if we can, but sticking to previous behavior for native to minimize risk.
    } catch (_) {
      return null;
    }
  }

  Future<String?> getAccessToken() async {
    try {
      _ensureConfig();
      
      if (_isWindows) {
        if (_windowsAccessToken != null) return _windowsAccessToken;
        final prefs = await SharedPreferences.getInstance();
        _windowsAccessToken = prefs.getString(_windowsTokenKey);
        return _windowsAccessToken;
      }

      if (kIsWeb) {
        await _ensureWebInitialized();
        if (_auth0Web == null) {
          debugPrint('Auth0Web instance is null; access token aborted');
          return null;
        }
        final creds = await _auth0Web?.credentials(
          scopes: {'openid', 'profile', 'email'},
        );
        return creds?.accessToken;
      }
      final creds = await _auth0?.credentialsManager.credentials();
      return creds?.accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getIdToken() async {
    try {
      _ensureConfig();

      if (_isWindows) {
        // We don't cache ID token in memory variable currently, so read from prefs
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_windowsIdTokenKey);
      }

      if (kIsWeb) {
        await _ensureWebInitialized();
        if (_auth0Web == null) return null;
        final creds = await _auth0Web?.credentials();
        return creds?.idToken;
      }

      final creds = await _auth0?.credentialsManager.credentials();
      return creds?.idToken;
    } catch (e) {
      debugPrint('Error getting ID token: $e');
      return null;
    }
  }

  // --- Windows Implementation ---

  Future<void> _loginWindows(bool signup) async {
    // 0. Ensure no previous server running
    await cancelLogin();

    // 1. Identify port from callback URL if possible, or use 5789 default
    int port = 5789;
    if (callbackUrl != null) {
      final uri = Uri.tryParse(callbackUrl!);
      if (uri != null && uri.hasPort) {
        port = uri.port;
      }
    }

    try {
      // Try specific port first
      _windowsServer = await HttpServer.bind('127.0.0.1', port);
    } catch (e) {
       throw Exception('Could not bind to port $port. Is the app already running? Error: $e');
    }

    final redirectUri = 'http://127.0.0.1:$port/callback';

    // 2. Generate PKCE
    final verifier = _createCodeVerifier();
    final challenge = _createCodeChallenge(verifier);

    // 3. Construct URL
    final url = Uri.https(domain, '/authorize', {
      'response_type': 'code',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': 'openid profile email',
      if (audience != null) 'audience': audience!,
      if (signup) 'screen_hint': 'signup',
    });

    // 4. Launch browser
    await launchUrl(url, mode: LaunchMode.externalApplication);

    // 5. Listen for callback
    String? code;
    try {
      if (_windowsServer == null) throw Exception('Login cancelled');

      await for (final request in _windowsServer!.take(1)) {
        if (request.uri.path == '/callback') {
          code = request.uri.queryParameters['code'];
          request.response
            ..statusCode = 200
            ..headers.set('content-type', 'text/html; charset=UTF-8')
            ..write('<html><body><h1>You can close this window now.</h1><script>window.close();</script></body></html>');
          await request.response.close();
        } else {
          request.response.statusCode = 404;
          await request.response.close();
        }
      }
    } catch (e) {
      if (_windowsServer == null) {
         throw Exception('Login cancelled by user.');
      }
      rethrow;
    } finally {
      await cancelLogin(); // cleanup
    }

    if (code == null) {
      throw Exception('Login flow interrupted or cancelled.');
    }

    // 6. Exchange code for token
    final tokenResponse = await http.post(
      Uri.https(domain, '/oauth/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'client_id': clientId,
        'code_verifier': verifier,
        'code': code,
        'redirect_uri': redirectUri,
      },
    );

    if (tokenResponse.statusCode != 200) {
      throw Exception('Failed to exchange token: ${tokenResponse.body}');
    }

    final data = jsonDecode(tokenResponse.body);
    final accessToken = data['access_token'] as String?;
    final idToken = data['id_token'] as String?;

    if (accessToken != null) {
      _windowsAccessToken = accessToken;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_windowsTokenKey, accessToken);
      if (idToken != null) {
        await prefs.setString(_windowsIdTokenKey, idToken);
      }
    }
  }

  Future<Auth0UserProfile?> _getUserWindows() async {
    final token = await getAccessToken();
    if (token == null) return null;

    // Use /userinfo endpoint
    final response = await http.get(
      Uri.https(domain, '/userinfo'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Auth0UserProfile(
        name: data['name'],
        email: data['email'],
        picture: data['picture'],
      );
    }
    
    // Fallback: try to decode ID token if we stored it (not secure but works for display sometimes)
    // But failing /userinfo usually means token is invalid.
    return null;
  }

  Future<void> _logoutWindows() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_windowsTokenKey);
    await prefs.remove(_windowsIdTokenKey);
    _windowsAccessToken = null;

    // Optional: Call Auth0 logout endpoint to clear server session
    // This often requires redirecting the user again, which might be annoying.
    // For a desktop app, clearing local tokens is usually sufficient for "logging out" of the app.
    // If we want to force full logout:
    final returnTo = logoutUrl ?? callbackUrl;
    if (returnTo != null) {
      final url = Uri.https(domain, '/v2/logout', {
        'client_id': clientId,
        'returnTo': returnTo,
      });
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // --- PKCE Helpers ---

  String _createCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return _base64UrlEncode(values);
  }

  String _createCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return _base64UrlEncode(digest.bytes);
  }

  String _base64UrlEncode(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  // --- Web Helpers ---

  Future<void> _ensureWebInitialized() async {
    if (!kIsWeb || _webInitialized || _auth0Web == null) return;
    try {
      await _auth0Web!.onLoad();
      _webInitialized = true;
    } catch (e, st) {
      debugPrint('Auth0Web onLoad failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  void _ensureConfig() {
    if (domain.isEmpty || clientId.isEmpty) {
      throw StateError(
        'Auth0 is not configured. Please set AUTH0_DOMAIN and AUTH0_CLIENT_ID.',
      );
    }
  }

  String _effectiveCallbackUrlForWeb() {
    if (!kIsWeb) {
      return callbackUrl ?? '';
    }
    if (callbackUrl != null && callbackUrl!.isNotEmpty) {
      return callbackUrl!;
    }
    return Uri.base.toString();
  }
}
