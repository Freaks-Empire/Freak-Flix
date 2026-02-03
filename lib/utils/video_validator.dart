/// lib/utils/video_validator.dart
/// 
/// Simple video validation utilities
/// Basic codec and format checking for video files

import '../utils/secure_logger.dart';

class SimpleVideoValidator {
  /// Check if video file extension is supported
  static bool isSupportedVideo(String filePath) {
    if (filePath.isEmpty) return false;
    
    final extension = filePath.split('.').last.toLowerCase();
    const supportedExtensions = ['mp4', 'mkv', 'avi', 'mov', 'webm', 'flv'];
    
    return supportedExtensions.contains(extension);
  }

  /// Get basic codec info from file extension
  static String getCodecInfo(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'mp4':
      case 'mov':
      case 'm4v':
        return 'H.264 (MP4)';
      case 'webm':
        return 'VP9 (WebM)';
      case 'mkv':
        return 'H.265/VP9 (MKV)';
      case 'avi':
        return 'MPEG-4 (AVI)';
      case 'flv':
        return 'H.263 (FLV)';
      default:
        return 'Unknown';
    }
  }

  /// Validate video file and return basic info
  static Map<String, dynamic> validateVideo(String filePath) {
    final isSupported = isSupportedVideo(filePath);
    final result = {
      'is_supported': isSupported,
      'codec_info': getCodecInfo(filePath),
      'file_extension': filePath.split('.').last.toLowerCase(),
    };
    
    if (!isSupported) {
      SecureLogger.warning('Unsupported video format: ${result['file_extension']}', 'VideoValidator');
    }
    
    return result;
  }
}