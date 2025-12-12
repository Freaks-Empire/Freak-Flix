import 'package:auth0_flutter/auth0_flutter.dart' as auth0_native;
import 'package:auth0_flutter/auth0_flutter_web.dart' as auth0_web;
import 'package:flutter/foundation.dart';

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

  Auth0Service({
    required this.domain,
    required this.clientId,
    this.audience,
    this.callbackUrl,
    this.logoutUrl,
  }) {
    if (kIsWeb) {
      _auth0Web = auth0_web.Auth0Web(domain, clientId);
    } else {
      _auth0 = auth0_native.Auth0(domain, clientId);
    }
  }

  Future<void> login({bool signup = false}) async {
    _ensureConfig();
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
          redirectUrl: callbackUrl,
          parameters: signup ? {'screen_hint': 'signup'} : const {},
        );
  }

  Future<void> logout() async {
    _ensureConfig();
    if (kIsWeb) {
      await _ensureWebInitialized();
      await _auth0Web?.logout();
      return;
    }

    await _auth0?.webAuthentication().logout(
          returnTo: logoutUrl ?? callbackUrl,
        );
  }

  Future<Auth0UserProfile?> getUser() async {
    try {
      _ensureConfig();
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
      return const Auth0UserProfile();
    } catch (_) {
      return null;
    }
  }

  Future<String?> getAccessToken() async {
    try {
      _ensureConfig();
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

  Future<void> _ensureWebInitialized() async {
    if (!kIsWeb || _webInitialized || _auth0Web == null) return;
    try {
      final redirect = _effectiveCallbackUrlForWeb();
      final audienceValue = (audience != null && audience!.isNotEmpty)
          ? audience!
          : null;
      await _auth0Web!.onLoad(
        redirectUrl: redirect.isEmpty ? null : redirect,
        audience: audienceValue,
      );
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
    // Fallback to current origin to avoid null crash; Auth0 should have this allowlisted.
    return Uri.base.toString();
  }
}
