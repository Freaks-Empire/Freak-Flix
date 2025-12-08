import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Handles Microsoft Graph authentication using the device code flow.
class GraphAuthService {
  /// Replace with your tenant or leave as 'organizations'/'consumers' depending on account type.
  static const String _tenant = 'organizations';

  /// TODO: replace with your real Azure AD application (client) ID.
  static const String _clientId = 'YOUR_CLIENT_ID_HERE';

  /// Basic scopes for OneDrive files and profile.
  static const List<String> _scopes = <String>[
    'offline_access',
    'Files.Read',
    'User.Read',
  ];

  static const String _tokenKey = 'graph_access_token_v1';
  static const String _tokenExpiryKey = 'graph_access_token_expiry_v1';

  String? _accessToken;
  DateTime? _expiresAt;

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final expiryRaw = prefs.getString(_tokenExpiryKey);

    if (token != null && expiryRaw != null) {
      final expiry = DateTime.tryParse(expiryRaw);
      if (expiry != null && expiry.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
        _accessToken = token;
        _expiresAt = expiry;
      }
    }
  }

  Future<void> _saveToken(String token, int expiresInSeconds) async {
    _accessToken = token;
    _expiresAt = DateTime.now().add(Duration(seconds: expiresInSeconds));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_tokenExpiryKey, _expiresAt!.toIso8601String());
  }

  bool get isLoggedIn =>
      _accessToken != null &&
      _expiresAt != null &&
      _expiresAt!.isAfter(DateTime.now().add(const Duration(minutes: 5)));

  String? get accessToken => _accessToken;

  /// Get a valid token, performing device-code login when needed.
  Future<String> getOrLoginWithDeviceCode() async {
    if (isLoggedIn) return _accessToken!;

    final authority = 'https://login.microsoftonline.com/$_tenant';
    final deviceCodeUrl = Uri.parse('$authority/oauth2/v2.0/devicecode');
    final tokenUrl = Uri.parse('$authority/oauth2/v2.0/token');

    // 1) Request device code
    final dcRes = await http.post(
      deviceCodeUrl,
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': _clientId,
        'scope': _scopes.join(' '),
      },
    );

    if (dcRes.statusCode != 200) {
      throw Exception('Device code request failed: ${dcRes.statusCode} ${dcRes.body}');
    }

    final dc = jsonDecode(dcRes.body) as Map<String, dynamic>;
    final deviceCode = dc['device_code'] as String;
    final userCode = dc['user_code'] as String;
    final verificationUri = dc['verification_uri'] as String? ??
        dc['verification_uri_complete'] as String? ??
        'https://microsoft.com/devicelogin';
    final interval = (dc['interval'] as num?)?.toInt() ?? 5;

    // TODO: surface these instructions in the UI; for now, log to console.
    stdout.writeln('========== Microsoft Login =========');
    stdout.writeln('Go to: $verificationUri');
    stdout.writeln('Enter code: $userCode');
    stdout.writeln('====================================');

    // 2) Poll token endpoint
    while (true) {
      await Future.delayed(Duration(seconds: interval));

      final tokenRes = await http.post(
        tokenUrl,
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          'client_id': _clientId,
          'device_code': deviceCode,
        },
      );

      final body = jsonDecode(tokenRes.body) as Map<String, dynamic>;

      if (tokenRes.statusCode == 200) {
        final token = body['access_token'] as String;
        final expiresIn = (body['expires_in'] as num).toInt();
        await _saveToken(token, expiresIn);
        return token;
      }

      final error = body['error'] as String?;
      if (error == 'authorization_pending') {
        // user has not finished yet – keep polling
        continue;
      } else if (error == 'authorization_declined' || error == 'expired_token') {
        throw Exception('User did not complete Microsoft sign-in.');
      } else if (error != null) {
        throw Exception('Token error: $error – ${body['error_description']}');
      } else {
        throw Exception('Token request failed: ${tokenRes.statusCode}');
      }
    }
  }

  Future<void> signOut() async {
    _accessToken = null;
    _expiresAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_tokenExpiryKey);
  }
}
