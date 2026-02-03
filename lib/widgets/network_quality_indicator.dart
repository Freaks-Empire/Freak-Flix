/// lib/widgets/network_quality_indicator.dart
/// 
/// Network quality indicator widget
/// Shows connection strength, download speed, and buffering status

import 'package:flutter/material.dart';

enum NetworkQuality {
  excellent,  // > 10 Mbps, < 50ms latency
  good,        // 5-10 Mbps, 50-100ms latency
  fair,         // 2-5 Mbps, 100-200ms latency
  poor,         // < 2 Mbps, > 200ms latency
  disconnected,  // No connection
}

class NetworkQualityIndicator extends StatelessWidget {
  final NetworkQuality? quality;
  final String? speedText;
  final bool isLoading;
  final Duration? bufferingTime;

  const NetworkQualityIndicator({
    super.key,
    this.quality,
    this.speedText,
    this.isLoading = false,
    this.bufferingTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getQualityColor(),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildQualityIcon(),
          const SizedBox(height: 4),
          if (speedText != null)
            Text(
              speedText!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (bufferingTime != null)
            _buildBufferingIndicator(),
        ],
      ),
    );
  }

  Widget _buildQualityIcon() {
    IconData icon;
    String label;
    Color color;

    if (isLoading) {
      icon = Icons.hourglass_empty;
      label = 'Loading...';
      color = Colors.grey[400];
    } else if (quality == null) {
      icon = Icons.wifi_off;
      label = 'Disconnected';
      color = Colors.red[400];
    } else {
      switch (quality!) {
        case NetworkQuality.excellent:
          icon = Icons.wifi_off;
          label = _getQualityLabel(quality);
          color = _getQualityColor(quality);
          break;
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildBufferingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Buffering...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getQualityColor() {
    if (quality == null) return Colors.grey[600];
    
    switch (quality!) {
      case NetworkQuality.excellent:
        return Colors.green.withOpacity(0.2);
      case NetworkQuality.good:
        return Colors.blue.withOpacity(0.2);
      case NetworkQuality.fair:
        return Colors.orange.withOpacity(0.2);
      case NetworkQuality.poor:
        return Colors.deepOrange.withOpacity(0.2);
      case NetworkQuality.disconnected:
        return Colors.red.withOpacity(0.2);
    }
  }

  IconData _getQualityIcon(NetworkQuality? quality) {
    if (quality == null) return Icons.wifi_off;
    
    switch (quality!) {
      case NetworkQuality.excellent:
        return Icons.signal_cellular_alt;
      case NetworkQuality.good:
        return Icons.signal_cellular_3_bar;
      case NetworkQuality.fair:
        return Icons.signal_cellular_2_bar;
      case NetworkQuality.poor:
        return Icons.signal_cellular_1_bar;
      case NetworkQuality.disconnected:
        return Icons.signal_wifi_off;
    }
  }

  String _getQualityLabel(NetworkQuality? quality) {
    if (quality == null) return 'No Connection';
    
    switch (quality!) {
      case NetworkQuality.excellent:
        return 'Excellent';
      case NetworkQuality.good:
        return 'Good';
      case NetworkQuality.fair:
        return 'Fair';
      case NetworkQuality.poor:
        return 'Poor';
      case NetworkQuality.disconnected:
        return 'No Connection';
      default:
        return 'Unknown';
    }
  }
}