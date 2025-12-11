import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NetlifyAuthService {
  final String baseUrl; // e.g. https://your-site.netlify.app

  NetlifyAuthService(this.baseUrl);

  Uri _endpoint(String path) => Uri.parse('$baseUrl/.netlify/identity/$path');

  Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final res = await http.post(
      _endpoint('signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        if (fullName != null && fullName.isNotEmpty)
          'user_metadata': {'full_name': fullName},
      }),
    );
    _throwOnError(res, 'Signup failed');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      _endpoint('token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'grant_type': 'password',
        'username': email,
        'password': password,
      }),
    );
    _throwOnError(res, 'Login failed');
    final payload = jsonDecode(res.body) as Map<String, dynamic>;
    await _saveTokens(payload, email);
    return payload;
  }

  Future<Map<String, dynamic>> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString('netlify_refresh_token');
    if (refresh == null) {
      throw Exception('No refresh token');
    }
    final res = await http.post(
      _endpoint('token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'grant_type': 'refresh_token',
        'refresh_token': refresh,
      }),
    );
    _throwOnError(res, 'Refresh failed');
    final payload = jsonDecode(res.body) as Map<String, dynamic>;
    await _saveTokens(payload, prefs.getString('netlify_email'));
    return payload;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('netlify_access_token');
    await prefs.remove('netlify_refresh_token');
    await prefs.remove('netlify_email');
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('netlify_access_token');
  }

  Future<void> _saveTokens(Map<String, dynamic> payload, String? email) async {
    final prefs = await SharedPreferences.getInstance();
    final access = payload['access_token'] as String?;
    final refresh = payload['refresh_token'] as String?;
    if (access != null) await prefs.setString('netlify_access_token', access);
    if (refresh != null) await prefs.setString('netlify_refresh_token', refresh);
    if (email != null) await prefs.setString('netlify_email', email);
  }

  Never _throwOnError(http.Response res, String message) {
    if (res.statusCode >= 400) {
      throw Exception('$message: ${res.statusCode} ${res.body}');
    }
    throw Exception('Unreachable');
  }
}
