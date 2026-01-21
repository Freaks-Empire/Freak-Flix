import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

class VideoKeyboardListener extends StatelessWidget {
  final Widget child;
  final Player player;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onBack;

  const VideoKeyboardListener({
    super.key,
    required this.child,
    required this.player,
    required this.onToggleFullscreen,
    required this.onBack,
  });

  void _seek(int seconds) {
    // Current position
    final pos = player.state.position;
    final total = player.state.duration;
    
    // Calculate new position
    var newPos = pos + Duration(seconds: seconds);
    
    // Clamp
    if (newPos < Duration.zero) newPos = Duration.zero;
    if (newPos > total) newPos = total;
    
    player.seek(newPos);
  }

  void _changeVolume(double delta) {
    final newVol = (player.state.volume + delta).clamp(0.0, 100.0);
    player.setVolume(newVol);
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      autofocus: true,
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.space): const PlayPauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyK): const PlayPauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const SeekForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyL): const SeekForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const SeekBackwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyJ): const SeekBackwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const VolumeUpIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const VolumeDownIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyM): const MuteIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyF): const FullscreenIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const BackIntent(),
      },
      actions: {
        PlayPauseIntent: CallbackAction<PlayPauseIntent>(onInvoke: (_) => player.playOrPause()),
        SeekForwardIntent: CallbackAction<SeekForwardIntent>(onInvoke: (_) => _seek(10)),
        SeekBackwardIntent: CallbackAction<SeekBackwardIntent>(onInvoke: (_) => _seek(-10)),
        VolumeUpIntent: CallbackAction<VolumeUpIntent>(onInvoke: (_) => _changeVolume(10)),
        VolumeDownIntent: CallbackAction<VolumeDownIntent>(onInvoke: (_) => _changeVolume(-10)),
        MuteIntent: CallbackAction<MuteIntent>(onInvoke: (_) => player.setVolume(player.state.volume == 0 ? 100 : 0)),
        FullscreenIntent: CallbackAction<FullscreenIntent>(onInvoke: (_) => onToggleFullscreen()),
        BackIntent: CallbackAction<BackIntent>(onInvoke: (_) => onBack()),
      },
      child: child,
    );
  }
}

// Intents
class PlayPauseIntent extends Intent { const PlayPauseIntent(); }
class SeekForwardIntent extends Intent { const SeekForwardIntent(); }
class SeekBackwardIntent extends Intent { const SeekBackwardIntent(); }
class VolumeUpIntent extends Intent { const VolumeUpIntent(); }
class VolumeDownIntent extends Intent { const VolumeDownIntent(); }
class MuteIntent extends Intent { const MuteIntent(); }
class FullscreenIntent extends Intent { const FullscreenIntent(); }
class BackIntent extends Intent { const BackIntent(); }
