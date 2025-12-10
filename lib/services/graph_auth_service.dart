import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NotInitializedError implements Exception {
  final String message;
  NotInitializedError([this.message = '']);
  @override
  String toString() => 'NotInitializedError: $message';
}

class GraphUser {
  final String id;
  final String displayName;
  final String userPrincipalName;

  GraphUser({
    required this.id,
    required this.displayName,
    required this.userPrincipalName,
  });
}

class GraphAccount {
  final String id;
  final String displayName;
  final String userPrincipalName;
  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  GraphAccount({
    required this.id,
    required this.displayName,
    required this.userPrincipalName,
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'userPrincipalName': userPrincipalName,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt?.toIso8601String(),
      };

  factory GraphAccount.fromJson(Map<String, dynamic> json) => GraphAccount(
        id: json['id'] as String,
        displayName: json['displayName'] as String? ?? '',
        userPrincipalName: json['userPrincipalName'] as String? ?? '',
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      expiresAt: json['expiresAt'] != null
      ? DateTime.tryParse(json['expiresAt'] as String)
      : null,
      );
}

class GraphAuthService {
  GraphAuthService._();
  static final GraphAuthService _instance = GraphAuthService._();
  factory GraphAuthService() => _instance;
  static GraphAuthService get instance => _instance;

  String? _clientId;
  String _tenant = 'common';
  late Uri _deviceCodeEndpoint;
  late Uri _tokenEndpoint;

  bool get isConfigured => _clientId != null && _clientId!.isNotEmpty;

  void configureFromEnv() {
    final String? clientIdRaw = dotenv.env['GRAPH_CLIENT_ID'] ?? dotenv.env['AZURE_CLIENT_ID'];
    final String? tenantIdRaw = dotenv.env['GRAPH_TENANT_ID'] ?? dotenv.env['AZURE_TENANT_ID'];

    final String clientId = clientIdRaw?.trim() ?? '';
    final String tenant = (tenantIdRaw?.trim().isNotEmpty ?? false)
        ? tenantIdRaw!.trim()
        : 'common';

    if (clientId.isEmpty) {
      throw NotInitializedError('GRAPH_CLIENT_ID must be set in .env');
    }

    _clientId = clientId;
    _tenant = tenant;
    _deviceCodeEndpoint = Uri.parse('https://login.microsoftonline.com/$_tenant/oauth2/v2.0/devicecode');
    _tokenEndpoint = Uri.parse('https://login.microsoftonline.com/$_tenant/oauth2/v2.0/token');
  }

  void _ensureConfigured() {
    if (!isConfigured) {
      throw NotInitializedError('GraphAuthService not configured. Call configureFromEnv() during startup.');
    }
  }

  static const _scopes = [
    'User.Read',
    'Files.Read',
    'offline_access', // Needed to receive refresh tokens.
  ];

  static const _accountsKey = 'graph_accounts_v1';
  static const _activeAccountIdKey = 'graph_active_account_v1';

  List<GraphAccount> _accounts = [];
  String? _activeAccountId;

  List<GraphAccount> get accounts => List.unmodifiable(_accounts);
  GraphAccount? get activeAccount {
    if (_accounts.isEmpty) return null;
    final existing = _accounts.where((a) => a.id == _activeAccountId);
    if (existing.isNotEmpty) return existing.first;
    return _accounts.first;
  }

  String? get activeAccountId => activeAccount?.id;
  bool get isConnected => _accounts.isNotEmpty;

