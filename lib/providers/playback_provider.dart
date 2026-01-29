/// lib/providers/playback_provider.dart
import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../models/user_profile.dart'; // Ensure import
import 'library_provider.dart';
import 'profile_provider.dart';

class PlaybackProvider extends ChangeNotifier {
  final LibraryProvider library;
  final ProfileProvider profileProvider; // Injected
  
  MediaItem? current;
  int positionSeconds = 0;

  PlaybackProvider(this.library, this.profileProvider);

  void start(MediaItem item) {
    current = item;
    // Get latest user data if available?
    // Item passing in 'start' is usually from the UI, so it should be the enriched one.
    // Double check:
    final userData = profileProvider.getDataFor(item.id);
    if (userData != null) {
        positionSeconds = userData.positionSeconds;
    } else {
        positionSeconds = item.lastPositionSeconds;
    }
    notifyListeners();
  }

  void updateProgress(MediaItem item, int seconds) {
    if (current == null || current!.id != item.id) {
       // If tracking a different item, switch to it?
       current = item;
    }
    positionSeconds = seconds;
    
    // Persist to Profile
    profileProvider.updateProgress(item.id, seconds);
    notifyListeners();
  }

  void markWatched() {
    if (current == null) return;
    
    profileProvider.updateProgress(current!.id, 0, isWatched: true);
    notifyListeners();
  }

  void setDuration(int totalSeconds) {
    if (current == null) return;
    
    // Duration is global metadata, save to Library
    final updated = current!.copyWith(totalDurationSeconds: totalSeconds);
    // Use library public method to update item in backing store
    library.updateItem(updated); 
    
    current = updated;
    notifyListeners();
  }
}
