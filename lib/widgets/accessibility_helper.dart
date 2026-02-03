/// lib/widgets/accessibility_helper.dart
/// 
/// Accessibility helper widgets and utilities
/// Ensures compliance with screen readers and improves user experience

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

class AccessibilityHelper {
  /// Check if screen reader is likely enabled
  static bool isScreenReaderEnabled() {
    return WidgetsBinding.instance.window.accessibilityEnabled;
  }

  /// Get high contrast colors for better visibility
  static Map<String, Color> getHighContrastColors() {
    return {
      'background': Colors.black,
      'primary': Colors.white,
      'accent': const Color(0xFFE50914), // Netflix red
      'success': Colors.green,
      'warning': Colors.orange,
      'error': Colors.red[400],
      'text_primary': Colors.white,
      'text_secondary': Colors.grey[300],
    };
  }

  /// Generate semantic labels for better screen reader support
  static Map<String, String> getSemanticLabels() {
    return {
      'play_button': 'Play video',
      'pause_button': 'Pause video',
      'progress_bar': 'Video progress',
      'volume_slider': 'Volume control',
      'fullscreen_button': 'Toggle fullscreen',
      'settings_button': 'Video settings',
      'next_episode': 'Next episode',
      'previous_episode': 'Previous episode',
      'quality_indicator': 'Connection quality',
    };
  }

  /// Wrap widget with accessibility properties
  static Widget wrapWithAccessibility({
    required Widget child,
    String? semanticLabel,
    Map<String, String>? semanticProperties,
    bool isFocusable = true,
    bool excludeFromSemantics = false,
  }) {
    final colors = getHighContrastColors();
    
    return Semantics(
      label: semanticLabel,
      properties: semanticProperties ?? {},
      child: Focus(
        canRequestFocus: isFocusable,
        excludeFromSemantics: excludeFromSemantics,
        child: Container(
          decoration: BoxDecoration(
            color: colors['background'],
            borderRadius: BorderRadius.circular(8),
            border: isFocusable 
                ? Border.all(color: colors['accent'])
                : null,
          ),
          child: child,
        ),
      ),
    );
  }

  /// Add screen reader announcements for important actions
  static void announceForScreenReader(BuildContext context, String message) {
    if (isScreenReaderEnabled()) {
      SemanticsService.announce(context, message);
    }
  }

  /// Check if high contrast mode should be enabled
  static bool shouldUseHighContrast(BuildContext context) {
    // Check system settings or user preference
    return MediaQuery.of(context).highContrast ?? false;
  }

  /// Get accessible color based on contrast preferences
  static Color getAdaptiveColor(BuildContext context, Color defaultColor) {
    final useHighContrast = shouldUseHighContrast(context);
    final colors = getHighContrastColors();
    
    if (useHighContrast) {
      return colors['primary'];
    } else {
      return defaultColor;
    }
  }
}