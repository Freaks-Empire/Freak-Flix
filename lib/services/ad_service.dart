/// lib/services/ad_service.dart
/// Service for managing ads for remote streaming.

import 'package:flutter/foundation.dart';

/// Service to manage ads for remote streaming.
/// 
/// Ads are shown before remote streaming content (every stream).
/// Local library content does NOT trigger ads.
/// 
/// Currently supports Android, iOS, and Web.
/// Windows is not supported for ads.
class AdService extends ChangeNotifier {
  static AdService? _instance;
  static AdService get instance => _instance ??= AdService._();
  
  AdService._();
  
  /// Test ad tag URL (replace with production URL in release)
  /// This is Google's sample VMAP Pre-roll ad tag
  static const String testAdTagUrl = 
      'https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/single_preroll_skippable&sz=640x480&ciu_szs=300x250%2C728x90&gdfp_req=1&output=vast&unviewed_position_start=1&env=vp&impl=s&correlator=';
  
  // TODO: Replace with your production ad tag URL
  static const String productionAdTagUrl = testAdTagUrl;
  
  /// Get the ad tag URL based on build mode
  String get adTagUrl => kReleaseMode ? productionAdTagUrl : testAdTagUrl;
  
  /// Whether ads are supported on this platform
  bool get isSupported {
    // Google IMA supports Android, iOS, and Web
    // Windows desktop is not supported by IMA
    return defaultTargetPlatform == TargetPlatform.android ||
           defaultTargetPlatform == TargetPlatform.iOS ||
           kIsWeb;
  }
  
  /// Whether we should attempt to show an ad.
  /// Returns false on unsupported platforms (Windows).
  bool shouldShowAd() {
    return isSupported;
  }
}
