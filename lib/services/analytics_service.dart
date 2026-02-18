/// lib/services/analytics_service.dart
/// Analytics service (Firebase removed - now a no-op stub)

import 'dart:io';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  AnalyticsService() {
    debugPrint('AnalyticsService: Firebase Analytics removed - analytics disabled');
  }

  // Log when a user opens a movie (no-op)
  Future<void> logMovieView(String movieId, String movieTitle) async {
    // Firebase removed - analytics disabled
  }

  // Log when a user plays a video (no-op)
  Future<void> logVideoStart(String movieTitle) async {
    // Firebase removed - analytics disabled
  }

  // Log searches (no-op)
  Future<void> logSearch(String query) async {
    // Firebase removed - analytics disabled
  }
}
