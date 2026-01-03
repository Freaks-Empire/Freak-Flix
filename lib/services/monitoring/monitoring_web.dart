import 'package:flutter/widgets.dart';

class MonitoringService {
  static Future<void> initialize() async {
    debugPrint('Monitoring (Web): Logic disabled/no-op.');
  }

  static void recordError(dynamic error, StackTrace? stack) {
    debugPrint('Monitoring (Web): Error recorded: $error');
  }

  static NavigatorObserver get navigationObserver => NavigatorObserver();
}
