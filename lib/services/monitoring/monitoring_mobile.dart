import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:newrelic_mobile/newrelic_mobile.dart';
import 'package:newrelic_mobile/newrelic_navigation_observer.dart';

class MonitoringService {
  static Future<void> initialize() async {
     try {
       // user-provided token for Android
       // user-provided token for Android
       /*
       final appToken = Platform.isAndroid 
          ? 'AAe36c031e01ebd715ca9d0c974005c41972f9a812-NRMA' 
          : 'YOUR_IOS_TOKEN_HERE';

       Config config = Config(
          accessToken: appToken,
          analyticsEventEnabled: true,
          networkErrorRequestEnabled: true,
          networkRequestEnabled: true,
          crashReportingEnabled: true,
          interactionTracingEnabled: true,
          httpResponseBodyCaptureEnabled: true,
          loggingEnabled: true,
          webViewInstrumentation: true,
          printStatementAsEventsEnabled: true,
          httpInstrumentationEnabled:true
       );

       FlutterError.onError = NewrelicMobile.onError;
       await NewrelicMobile.instance.startAgent(config);
       debugPrint('Monitoring (Mobile): New Relic started.');
       */
       debugPrint('Monitoring (Mobile): New Relic disabled for Windows verify.');
     } catch (e) {
       debugPrint('Monitoring (Mobile): Init failed: $e');
     }
  }

  static void recordError(dynamic error, StackTrace? stack) {
    NewrelicMobile.instance.recordError(error, stack);
  }

  static NavigatorObserver get navigationObserver => NewRelicNavigationObserver();
}
