// Extracted from LibraryProvider — manages scan progress tracking,
// notifications, foreground tasks, and wakelock.
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../utils/platform/platform.dart';

String scanConstraintNote({
  required bool isWeb,
  required bool isIOS,
}) {
  if (isWeb) {
    return 'Background scan service is not available on Web yet. Keep this tab open while scanning.';
  }
  if (isIOS) {
    return 'Background scan notifications are limited on iOS.';
  }
  return '';
}

class ScanOrchestrationService extends ChangeNotifier {
  // ── Scan progress state ──────────────────────────────────────────────
  bool isScanning = false;
  int scannedCount = 0;
  int totalToScan = 0;
  String? currentScanSource;
  String? currentScanItem;
  String scanningStatus = '';
  String _platformConstraintNote = '';
  bool _cancelScanRequested = false;

  bool get cancelRequested => _cancelScanRequested;

  // ── Notifications ────────────────────────────────────────────────────
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool get _supportsWakelock => Platform.isAndroid || Platform.isIOS;
  bool get _supportsForegroundTask => Platform.isAndroid;
  bool get _supportsCompletionNotifications =>
      !Platform.isWeb && !Platform.isIOS;

  // ── Constructor ──────────────────────────────────────────────────────
  ScanOrchestrationService() {
    if (_supportsCompletionNotifications) {
      _initNotifications();
    }
    if (_supportsForegroundTask) {
      _initForegroundTask();
    }
  }

  // ── Scan lifecycle ───────────────────────────────────────────────────

  void beginScan({String? sourceLabel, int? total}) {
    isScanning = true;
    _cancelScanRequested = false;
    scannedCount = 0;
    totalToScan = total ?? 0;
    currentScanSource = sourceLabel;
    currentScanItem = null;
    _platformConstraintNote = scanConstraintNote(
      isWeb: Platform.isWeb,
      isIOS: Platform.isIOS,
    );

    if (_supportsWakelock) {
      WakelockPlus.enable();
      _requestNotificationPermission();
    }

    if (_supportsForegroundTask) {
      FlutterForegroundTask.startService(
        notificationTitle: 'Scanning Library',
        notificationText: 'Starting scan...',
      );
    }

    _updateScanningStatus();
    notifyListeners();
  }

  void reportScanProgress({
    int? scanned,
    int? total,
    String? currentItem,
    String? sourceLabel,
  }) {
    if (scanned != null) scannedCount = scanned;
    if (total != null) totalToScan = total;
    if (sourceLabel != null && sourceLabel.isNotEmpty) {
      currentScanSource = sourceLabel;
    }
    if (currentItem != null && currentItem.isNotEmpty) {
      currentScanItem = currentItem;
    }
    _updateScanningStatus();
    notifyListeners();
  }

  void finishScan() {
    isScanning = false;
    _cancelScanRequested = false;
    scannedCount = 0;
    totalToScan = 0;
    currentScanSource = null;
    currentScanItem = null;
    scanningStatus = '';
    _platformConstraintNote = '';

    if (_supportsWakelock) {
      WakelockPlus.disable();
    }

    if (_supportsForegroundTask) {
      FlutterForegroundTask.stopService();
    }

    if (_supportsCompletionNotifications) {
      _showCompletionNotification();
    }

    notifyListeners();
  }

  void requestCancelScan() {
    if (!isScanning) return;
    _cancelScanRequested = true;
    scanningStatus = 'Cancelling...';
    notifyListeners();
  }

  void setScanStatus(String message) {
    scanningStatus = message;
    notifyListeners();
  }

  // ── Internal helpers ─────────────────────────────────────────────────

  void _updateScanningStatus() {
    if (!isScanning) {
      scanningStatus = '';
      return;
    }

    final where = currentScanSource ?? '';
    final item = currentScanItem ?? '';
    String statusMsg = '';

    if (totalToScan > 0) {
      statusMsg =
          'Scanning $where ($scannedCount / $totalToScan)... ${item.isEmpty ? '' : item}';
    } else {
      statusMsg = 'Scanning $where... ${item.isEmpty ? '' : item}';
    }

    if (_platformConstraintNote.isNotEmpty) {
      statusMsg = '$statusMsg $_platformConstraintNote';
    }

    scanningStatus = statusMsg;

    if (_supportsForegroundTask) {
      FlutterForegroundTask.updateService(
        notificationTitle: 'Freak-Flix Scanning',
        notificationText: statusMsg,
      );
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (!Platform.isAndroid) {
      return;
    }

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  Future<void> _showCompletionNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'scan_complete_channel',
      'Scan Complete',
      channelDescription: 'Notifies when library scan is finished',
      importance: Importance.high,
      priority: Priority.high,
    );
    const linuxDetails = LinuxNotificationDetails(
      defaultActionName: 'Open',
    );
    const details = NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );
    await _notifications.show(
      0,
      'Scan Complete',
      'Library scan finished successfully.',
      details,
    );
  }

  Future<void> _initNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      linux: LinuxInitializationSettings(defaultActionName: 'Open'),
      macOS: iosSettings,
      windows: WindowsInitializationSettings(
          appName: 'Freak-Flix',
          appUserModelId: 'com.freakflix.app',
          guid: '81a3d53b-9e4b-48fb-9c9b-1e247470f7d5'),
    );

    await _notifications.initialize(initSettings);
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'scanning_channel',
        channelName: 'Library Scanning',
        channelDescription:
            'Shows progress when scanning library in background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }
}
