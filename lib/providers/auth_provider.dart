import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/netlify_auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final NetlifyAuthService authService;
  bool _loading = false;
  String? _accessToken;
  String? _email;
  String? _error;

  AuthProvider(this.authService);

  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;
  bool get isLoading => _loading;
  String? get email => _email;
  String? get error => _error;

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('netlify_access_token');
    _email = prefs.getString('netlify_email');
    notifyListeners();
  }

  Future<void> signup(String email, String password, {String? fullName}) async {
    _setLoading(true);
    try {
      await authService.signup(email: email, password: password, fullName: fullName);
      await login(email, password);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> login(String email, String password) async {
    _setLoading(true);
    try {
      final payload = await authService.login(email: email, password: password);
      _accessToken = payload['access_token'] as String?;
      _email = email;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refresh() async {
    _setLoading(true);
    try {
      final payload = await authService.refreshToken();
      _accessToken = payload['access_token'] as String?;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await authService.logout();
    _accessToken = null;
    _email = null;
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }
}
