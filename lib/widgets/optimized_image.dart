/// lib/widgets/optimized_image.dart
/// 
/// Optimized image loading with caching and performance improvements
/// Reduces memory usage and improves loading performance

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final BoxFit fit;
  final Duration fadeInDuration;
  final bool enableMemoryOptimization;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.placeholder,
    this.fit = BoxFit.cover,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.enableMemoryOptimization = true,
  });

  @override
  Widget build(BuildContext context) {
    // For large images, use memory-optimized loading
    if (enableMemoryOptimization && _isLargeImage()) {
      return _buildMemoryOptimizedImage();
    }

    // For smaller images, use standard cached network image
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      placeholder: placeholder,
      fit: fit,
      fadeInDuration: fadeInDuration,
      // Basic optimizations
      filterQuality: FilterQuality.low,
      errorWidget: _buildErrorWidget(),
      progressIndicatorBuilder: (context, url, progress) => 
        _buildProgressIndicator(progress),
    );
  }

  /// Check if image is large enough to need memory optimization
  bool _isLargeImage() {
    // Consider images larger than 1MB as large
    return _estimatedImageSize() > 1024 * 1024;
  }

  /// Estimate image size from URL (rough estimation)
  int _estimatedImageSize() {
    // Basic estimation based on URL patterns
    if (imageUrl.contains('high') || imageUrl.contains('large') || 
        imageUrl.contains('original') || imageUrl.contains('hd')) {
      return 2 * 1024 * 1024; // Assume 2MB for HD content
    }
    
    if (imageUrl.contains('thumb') || imageUrl.contains('small') ||
        imageUrl.contains('poster')) {
      return 200 * 1024; // 200KB for thumbnails
    }
    
    return 512 * 1024; // Default to 512KB
  }

  /// Calculate optimal cache size based on device memory
  int _calculateOptimalCacheSize() {
    // Default cache size, could be made more sophisticated
    return (width ?? 300) * (height ?? 300) ~/ 4; // Quarter of image size
  }

  /// Get device-optimal width
  double _getDeviceOptimalWidth() {
      // Limit based on typical device capabilities
    final deviceWidth = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.width;
    final deviceHeight = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.height;
    return deviceWidth.clamp(200.0, 800.0);
  }

  /// Get device-optimal height  
  double _getDeviceOptimalHeight() {
    return deviceHeight.clamp(200.0, 600.0);
  }

  /// Generate cache key for optimized caching
  String _generateCacheKey() {
    return 'img_${width}x${height}_${imageUrl.hashCode}';
  }

  /// Simple memory-optimized image
  Widget _buildMemoryOptimizedImage() {
    return ClipRRect(
      child: Image.network(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        },
        errorBuilder: (context, error, stackTrace) => 
          _buildErrorWidget(),
      ),
    );
  }

  /// Custom error widget for better UX
  Widget _buildErrorWidget() {
    return Container(
      width: width ?? 100,
      height: height ?? 100,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.broken_image,
        color: Colors.grey[600],
        size: 32,
      ),
    );
  }

  /// Custom progress indicator for better loading feedback
  Widget _buildProgressIndicator(double progress) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 4,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: Colors.blue[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Extension for easier usage
extension OptimizedImageExtensions on Widget {
  /// Wrap a widget with optimized image loading
  Widget withOptimizedImage({
    required String imageUrl,
    double? width,
    double? height,
    Widget? placeholder,
    BoxFit fit = BoxFit.cover,
    Duration fadeInDuration = const Duration(milliseconds: 300),
  }) {
    return OptimizedImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      placeholder: placeholder,
      fit: fit,
      fadeInDuration: fadeInDuration,
    );
  }
}