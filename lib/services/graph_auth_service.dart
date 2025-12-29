/// lib/services/graph_auth_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'persistence_service.dart';

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

class DeviceCodeSession {
  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final int interval;
  final DateTime expiresAt;

  const DeviceCodeSession({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.interval,
    required this.expiresAt,
  });
}

enum DeviceCodePollState {
  pending,
  slowDown,
  declined,
  expired,
  success,
  error
}

class DeviceCodePollResult {
  final DeviceCodePollState state;
  final GraphAccount? account;
  final String? error;
  final int? recommendedInterval;

  const DeviceCodePollResult({
    required this.state,
    this.account,
    this.error,
    this.recommendedInterval,
  });
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
  
  void Function()? onStateChanged;

  bool get isConfigured => _clientId != null && _clientId!.isNotEmpty;

  String? _configError;

  /// Returns the base URL for Graph API calls (e.g. https://graph.microsoft.com/v1.0 or /api/graph/v1.0 on web)
  String get graphBaseUrl {
    if (kIsWeb) {
      // Use local proxy defined in netlify.toml
      return '/api/graph/v1.0';
    }
    return 'https://graph.microsoft.com/v1.0';
  }

  void configureFromEnv() {
    final String? clientIdRaw = dotenv.env['GRAPH_CLIENT_ID'] ??
        dotenv.env['AZURE_CLIENT_ID'] ??
        const String.fromEnvironment('GRAPH_CLIENT_ID');
    final String? tenantIdRaw = dotenv.env['GRAPH_TENANT_ID'] ??
        dotenv.env['AZURE_TENANT_ID'] ??
        const String.fromEnvironment('GRAPH_TENANT_ID');

    final String clientId = clientIdRaw?.trim() ?? '';
    final String tenant = (tenantIdRaw?.trim().isNotEmpty ?? false)
        ? tenantIdRaw!.trim()
        : 'common';

    if (clientId.isEmpty) {
      _configError = 'GRAPH_CLIENT_ID missing. Env keys found: ${dotenv.env.keys.toList()}';
      debugPrint('GraphAuthService: $_configError');
      return;
    }

    _clientId = clientId;
    _tenant = tenant;
    _configError = null; // Success
    
    if (kIsWeb) {
      // Use local proxy to avoid CORS on web
      // Configured in netlify.toml: /api/ms_auth/* -> https://login.microsoftonline.com/:splat
      const proxyPrefix = '/api/ms_auth';
      _deviceCodeEndpoint = Uri.parse('$proxyPrefix/$_tenant/oauth2/v2.0/devicecode');
      _tokenEndpoint = Uri.parse('$proxyPrefix/$_tenant/oauth2/v2.0/token');
    } else {
      _deviceCodeEndpoint = Uri.parse(
          'https://login.microsoftonline.com/$_tenant/oauth2/v2.0/devicecode');
      _tokenEndpoint = Uri.parse(
          'https://login.microsoftonline.com/$_tenant/oauth2/v2.0/token');
    }
  }

  void _ensureConfigured() {
    if (!isConfigured) {
      throw NotInitializedError(
          _configError ?? 'GraphAuthService not configured. Call configureFromEnv() during startup.');
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

  Map<String, dynamic> exportState() {
    return {
      'accounts': _accounts.map((a) => a.toJson()).toList(),
      'activeAccountId': _activeAccountId,
    };
  }

  Future<void> importState(Map<String, dynamic> data) async {
    if (data['accounts'] != null) {
      final list = (data['accounts'] as List<dynamic>)
          .map((e) => GraphAccount.fromJson(e as Map<String, dynamic>))
          .toList();
      _accounts = list;
    }
    _activeAccountId = data['activeAccountId'] as String?;
    await _saveAccounts();
  }

  static const _storageFile = 'graph_auth.json';

  /// Load saved token and user from PersistenceService.
  Future<void> loadFromPrefs() async {
    debugPrint('GraphAuthService: Loading from file storage...');
    try {
      final jsonStr = await PersistenceService.instance.loadString(_storageFile);
      
      if (jsonStr == null) {
        // Fallback: Try SharedPreferences for migration
         debugPrint('GraphAuthService: No file found. Checking legacy SharedPreferences...');
         await _migrateFromPrefs();
         return;
      }

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      if (data['accounts'] != null) {
        final list = (data['accounts'] as List<dynamic>)
            .map((e) => GraphAccount.fromJson(e as Map<String, dynamic>))
            .toList();
        _accounts = list;
      }
      
      _activeAccountId = data['activeAccountId'] as String?;
      
      if (_activeAccountId != null && !_accounts.any((a) => a.id == _activeAccountId)) {
         _activeAccountId = null;
      }
       debugPrint('GraphAuthService: Successfully loaded ${_accounts.length} accounts from file.');

    } catch (e, stack) {
      debugPrint('GraphAuthService: ERROR loading accounts from file: $e\n$stack');
      _accounts = [];
      _activeAccountId = null;
    }
  }

  Future<void> _migrateFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_accountsKey);
    final activeId = prefs.getString(_activeAccountIdKey);
    
    if (raw == null) {
       debugPrint('GraphAuthService: No legacy accounts found.');
       return;
    }
    
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => GraphAccount.fromJson(e as Map<String, dynamic>))
          .toList();
      _accounts = list;
      _activeAccountId = activeId;
      
