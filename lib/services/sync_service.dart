import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  FirebaseFirestore? _db;
  StreamSubscription? _subscription;
  String? _userId;
  
  // Callback when external changes happen
  Function(Map<String, dynamic>)? onRemoteUpdate;

  /// Initialize the sync service with a user ID.
  /// [onUpdate] is called when a remote change is detected.
  void init(String userId, Function(Map<String, dynamic>) onUpdate) {
    if (_userId == userId) return; // Already init for this user
    
    // Firestore desktop plugins are unstable on Windows; skip to avoid platform thread violations
    if (!kIsWeb && Platform.isWindows) {
      debugPrint('SyncService: Firestore disabled on Windows (desktop not supported).');
      _db = null;
      return;
    }

    _userId = userId;
    onRemoteUpdate = onUpdate;
    
    // Only use Firestore on supported platforms (Web, Mobile, Desktop if configured)
    // We assume Firebase.initializeApp() was called in main.dart
    try {
      _db = FirebaseFirestore.instance;
      _listen();
    } catch (e) {
      debugPrint('SyncService: Failed to init Firestore: $e');
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _userId = null;
  }

  void _listen() {
    if (_db == null || _userId == null) return;
    
    _subscription?.cancel();
    _subscription = _db!.collection('users').doc(_userId).snapshots().listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null && !snapshot.metadata.hasPendingWrites) {
        // This is a remote update (hasPendingWrites is false)
        debugPrint('SyncService: Received remote update.');
        if (onRemoteUpdate != null) {
           onRemoteUpdate!(snapshot.data()!);
        }
      }
    }, onError: (e) => debugPrint('SyncService Listen Error: $e'));
  }

  /// Push local changes to the cloud (Last-Write-Wins)
  Future<void> pushUpdate(Map<String, dynamic> data) async {
    if (_db == null || _userId == null) {
      // debugPrint('SyncService: Push ignored (Not active)');
      return;
    }
    try {
      final payload = Map<String, dynamic>.from(data);
      // Add metadata
      payload['updatedAt'] = FieldValue.serverTimestamp();
      payload['platform'] = kIsWeb ? 'web' : Platform.operatingSystem;

      await _db!.collection('users').doc(_userId).set(
        payload, 
        SetOptions(merge: true)
      );
      debugPrint('SyncService: Pushed update to Firestore.');
    } catch (e) {
      debugPrint('SyncService Push Error: $e');
    }
  }

  /// Create a "Save Point" (Backup)
  Future<void> createSnapshot(Map<String, dynamic> data, String deviceName) async {
    if (_db == null || _userId == null) throw Exception('Sync not active');
    
    final payload = Map<String, dynamic>.from(data);
    
    await _db!.collection('users').doc(_userId).collection('backups').add({
      'data': payload,
      'savedAt': FieldValue.serverTimestamp(),
      'deviceName': deviceName,
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
    });
  }
  
  /// Get list of available backups
  Stream<List<Map<String, dynamic>>> getSnapshots() {
     if (_db == null || _userId == null) return const Stream.empty();
     
     return _db!.collection('users').doc(_userId).collection('backups')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map((d) {
             final data = d.data();
             data['id'] = d.id;
             // Handle Timestamp to String for UI if needed, usually UI handles DateTime
             // Firestore Timestamp needs conversion
             return data;
        }).toList());
  }
  
  /// helper to convert Timestamp to DateTime
  static DateTime? parseTimestamp(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    return null;
  }
  
  /// Restore a snapshot (Fetch & Push)
  /// Returns the data map so the app can apply it locally.
  Future<Map<String, dynamic>?> fetchSnapshot(String snapshotId) async {
      if (_db == null || _userId == null) return null;
      
      final doc = await _db!.collection('users').doc(_userId).collection('backups').doc(snapshotId).get();
      if (doc.exists) {
          final data = doc.data();
          if (data != null && data['data'] != null) {
              final content = data['data'] as Map<String, dynamic>;
              // Also auto-push to live?
              // The usage pattern: App gets data -> App applies -> App calls pushUpdate.
              return content;
          }
      }
      return null;
  }
}
