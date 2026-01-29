/// lib/widgets/ads/web_banner_impl.dart
/// Web-specific implementation for Adsterra banner and interstitial ads.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';

// Unique IDs for ad elements
int _adCounter = 0;

/// Builds a banner ad widget for web using Adsterra.
Widget buildBannerAd({double width = 728, double height = 90}) {
  final viewId = 'adsterra-banner-${_adCounter++}';
  
  // Register the HTML element
  // ignore: undefined_prefixed_name
  ui.platformViewRegistry.registerViewFactory(viewId, (int id) {
    final container = html.DivElement()
      ..id = 'ad-container-$id'
      ..style.width = '${width}px'
      ..style.height = '${height}px'
      ..style.display = 'flex'
      ..style.justifyContent = 'center'
      ..style.alignItems = 'center'
      ..style.backgroundColor = '#1a1a1a'
      ..style.borderRadius = '8px'
      ..style.overflow = 'hidden';
    
    // Add Adsterra banner script
    // Note: Replace with your actual Adsterra banner code
    final script = html.ScriptElement()
      ..async = true
      ..setAttribute('data-cfasync', 'false')
      ..src = 'https://beastlyfluke.com/5c/08/34/5c0834ad84875b096cd1fd0bd78dda98.js';
    
    // Fallback content if ad doesn't load
    final fallback = html.DivElement()
      ..style.color = '#666'
      ..style.fontSize = '12px'
      ..style.textAlign = 'center'
      ..innerText = 'Advertisement';
    
    container.append(fallback);
    container.append(script);
    
    return container;
  });
  
  return SizedBox(
    width: width,
    height: height,
    child: HtmlElementView(viewType: viewId),
  );
}

/// Shows an interstitial ad as a full-screen overlay.
Future<void> showInterstitialAd(BuildContext context) async {
  final completer = Completer<void>();
  
  // Create overlay
  OverlayEntry? overlayEntry;
  
  overlayEntry = OverlayEntry(
    builder: (context) => Material(
      color: Colors.black87,
      child: SafeArea(
        child: Stack(
          children: [
            // Ad content area
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.7,
                decoration: BoxDecoration(
                  color: const Color(0xFF1a1a1a),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  children: [
                    // Header with close button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.white12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Sponsored',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          _InterstitialCloseButton(
                            onClose: () {
                              overlayEntry?.remove();
                              completer.complete();
                            },
                          ),
                        ],
                      ),
                    ),
                    // Ad content
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.celebration,
                              size: 64,
                              color: Colors.amber.withOpacity(0.7),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'OneDrive Connected!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Thank you for using Freak Flix',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 32),
                            // Placeholder for actual ad
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '📢 Advertisement Space',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  
  Overlay.of(context).insert(overlayEntry);
  
  return completer.future;
}

/// Close button with countdown timer.
class _InterstitialCloseButton extends StatefulWidget {
  final VoidCallback onClose;
  
  const _InterstitialCloseButton({required this.onClose});
  
  @override
  State<_InterstitialCloseButton> createState() => _InterstitialCloseButtonState();
}

class _InterstitialCloseButtonState extends State<_InterstitialCloseButton> {
  int _countdown = 3;
  Timer? _timer;
  
  @override
  void initState() {
    super.initState();
    _startCountdown();
  }
  
  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (_countdown > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Close in $_countdown',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      );
    }
    
    return TextButton.icon(
      onPressed: widget.onClose,
      icon: const Icon(Icons.close, size: 16, color: Colors.white70),
      label: const Text('Close', style: TextStyle(color: Colors.white70)),
      style: TextButton.styleFrom(
        backgroundColor: Colors.white10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
