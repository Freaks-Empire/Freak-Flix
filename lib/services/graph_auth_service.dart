import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GraphUser {
  final String displayName;
  final String userPrincipalName;

  GraphUser({
    required this.displayName,
    required this.userPrincipalName,
  });
}

class GraphAuthService {
  // Use 'common' so both personal and org accounts work.
  static const _tenant = 'common';

  // TODO: put your real Application (client) ID here
  static const _clientId = 'YOUR_CLIENT_ID_HERE';

  static const _scopes = [
    'User.Read',
    'Files.Read',
  ];

  static const _tokenKey = 'graph_token_v1';
  static const _userNameKey = 'graph_user_name_v1';
  static const _userUpnKey = 'graph_user_upn_v1';

  String? _accessToken;
  GraphUser? _user;

  String? get accessToken => _accessToken;
  GraphUser? get currentUser => _user;
  bool get isConnected => _accessToken != null;

  /// Load saved token and user from SharedPreferences.
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_tokenKey);
    final name = prefs.getString(_userNameKey);
    final upn = prefs.getString(_userUpnKey);
    if (_accessToken != null && upn != null) {
      _user = GraphUser(displayName: name ?? upn, userPrincipalName: upn);
    }
  }

  Future<void> _saveToPrefs(String token, GraphUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userNameKey, user.displayName);
    await prefs.setString(_userUpnKey, user.userPrincipalName);
    _accessToken = token;
    _user = user;
  }

  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userUpnKey);
    _accessToken = null;
    _user = null;
  }

  /// Connects the account using device-code flow and returns user info.
  Future<GraphUser> connectWithDeviceCode() async {
    final authority = 'https://login.microsoftonline.com/$_tenant';
    final deviceCodeUrl = Uri.parse('$authority/oauth2/v2.0/devicecode');
    final tokenUrl = Uri.parse('$authority/oauth2/v2.0/token');

    // Request device code
    final dcRes = await http.post(
      deviceCodeUrl,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': _clientId,
        'scope': _scopes.join(' '),
      },
    );

    if (dcRes.statusCode != 200) {
      throw Exception(
          'Device code request failed: ${dcRes.statusCode} ${dcRes.body}');
    }

    final dc = jsonDecode(dcRes.body) as Map<String, dynamic>;
    final deviceCode = dc['device_code'] as String;
    final userCode = dc['user_code'] as String;
    final verificationUri = (dc['verification_uri'] as String?) ??
        (dc['verification_uri_complete'] as String?) ??
        'https://microsoft.com/devicelogin';
    final interval = (dc['interval'] as num?)?.toInt() ?? 5;

    // Surface device-code instructions in logs for now.
    print('========== Microsoft Login =========');
    print('Go to: $verificationUri');
    print('Enter code: $userCode');
    print('====================================');

    // 2) Poll for token
    while (true) {
      await Future.delayed(Duration(seconds: interval));

      final tokenRes = await http.post(
        tokenUrl,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          'client_id': _clientId,
          'device_code': deviceCode,
        },
      );

      final body = jsonDecode(tokenRes.body) as Map<String, dynamic>;
      if (tokenRes.statusCode == 200) {
        final token = body['access_token'] as String;
        final user = await _fetchMe(token);
        await _saveToPrefs(token, user);
        return user;
      }

      final error = body['error'] as String?;
      if (error == 'authorization_pending') {
        continue; // user hasn't finished yet
      }
      throw Exception('Token error: $error ${body['error_description']}');
    }
  }

  Future<GraphUser> _fetchMe(String token) async {
    final res = await http.get(
      Uri.parse('https://graph.microsoft.com/v1.0/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) {
      throw Exception(
          'Failed to fetch user profile: ${res.statusCode} ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final displayName = (json['displayName'] as String?) ?? '';
    final upn = (json['userPrincipalName'] as String?) ?? '';
    return GraphUser(
      displayName: displayName.isEmpty ? upn : displayName,
      userPrincipalName: upn,
    );
  }
}
