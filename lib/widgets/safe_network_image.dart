import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

/// Network image that fails gracefully and shows a placeholder on 404/other errors.
class SafeNetworkImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const SafeNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(12);

    // No URL? Just show placeholder.
    if (url == null || url!.isEmpty) {
      return _buildPlaceholder(radius);
    }

    final safeUrl = url!;
    
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final isStash = safeUrl.contains('stashdb.org');
        
        return Image.network(
          safeUrl,
          width: width,
          height: height,
          fit: fit,
          headers: isStash ? {'ApiKey': settings.stashApiKey} : null,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          (progress.expectedTotalBytes ?? 1)
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder(radius);
          },
        );
      }
    );

    return ClipRRect(
      borderRadius: radius,
      child: image,
    );
  }

  Widget _buildPlaceholder(BorderRadius radius) {
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: width,
        height: height,
        color: Colors.grey.shade900,
        child: Icon(
          Icons.broken_image_rounded,
          color: Colors.grey.shade600,
          size: 32,
        ),
      ),
    );
  }
}
