import 'package:firebase_analytics/firebase_analytics.dart';

import 'dart:io';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  FirebaseAnalytics? _analytics;

  AnalyticsService() {
    // Only use Firebase Analytics on supported platforms where Firebase is initialized
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      try {
        _analytics = FirebaseAnalytics.instance;
      } catch (e) {
        debugPrint('AnalyticsService: Failed to get FirebaseAnalytics instance: $e');
      }
    }
  }

  // Log when a user opens a movie
  Future<void> logMovieView(String movieId, String movieTitle) async {
    if (_analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'view_movie',
        parameters: {
          'id': movieId,
          'title': movieTitle,
        },
      );
    } catch (_) {}
  }

  // Log when a user plays a video
  Future<void> logVideoStart(String movieTitle) async {
    if (_analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'video_start',
        parameters: {
          'title': movieTitle,
        },
      );
    } catch (_) {}
  }

  // Log searches
  Future<void> logSearch(String query) async {
    if (_analytics == null) return;
    try {
      await _analytics!.logSearch(searchTerm: query);
    } catch (_) {}
  }
}
