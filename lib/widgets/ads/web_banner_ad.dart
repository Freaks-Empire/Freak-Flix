/// lib/widgets/ads/web_banner_ad.dart
/// Web-specific banner ad widget using Adsterra

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

// Conditional import for web
import 'web_banner_stub.dart'
    if (dart.library.html) 'web_banner_impl.dart' as platform;

/// A banner ad widget that only shows on web platform.
/// Uses Adsterra banner ads.
class WebBannerAd extends StatelessWidget {
  final double width;
  final double height;
  
  const WebBannerAd({
    Key? key,
    this.width = 728,
    this.height = 90,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }
    
    return platform.buildBannerAd(width: width, height: height);
  }
}

/// Shows an interstitial ad (full-screen overlay).
/// Returns a Future that completes when the ad is closed.
Future<void> showInterstitialAd(BuildContext context) async {
  if (!kIsWeb) return;
  
  return platform.showInterstitialAd(context);
}
