/// lib/widgets/simple_optimized_image.dart
/// 
/// Simple optimized image widget for better performance
/// Basic image loading with caching and error handling

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SimpleOptimizedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final BoxFit fit;
  final Duration fadeInDuration;
  final bool enableCache;

  const SimpleOptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.placeholder,
    this.fit = BoxFit.cover,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.enableCache = true,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      placeholder: placeholder,
      fit: fit,
      fadeInDuration: fadeInDuration,
      // Enable memory cache
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
      errorWidget: placeholder ?? const Icon(Icons.broken_image),
    );
  }
}

/// Extension for easy usage
extension SimpleOptimizedImageExtensions on Widget {
  /// Wrap with simple optimized image
  Widget withSimpleOptimizedImage({
    required String imageUrl,
    double? width,
    double? height,
    Widget? placeholder,
    BoxFit fit = BoxFit.cover,
    Duration fadeInDuration = const Duration(milliseconds: 300),
  }) {
    return SimpleOptimizedImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      placeholder: placeholder,
      fit: fit,
      fadeInDuration: fadeInDuration,
    );
  }
}