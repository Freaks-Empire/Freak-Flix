import 'package:auth0_flutter/auth0_flutter.dart' as auth0_native;
import 'package:auth0_flutter/auth0_flutter_web.dart' as auth0_web;
import 'package:flutter/foundation.dart' show kIsWeb;

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
    if (kIsWeb) {
      await _auth0Web?.loginWithRedirect(
        redirectUrl: callbackUrl,
        audience: audience,
        scopes: {'openid', 'profile', 'email'},
        parameters: signup ? {'screen_hint': 'signup'} : const {},
      );
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
    if (kIsWeb) {
      await _auth0Web?.logout();
      return;
    }

    await _auth0?.webAuthentication().logout(
          returnTo: logoutUrl ?? callbackUrl,
        );
  }

  Future<Auth0UserProfile?> getUser() async {
    try {
      if (kIsWeb) {
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
      if (kIsWeb) {
        final creds = await _auth0Web?.credentials(
          audience: audience,
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
}