  /// Load saved token and user from SharedPreferences.
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _activeAccountId = prefs.getString(_activeAccountIdKey);
    final raw = prefs.getString(_accountsKey);
    if (raw == null) {
      _accounts = [];
      return;
    }
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => GraphAccount.fromJson(e as Map<String, dynamic>))
          .toList();
      _accounts = list;
      if (_activeAccountId != null &&
          !_accounts.any((a) => a.id == _activeAccountId)) {
        _activeAccountId = _accounts.isNotEmpty ? _accounts.first.id : null;
      }
    } catch (_) {
      _accounts = [];
      _activeAccountId = null;
    }
  }

  Future<void> _saveAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _accountsKey,
      jsonEncode(_accounts.map((a) => a.toJson()).toList()),
    );
    if (_activeAccountId != null) {
      await prefs.setString(_activeAccountIdKey, _activeAccountId!);
    } else {
      await prefs.remove(_activeAccountIdKey);
    }
  }

  Future<void> _upsertAccount(GraphAccount account) async {
    _accounts.removeWhere((a) => a.id == account.id);
    _accounts.add(account);
    _activeAccountId = account.id;
    await _saveAccounts();
  }

  Future<void> removeAccount(String accountId) async {
    _accounts.removeWhere((a) => a.id == accountId);
    if (_activeAccountId == accountId) {
      _activeAccountId = _accounts.isNotEmpty ? _accounts.first.id : null;
    }
    await _saveAccounts();
  }

  Future<void> setActiveAccount(String accountId) async {
    if (_accounts.any((a) => a.id == accountId)) {
      _activeAccountId = accountId;
      await _saveAccounts();
    }
  }

  Future<void> clearAll() async {
    _accounts = [];
    _activeAccountId = null;
    await _saveAccounts();
  }

  Future<void> _saveToPrefs(String token, GraphUser user) async {
    final prefs = await SharedPreferences.getInstance();
    // Back-compat: store latest single token so old callers still work during migration.
    await prefs.setString('graph_token_v1', token);
    await prefs.setString('graph_user_name_v1', user.displayName);
    await prefs.setString('graph_user_upn_v1', user.userPrincipalName);

    final account = GraphAccount(
      id: user.id,
      displayName: user.displayName,
      userPrincipalName: user.userPrincipalName,
      accessToken: token,
    );
    await _upsertAccount(account);
  }

  Future<void> disconnect() async {
    await clearAll();
  }

  /// Connects the account using device-code flow and returns user info.
  Future<GraphUser> connectWithDeviceCode() async {
    _ensureConfigured();

    final clientId = _clientId!;

    final deviceCodeUrl = _deviceCodeEndpoint;
    final tokenUrl = _tokenEndpoint;

    // Request device code
    final dcRes = await http.post(
      deviceCodeUrl,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
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
          'client_id': clientId,
          'device_code': deviceCode,
        },
      );

      final body = jsonDecode(tokenRes.body) as Map<String, dynamic>;
      if (tokenRes.statusCode == 200) {
        final token = body['access_token'] as String;
        final refreshToken = body['refresh_token'] as String?;
        final expiresIn = (body['expires_in'] as num?)?.toInt() ?? 3600;
        final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
        final user = await _fetchMe(token);
        final account = GraphAccount(
          id: user.id,
          displayName: user.displayName,
          userPrincipalName: user.userPrincipalName,
          accessToken: token,
          refreshToken: refreshToken,
          expiresAt: expiresAt,
        );
        await _upsertAccount(account);
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
    final id = (json['id'] as String?) ?? '';
    final displayName = (json['displayName'] as String?) ?? '';
    final upn = (json['userPrincipalName'] as String?) ?? '';
    return GraphUser(
      id: id.isEmpty ? upn : id,
      displayName: displayName.isEmpty ? upn : displayName,
      userPrincipalName: upn,
    );
  }

  /// Returns an access token, performing device-code login if needed.
  Future<String> getOrLoginWithDeviceCode() async {
    final active = activeAccount;
    if (active != null) return getFreshAccessToken(active.id);
    await connectWithDeviceCode();
    final newActive = activeAccount;
    if (newActive == null) {
      throw Exception('Failed to obtain Microsoft Graph access token');
    }
    return getFreshAccessToken(newActive.id);
  }

  /// Ensure the access token for the given account is fresh, refreshing if possible.
  Future<String> getFreshAccessToken(String accountId) async {
    final account = _accounts.firstWhere(
      (a) => a.id == accountId,
      orElse: () => throw Exception('No account found for id $accountId'),
    );

    // If we do not know expiry (older saved token), just return what we have.
    if (account.expiresAt == null) {
      return account.accessToken;
    }

    // If token is still valid for at least 5 minutes, reuse it.
    final now = DateTime.now();
    final grace = const Duration(minutes: 5);
    if (now.isBefore(account.expiresAt!.subtract(grace))) {
      return account.accessToken;
    }

    // Try refresh if we have a refresh token.
    if (account.refreshToken != null && account.refreshToken!.isNotEmpty) {
      final refreshed = await _refreshAccount(account);
      return refreshed.accessToken;
    }

    // Fall back to forcing a new login.
    final user = await connectWithDeviceCode();
    final refreshed = _accounts.firstWhere(
      (a) => a.id == user.id,
      orElse: () => throw Exception('Login succeeded but account missing'),
    );
    return refreshed.accessToken;
  }

  Future<GraphAccount> _refreshAccount(GraphAccount account) async {
    _ensureConfigured();

    final res = await http.post(
      _tokenEndpoint,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'client_id': _clientId!,
        'refresh_token': account.refreshToken ?? '',
        'scope': _scopes.join(' '),
      },
    );

    if (res.statusCode != 200) {
      throw Exception(
          'Failed to refresh token (${res.statusCode}): ${res.body}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final accessToken = body['access_token'] as String?;
    final refreshToken = body['refresh_token'] as String? ?? account.refreshToken;
    final expiresIn = (body['expires_in'] as num?)?.toInt() ?? 3600;
    if (accessToken == null) {
      throw Exception('Refresh response missing access_token');
    }

    final updated = GraphAccount(
      id: account.id,
      displayName: account.displayName,
      userPrincipalName: account.userPrincipalName,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );

    await _upsertAccount(updated);
    return updated;
  }
}
