import 'package:flutter/foundation.dart';
import '../services/sync_service.dart';
import '../services/graph_auth_service.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';
import 'library_provider.dart';

class SyncProvider extends ChangeNotifier {
  final AuthProvider auth;
  final SettingsProvider settings;
  final LibraryProvider library;
  late final SyncService _service;

  bool _isSyncing = false;
  String? _lastError;
  DateTime? _lastSyncTime;

  bool get isSyncing => _isSyncing;
  String? get lastError => _lastError;
  DateTime? get lastSyncTime => _lastSyncTime;

  SyncProvider({
    required this.auth,
    required this.settings,
    required this.library,
  }) {
    // Inject ID Token getter
    _service = SyncService(getAccessToken: () => auth.getIdToken());

    // Listen to changes to trigger PUSH
    settings.addListener(_onSettingsChanged);
    GraphAuthService.instance.onStateChanged = _onGraphChanged;
    // library.addListener(_onLibraryChanged); // Library changes often during scan, careful.
    // Ideally we only sync library LIST changes, not scan progress. 
    // LibraryProvider doesn't have granular notifications yet. 
    // Let's hook into relevant methods or just manual sync for library mainly?
    // User wants "settings" sync. 
    // Let's expose a way for LibraryProvider to notify "config changed".
    // For now, we can rely on manual or app start, OR check for specific changes?
    // Actually, GraphService notifies on account changes. 
    // We can add a specialized listener or just debounce pushes?
    library.onConfigChanged.listen((_) => pushSync());
    
    // Listen to Auth for initial PULL
    auth.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (auth.isAuthenticated && _lastSyncTime == null) {
      pullSync();
    }
  }

  void _onSettingsChanged() {
    // Debounce?
    pushSync();
  }

  void _onGraphChanged() {
    pushSync();
  }

  Future<void> pushSync() async {
    if (!auth.isAuthenticated) return;
    if (_isSyncing) return; // Basic mutex

    // Don't show "syncing" UI for background pushes to avoid flicker? 
    // Or do show small indicator?
    // Let's just do background work, maybe setting a "saving" flag if really needed.
    // _isSyncing = true; notifyListeners(); 

    try {
      final data = {
        'settings': settings.exportSettings(),
        'graph': GraphAuthService.instance.exportState(),
        'library': library.exportState(),
      };
      await _service.pushData(data);
      _lastSyncTime = DateTime.now();
      _lastError = null;
    } catch (e) {
      _lastError = e.toString();
    } finally {
      // _isSyncing = false; notifyListeners();
    }
  }

  Future<void> pullSync() async {
    if (!auth.isAuthenticated) return;
    
    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final data = await _service.pullData();
      if (data != null) {
        if (data['settings'] != null) {
          await settings.importSettings(data['settings']);
        }
        if (data['graph'] != null) {
          await GraphAuthService.instance.importState(data['graph']);
        }
        if (data['library'] != null) {
          await library.importState(data['library']);
        }
      }
      _lastSyncTime = DateTime.now();
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  // Manual trigger
  Future<void> forceSync() async {
    await pullSync(); 
    await pushSync();
  }
}
