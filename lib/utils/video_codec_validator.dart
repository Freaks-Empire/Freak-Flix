/// lib/utils/video_codec_validator.dart
/// 
/// Video codec validation and fallback handling
/// Ensures video files are compatible with player

import 'dart:io';
import '../utils/secure_logger.dart';

enum VideoCodec {
  h264,
  h265,
  vp9,
  av1,
  mpeg2,
  mpeg4,
  hevc,
  avc,
  unknown,
}

enum VideoContainer {
  mp4,
  mkv,
  avi,
  mov,
  webm,
  flv,
  unknown,
}

class CodecValidationResult {
  final bool isValid;
  final VideoCodec codec;
  final VideoContainer container;
  final String? error;
  final List<String> warnings;

  const CodecValidationResult({
    required this.isValid,
    required this.codec,
    required this.container,
    this.error,
    this.warnings = const [],
  });
}

/// Video codec validation utility
class VideoCodecValidator {
  /// Supported codec priority (higher = better)
  static const List<VideoCodec> codecPriority = [
    VideoCodec.h265,  // Best efficiency
    VideoCodec.hevc,   // Good efficiency  
    VideoCodec.vp9,    // Open source, good efficiency
    VideoCodec.av1,     // Modern, efficient
    VideoCodec.h264,    // Widely compatible
    VideoCodec.avc,    // Legacy but compatible
  ];

  /// Supported containers with compatibility notes
  static const Map<VideoContainer, String> containerInfo = {
    VideoContainer.mp4: 'MP4 - Widely compatible',
    VideoContainer.mkv: 'MKV - Open source friendly',
    VideoContainer.webm: 'WebM - Web optimized',
    VideoContainer.mov: 'MOV - Apple compatible',
    VideoContainer.avi: 'AVI - Legacy format',
    VideoContainer.flv: 'FLV - Flash video',
  };

  /// Extract codec from file extension
  static VideoCodec extractCodecFromFile(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    
      switch (extension) {
      case 'mp4':
      case 'mov':
      case 'm4v':
        return VideoCodec.h264; // Most common
      case 'webm':
        return VideoCodec.vp9; // WebM typically VP9
      case 'mkv':
        return VideoCodec.h265; // MKV often uses H.265
      case 'avi':
        return VideoCodec.mpeg4; // Legacy
      case 'flv':
        return VideoCodec.mpeg4; // Legacy (corrected from h263)
      default:
        return VideoCodec.unknown;
      }
      default:
        return VideoCodec.unknown;
    }
  }

  /// Extract container from file extension
  static VideoContainer extractContainer(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'mp4':
        return VideoContainer.mp4;
      case 'mkv':
        return VideoContainer.mkv;
      case 'avi':
        return VideoContainer.avi;
      case 'mov':
        return VideoContainer.mov;
      case 'webm':
        return VideoContainer.webm;
      case 'flv':
        return VideoContainer.flv;
      default:
        return VideoContainer.unknown;
    }
  }

  /// Validate video file for codec support
  static CodecValidationResult validateVideoFile(String filePath) {
    final codec = extractCodecFromFile(filePath);
    final container = extractContainer(filePath);
    final warnings = <String>[];
    String? error;

    // Check if codec is supported
    if (codec == VideoCodec.unknown) {
      error = 'Unknown video codec detected';
      return CodecValidationResult(
        isValid: false,
        codec: codec,
        container: container,
        error: error,
        warnings: warnings,
      );
    }

    // Check if container is supported
    if (container == VideoContainer.unknown) {
      warnings.add('Unknown container format: ${container.toString()}');
    }

    // Check codec compatibility warnings
    if (codecPriority.indexOf(codec) > 3) {
      warnings.add('Codec ${codec.toString()} may have limited hardware support');
    }

    // Check for legacy formats
    if (codec == VideoCodec.mpeg2 || codec == VideoCodec.mpeg4) {
      warnings.add('Legacy codec detected - may have performance issues');
    }

    // Additional checks based on file size
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final fileSize = await file.length();
        final fileSizeMB = fileSize / (1024 * 1024);
        
        if (fileSizeMB > 2048) { // 2GB
          warnings.add('Large file detected - may have playback issues');
        }
        
        if (fileSizeMB > 8192) { // 8GB
          error = 'File too large for stable playback (>8GB)';
          return CodecValidationResult(
            isValid: false,
            codec: codec,
            container: container,
            error: error,
            warnings: warnings,
          );
        }
      }
    } catch (e) {
      SecureLogger.error('Error validating video file', e, 'CodecValidator');
      warnings.add('File validation error: $e');
    }

    return CodecValidationResult(
      isValid: error == null,
      codec: codec,
      container: container,
      error: error,
      warnings: warnings,
    );
  }

  /// Get recommended player settings based on codec
  static Map<String, dynamic> getRecommendedSettings(VideoCodec codec) {
    switch (codec) {
      case VideoCodec.h265:
      case VideoCodec.hevc:
        return {
          'hardware_acceleration': 'preferred',
          'buffer_size': 'large',
          'decoder_priority': 'high',
        };
      case VideoCodec.vp9:
      case VideoCodec.av1:
        return {
          'hardware_acceleration': 'supported',
          'buffer_size': 'medium',
          'decoder_priority': 'medium',
        };
      case VideoCodec.h264:
      case VideoCodec.avc:
        return {
          'hardware_acceleration': 'universal',
          'buffer_size': 'small',
          'decoder_priority': 'low',
        };
      default:
        return {
          'hardware_acceleration': 'unknown',
          'buffer_size': 'medium',
          'decoder_priority': 'medium',
        };
    }
  }

  /// Get human-readable codec name
  static String getCodecName(VideoCodec codec) {
    switch (codec) {
      case VideoCodec.h264:
        return 'H.264';
      case VideoCodec.h265:
        return 'H.265';
      case VideoCodec.vp9:
        return 'VP9';
      case VideoCodec.av1:
        return 'AV1';
      case VideoCodec.hevc:
        return 'HEVC';
      case VideoCodec.avc:
        return 'AVC';
      default:
        return 'Unknown';
    }
  }

  /// Get human-readable container name
  static String getContainerName(VideoContainer container) {
    switch (container) {
      case VideoContainer.mp4:
        return 'MP4';
      case VideoContainer.mkv:
        return 'MKV';
      case VideoContainer.avi:
        return 'AVI';
      case VideoContainer.mov:
        return 'MOV';
      case VideoContainer.webm:
        return 'WebM';
      case VideoContainer.flv:
        return 'FLV';
      default:
        return 'Unknown';
    }
  }
}