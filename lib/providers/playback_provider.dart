import 'dart:io';
import 'package:flutter/material.dart';
import '../models/media_item.dart';
import 'library_provider.dart';

class PlaybackProvider extends ChangeNotifier {
  final LibraryProvider library;
  MediaItem? current;
  int positionSeconds = 0;

  PlaybackProvider(this.library);

  void start(MediaItem item) {
    current = item;
    positionSeconds = item.lastPositionSeconds;
    notifyListeners();
  }

  void updatePosition(int seconds) {
    if (current == null) return;
    positionSeconds = seconds;
    final updated = current!.copyWith(lastPositionSeconds: seconds);
    _replace(updated);
    notifyListeners();
  }

  void markWatched() {
    if (current == null) return;
    final updated = current!.copyWith(isWatched: true, lastPositionSeconds: 0);
    _replace(updated);
    notifyListeners();
  }

  void setDuration(int totalSeconds) {
    if (current == null) return;
    final updated = current!.copyWith(totalDurationSeconds: totalSeconds);
    _replace(updated);
    notifyListeners();
  }

  void _replace(MediaItem updated) {
    final idx = library.items.indexWhere((i) => i.filePath == updated.filePath);
    if (idx >= 0) {
      library.items[idx] = updated;
      current = updated;
      library.saveLibrary();
    }
  }

  File? get currentFile => current == null ? null : File(current!.filePath);
}