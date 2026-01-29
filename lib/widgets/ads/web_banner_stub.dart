/// lib/widgets/ads/web_banner_stub.dart
/// Stub for non-web platforms - ads not available.

import 'package:flutter/material.dart';

Widget buildBannerAd({double width = 728, double height = 90}) {
  return const SizedBox.shrink();
}

Future<void> showInterstitialAd(BuildContext context) async {
  // No ads on non-web platforms
}
