/// lib/services/api_service.dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  static ApiService get instance => _instance;
  ApiService._internal();

  String get _baseUrl => dotenv.get('BACKEND_URL', fallback: 'http://localhost:8787');
  String? _token;

  Future<String?> get token async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    return _token;
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove('auth_token');
    } else {
      await prefs.setString('auth_token', token);
    }
  }

  Future<Map<String, String>> _headers() async {
    final t = await token;
    return {
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  // Auth
  Future<dynamic> register(String email, String password) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (resp.statusCode >= 400) throw Exception(resp.body);
    return jsonDecode(resp.body);
  }

  Future<dynamic> login(String email, String password) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (resp.statusCode >= 400) throw Exception(resp.body);
    final data = jsonDecode(resp.body);
    await setToken(data['token']);
    return data['user'];
  }

  Future<dynamic> me() async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/auth/me'),
      headers: await _headers(),
    );
    if (resp.statusCode >= 400) throw Exception(resp.body);
    return jsonDecode(resp.body);
  }

  // Library
  Future<void> triggerScan({
    required String folderId,
    required String accessToken,
    required String path,
    String provider = 'onedrive',
  }) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/library/scan'),
      headers: await _headers(),
      body: jsonEncode({
        'folderId': folderId,
        'accessToken': accessToken,
        'path': path,
        'provider': provider,
      }),
    );
    if (resp.statusCode >= 400) throw Exception(resp.body);
  }

  Future<List<dynamic>> getItems() async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/library/items'),
      headers: await _headers(),
    );
    if (resp.statusCode >= 400) throw Exception(resp.body);
    final data = jsonDecode(resp.body);
    return data['items'];
  }
}
