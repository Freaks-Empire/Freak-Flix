/// lib/widgets/image_extensions.dart
/// 
/// Extension for optimized image loading across the app

import 'package:cached_network_image/cached_network_image.dart';

extension OptimizedImageExtensions on Widget {
  /// Add optimized image loading with better caching
  Widget withOptimizedImage({
    required String imageUrl, {
    double? width,
    double? height,
    Widget? placeholder,
    BoxFit fit = BoxFit.cover,
    Duration fadeInDuration = const Duration(milliseconds: 300),
    bool enableCache = true,
  }) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      placeholder: placeholder,
      fit: fit,
      fadeInDuration: fadeInDuration,
      memCacheWidth: enableCache ? width?.toInt() : null,
      memCacheHeight: enableCache ? height?.toInt() : null,
      errorWidget: placeholder,
    );
  }
}