import 'package:auth0_flutter/auth0_flutter.dart';

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

  late final Auth0 _auth0;

  Auth0Service({
    required this.domain,
    required this.clientId,
    this.audience,
    this.callbackUrl,
    this.logoutUrl,
  }) {
    _auth0 = Auth0(domain, clientId);
  }

  Future<void> login({bool signup = false}) async {
    await _auth0.webAuthentication().login(
          audience: audience,
          scopes: ['openid', 'profile', 'email'],
          redirectUrl: callbackUrl,
          parameters: signup ? {'screen_hint': 'signup'} : null,
        );
  }

  Future<void> logout() async {
    await _auth0.webAuthentication().logout(
          returnTo: logoutUrl ?? callbackUrl,
        );
  }

  Future<Auth0UserProfile?> getUser() async {
    try {
      final creds = await _auth0.credentialsManager.credentials();
      final claims = creds.idTokenClaims ?? {};
      return Auth0UserProfile(
        name: claims['name'] as String?,
        email: claims['email'] as String?,
        picture: claims['picture'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> getAccessToken() async {
    try {
      final creds = await _auth0.credentialsManager.credentials();
      return creds.accessToken;
    } catch (_) {
      return null;
    }
  }
}
