import 'dart:async';
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
  bool _pendingPush = false; // Queue a push if one happens while syncing
  String? _lastError;
  DateTime? _lastSyncTime;

  bool get isSyncing => _isSyncing;
  String? get lastError => _lastError;
  DateTime? get lastSyncTime => _lastSyncTime;
  
  // Simple heuristic: do we have ANY data locally that might need pushing?
  bool get _hasLocalData => 
      library.libraryFolders.isNotEmpty 
      || settings.tmdbApiKey.isNotEmpty
      || library.items.isNotEmpty; // check items just in case

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
    // Listen to Auth for initial PULL and background sync management
    auth.addListener(_onAuthChanged);
    
    // Check initial state
    if (auth.isAuthenticated) {
      _onAuthChanged();
    }
  }

  Timer? _pollingTimer;

  void _onAuthChanged() {
    if (auth.isAuthenticated) {
      // SMART INIT:
      // If we have local data, assume we want to KEEP it and push it (e.g. offline changes).
      // If we have NOTHING, assume it's a fresh install/login and we want to PULL.
      if (_lastSyncTime == null) {
        if (_hasLocalData) {
          debugPrint('SyncProvider: Local data detected. Pushing to cloud.');
          pushSync();
        } else {
          debugPrint('SyncProvider: No local data. Pulling from cloud (Restore).');
          pullSync();
        }
      }
      _startPolling();
    } else {
      _stopPolling();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      pullSync();
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  void dispose() {
    _stopPolling();
    settings.removeListener(_onSettingsChanged);
    auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    // Debounce?
    pushSync();
  }

  void _onGraphChanged() {
    pushSync();
  }

  Timer? _debounceTimer;

  Completer<void>? _pushCompleter;

  Future<void> pushSync() {
    if (!auth.isAuthenticated) return Future.value();
    
    // If we are already waiting for a push (debounce phase), reuse the completer.
    // If the previous one finished, create a new one.
    if (_pushCompleter == null || _pushCompleter!.isCompleted) {
      _pushCompleter = Completer<void>();
    }
    
    // Debounce to ensure multiple rapid changes (like deleting accounts + settings update)
    // are grouped into one solid push, and gives the UI/State time to settle.
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
       try {
         await _performPush();
       } finally {
         // Only complete if not already completed (though distinct completers prevent this usually)
         if (!(_pushCompleter?.isCompleted ?? true)) {
           _pushCompleter?.complete();
         }
       }
    });

    return _pushCompleter!.future;
  }

  Future<void> _performPush() async {
    if (!auth.isAuthenticated) return;

    // If already syncing, queue another push for immediately after 
    // so we don't lose the latest state.
    if (_isSyncing) {
      _pendingPush = true;
      return; 
    }

    _isSyncing = true;
    notifyListeners(); 

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
      _isSyncing = false;
      notifyListeners();
      _checkPendingPush();
    }
  }

  Future<void> pullSync() async {
    if (!auth.isAuthenticated) return;
    
    // If syncing, we can probably skip a background pull.
    // But if it was a push, maybe we want to pull after?
    // Let's protect broadly.
    if (_isSyncing) return;
    
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
      // If a push was requested while we were pulling, do it now.
      _checkPendingPush();
    }
  }
  
  void _checkPendingPush() {
    if (_pendingPush) {
      _pendingPush = false;
      // Schedule slightly later to unwind stack? No need, async is fine.
      pushSync();
    }
  }
  
  // Manual trigger
  Future<void> forceSync() async {
    // Always PUSH local state first so we don't lose it.
    await pushSync();
    
    // If push failed, DO NOT pull (to avoid overwriting local changes with stale cloud data).
    // The UI should show the error from pushSync.
    if (_lastError != null) {
      debugPrint('SyncProvider: Push failed with "$_lastError". Aborting Pull.');
      notifyListeners(); // Ensure UI sees error
      return;
    }
    
    // Then pull to get updates from other devices.
    await pullSync(); 
  }
}
