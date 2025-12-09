import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

  GraphAccount({
    required this.id,
    required this.displayName,
    required this.userPrincipalName,
    required this.accessToken,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'userPrincipalName': userPrincipalName,
        'accessToken': accessToken,
      };

  factory GraphAccount.fromJson(Map<String, dynamic> json) => GraphAccount(
        id: json['id'] as String,
        displayName: json['displayName'] as String? ?? '',
        userPrincipalName: json['userPrincipalName'] as String? ?? '',
        accessToken: json['accessToken'] as String,
      );
}

class GraphAuthService {
  // Values injected via --dart-define (see CI workflow). Tenant defaults to 'common'.
  static const _tenant =
      String.fromEnvironment('GRAPH_TENANT_ID', defaultValue: 'common');
  static const _clientId =
      String.fromEnvironment('GRAPH_CLIENT_ID', defaultValue: '');

  static const _scopes = [
    'User.Read',
    'Files.Read',
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
    if (_clientId.isEmpty) {
      throw Exception(
          'Graph client ID missing. Provide via --dart-define=GRAPH_CLIENT_ID');
    }
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
    if (active != null) return active.accessToken;
    await connectWithDeviceCode();
    final newActive = activeAccount;
    if (newActive == null) {
      throw Exception('Failed to obtain Microsoft Graph access token');
    }
    return newActive.accessToken;
  }
}