      // Save to new storage
      await _saveAccounts();
      debugPrint('GraphAuthService: Migrated ${_accounts.length} accounts from SharedPreferences.');
    } catch (e) {
      debugPrint('GraphAuthService: Migration failed: $e');
    }
  }

  Future<void> _saveAccounts() async {
    final data = {
      'accounts': _accounts.map((a) => a.toJson()).toList(),
      'activeAccountId': _activeAccountId,
    };
    await PersistenceService.instance.saveString(_storageFile, jsonEncode(data));
    onStateChanged?.call();
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

  Future<DeviceCodeSession> requestDeviceCode() async {
    _ensureConfigured();

    final dcRes = await http.post(
      _deviceCodeEndpoint,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': _clientId!,
        'scope': _scopes.join(' '),
      },
    );

    if (dcRes.statusCode != 200) {
      debugPrint('Device code request failed: ${dcRes.statusCode}');
      debugPrint('Body: ${dcRes.body}');
      throw Exception(
          'Device code request failed: ${dcRes.statusCode} ${dcRes.body}');
    }

    final dc = jsonDecode(dcRes.body) as Map<String, dynamic>;
    final expiresIn = (dc['expires_in'] as num?)?.toInt() ?? 900;
    final verificationUri = (dc['verification_uri_complete'] as String?) ??
        (dc['verification_uri'] as String?) ??
        'https://microsoft.com/devicelogin';

    return DeviceCodeSession(
      deviceCode: dc['device_code'] as String,
      userCode: dc['user_code'] as String,
      verificationUri: verificationUri,
      interval: (dc['interval'] as num?)?.toInt() ?? 5,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  Future<DeviceCodePollResult> pollDeviceCode(DeviceCodeSession session) async {
    _ensureConfigured();

    final tokenRes = await http.post(
      _tokenEndpoint,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        'client_id': _clientId!,
        'device_code': session.deviceCode,
      },
    );

    final body = jsonDecode(tokenRes.body) as Map<String, dynamic>;
    if (tokenRes.statusCode == 200 && body['access_token'] != null) {
      final account = await _accountFromTokenPayload(body);
      return DeviceCodePollResult(
          state: DeviceCodePollState.success, account: account);
    }

    final error = body['error'] as String? ?? 'unknown_error';
    final description = body['error_description'] as String?;
    if (error == 'authorization_pending') {
      return const DeviceCodePollResult(state: DeviceCodePollState.pending);
    }
    if (error == 'slow_down') {
      final nextInterval = session.interval + 5;
      return DeviceCodePollResult(
        state: DeviceCodePollState.slowDown,
        recommendedInterval: nextInterval,
        error: description,
      );
    }
    if (error == 'authorization_declined') {
      return DeviceCodePollResult(
        state: DeviceCodePollState.declined,
        error: description,
      );
    }
    if (error == 'expired_token') {
      return DeviceCodePollResult(
        state: DeviceCodePollState.expired,
        error: description,
      );
    }

    return DeviceCodePollResult(
      state: DeviceCodePollState.error,
      error: description ?? error,
    );
  }

  Future<GraphAccount> _accountFromTokenPayload(
      Map<String, dynamic> body) async {
    final token = body['access_token'] as String?;
    if (token == null) {
      throw Exception('Token response missing access_token');
    }
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
    return account;
  }

  GraphUser _userFromAccount(GraphAccount account) => GraphUser(
        id: account.id,
        displayName: account.displayName,
        userPrincipalName: account.userPrincipalName,
      );

  /// Connects the account using device-code flow and returns user info.
  Future<GraphUser> connectWithDeviceCode({
    void Function(DeviceCodeSession session)? onUserCode,
  }) async {
    final session = await requestDeviceCode();

    if (onUserCode != null) {
      onUserCode(session);
    } else {
      print('========== Microsoft Login =========');
      print('Go to: ${session.verificationUri}');
      print('Enter code: ${session.userCode}');
      print('====================================');
    }

    var interval = session.interval;
    while (DateTime.now().isBefore(session.expiresAt)) {
      await Future.delayed(Duration(seconds: interval));
      final result = await pollDeviceCode(session);
      switch (result.state) {
        case DeviceCodePollState.pending:
          continue;
        case DeviceCodePollState.slowDown:
          interval = result.recommendedInterval ?? (interval + 5);
          continue;
        case DeviceCodePollState.declined:
          throw Exception('Authorization declined by user.');
        case DeviceCodePollState.expired:
          throw Exception('Device code expired. Please try again.');
        case DeviceCodePollState.error:
          throw Exception('Token error: ${result.error ?? 'unknown_error'}');
        case DeviceCodePollState.success:
          final account = result.account;
          if (account == null) {
            throw Exception('Token response missing account payload');
          }
          return _userFromAccount(account);
      }
    }

    throw Exception('Device code expired. Please try again.');
  }

  Future<GraphUser> _fetchMe(String token) async {
    final res = await http.get(
      Uri.parse('$graphBaseUrl/me'),
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

  /// Fetches a fresh download URL for a specific drive item.
  Future<String?> getDownloadUrl(String accountId, String itemId) async {
    try {
      final token = await getFreshAccessToken(accountId);
      
      final url = Uri.parse('$graphBaseUrl/me/drive/items/$itemId');
      final res = await http.get(url, headers: {'Authorization': 'Bearer $token'});
      
      if (res.statusCode != 200) {
        debugPrint('getDownloadUrl failed: ${res.statusCode} ${res.body}');
        return null;
      }
      
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return json['@microsoft.graph.downloadUrl'] as String?;
    } catch (e) {
      debugPrint('getDownloadUrl error: $e');
      return null;
    }
  }

  /// Fetches an HLS stream manifest URL for a video item.
  /// Returns null if HLS is not available or fails.
  Future<String?> getHlsUrl(String accountId, String itemId) async {
    try {
       final token = await getFreshAccessToken(accountId);

       if (kIsWeb) {
          // 'followRedirects' is not supported on Web.
          // Getting raw m3u8 content via XHR is possible but requires complex proxying for segments.
          // For now, disable HLS on Web and fallback to downloadUrl.
          debugPrint('getHlsUrl: Skipped on Web (platform limitation).');
          return null;
       }
       
       // Request content with format=hls
       // We must disable following redirects to capture the 302 Location header
       final url = Uri.parse('$graphBaseUrl/me/drive/items/$itemId/content?format=hls');
       
       final request = http.Request('GET', url)
         ..followRedirects = false
         ..headers['Authorization'] = 'Bearer $token';
         
       final streamedRes = await request.send();
       
       if (streamedRes.statusCode == 302) {
          final location = streamedRes.headers['location'];
          if (location != null && location.isNotEmpty) {
             debugPrint('Got HLS URL for $itemId: $location');
             return location;
          }
       }
       
       debugPrint('getHlsUrl failed: ${streamedRes.statusCode} (Expected 302)');
       return null;
    } catch (e) {
       debugPrint('getHlsUrl error: $e');
       return null;
    }
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
      debugPrint('Token refresh failed: ${res.statusCode}');
      debugPrint('Body: ${res.body}');
      throw Exception(
          'Failed to refresh token (${res.statusCode}): ${res.body}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final accessToken = body['access_token'] as String?;
    final refreshToken =
        body['refresh_token'] as String? ?? account.refreshToken;
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

  /// Uploads a text string as a file to a specific parent folder.
  /// Used for creating metadata sidecar files (NFO/JSON).
  /// [parentId] is the OneDrive ID of the folder to put the file in.
  /// [filename] is the name of the file to create/overwrite.
  Future<bool> uploadString({
      required String accountId,
      required String parentId,
      required String filename,
      required String content,
  }) async {
    try {
       final token = await getFreshAccessToken(accountId);
       // PUT /me/drive/items/{parent-id}:/{filename}:/content
       final url = Uri.parse('$graphBaseUrl/me/drive/items/$parentId:/$filename:/content');
       
       final response = await http.put(
          url,
          headers: {
             'Authorization': 'Bearer $token',
             'Content-Type': 'text/plain; charset=utf-8', 
          },
          body: content,
       );
       
       if (response.statusCode >= 200 && response.statusCode < 300) {
           debugPrint('GraphAuthService: Uploaded $filename successfully.');
           return true;
       }
       debugPrint('GraphAuthService: Upload failed: ${response.statusCode} ${response.body}');
       return false;
    } catch (e) {
       debugPrint('GraphAuthService: Upload error: $e');
       return false;
    }
  }

  /// Renames a file on OneDrive.
  /// [itemId] is the file ID.
  /// [newName] is the new filename (with extension).
  Future<bool> renameItem({
      required String accountId,
      required String itemId,
      required String newName,
  }) async {
      try {
          final token = await getFreshAccessToken(accountId);
          final url = Uri.parse('$graphBaseUrl/me/drive/items/$itemId');
          
          final response = await http.patch(
              url,
              headers: {
                 'Authorization': 'Bearer $token',
                 'Content-Type': 'application/json',
              },
              body: jsonEncode({'name': newName}),
          );
          
          if (response.statusCode >= 200 && response.statusCode < 300) {
              debugPrint('GraphAuthService: Renamed item $itemId to $newName');
              return true;
          }
          debugPrint('GraphAuthService: Rename failed: ${response.statusCode} ${response.body}');
          return false;
      } catch (e) {
          debugPrint('GraphAuthService: Rename error: $e');
          return false;
      }
  }
}
