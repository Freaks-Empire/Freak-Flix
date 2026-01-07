import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Log when a user opens a movie
  Future<void> logMovieView(String movieId, String movieTitle) async {
    await _analytics.logEvent(
      name: 'view_movie',
      parameters: {
        'id': movieId,
        'title': movieTitle,
      },
    );
  }

  // Log when a user plays a video
  Future<void> logVideoStart(String movieTitle) async {
    await _analytics.logEvent(
      name: 'video_start',
      parameters: {
        'title': movieTitle,
      },
    );
  }

  // Log searches
  Future<void> logSearch(String query) async {
    await _analytics.logSearch(searchTerm: query);
  }
}
