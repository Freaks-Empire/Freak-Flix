import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:auth0_flutter_platform_interface/auth0_flutter_platform_interface.dart'
    show AuthorizationParams, LogoutOptions;
import 'package:auth0_flutter_web/auth0_flutter_web.dart';
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

  Auth0? _auth0;
  Auth0Web? _auth0Web;

  Auth0Service({
    required this.domain,
    required this.clientId,
    this.audience,
    this.callbackUrl,
    this.logoutUrl,
  }) {
    if (kIsWeb) {
      _auth0Web = Auth0Web(domain: domain, clientId: clientId);
    } else {
      _auth0 = Auth0(domain, clientId);
    }
  }

  Future<void> login({bool signup = false}) async {
    if (kIsWeb) {
      await _auth0Web?.loginWithRedirect(
        redirectUrl: callbackUrl,
        authorizationParams: AuthorizationParams(
          audience: audience,
          scope: 'openid profile email',
          screenHint: signup ? 'signup' : null,
        ),
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
      await _auth0Web?.logout(
        options: LogoutOptions(returnTo: logoutUrl ?? callbackUrl),
      );
      return;
    }

    await _auth0?.webAuthentication().logout(
          returnTo: logoutUrl ?? callbackUrl,
        );
  }

  Future<Auth0UserProfile?> getUser() async {
    try {
      if (kIsWeb) {
        final profile = await _auth0Web?.getUser();
        if (profile == null) return null;
        return Auth0UserProfile(
          name: profile.name,
          email: profile.email,
          picture: profile.picture,
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
        return _auth0Web?.getTokenSilently(
            audience: audience, scope: 'openid profile email');
      }
      final creds = await _auth0?.credentialsManager.credentials();
      return creds?.accessToken;
    } catch (_) {
      return null;
    }
  }
}
