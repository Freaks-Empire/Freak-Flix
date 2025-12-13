import 'package:flutter/foundation.dart';
import '../services/auth0_service.dart';

class AuthProvider extends ChangeNotifier {
  final Auth0Service auth0;
  bool _loading = false;
  String? _error;
  Auth0UserProfile? _user;

  AuthProvider(this.auth0);

  bool get isAuthenticated => _user != null;
  bool get isLoading => _loading;
  String? get error => _error;
  Auth0UserProfile? get user => _user;

  Future<void> restoreSession() async {
    _setLoading(true);
    try {
      final profile = await auth0.getUser();
      _user = profile;
    } catch (_) {
      _user = null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> login() async {
    _setLoading(true);
    try {
      await auth0.login();
      _user = await auth0.getUser();
      _error = null;
      notifyListeners();
    } catch (e, st) {
      // Surface full stack to help diagnose null-assert errors in release.
      _error = '$e\n$st';
      debugPrint('Auth0 login error: $e');
      debugPrintStack(stackTrace: st);
      // Don't rethrow, just show error in UI
    } finally {
      _setLoading(false);
    }
  }

  Future<void> cancelLogin() async {
    await auth0.cancelLogin();
    _setLoading(false);
  }

  Future<void> logout() async {
    await auth0.logout();
    _user = null;
    _error = null;
    notifyListeners();
  }

  Future<String?> getAccessToken() => auth0.getAccessToken();

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }
}
