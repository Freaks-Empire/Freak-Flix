import 'package:flutter/material.dart';
import '../settings_widgets.dart';

/// A simple bar chart showing watch activity over the last 7 days
class ProfileActivityChart extends StatelessWidget {
  final Map<String, int> activityByDay;

  const ProfileActivityChart({
    super.key,
    required this.activityByDay,
  });

  @override
  Widget build(BuildContext context) {
    if (activityByDay.isEmpty) {
      return _buildEmptyState();
    }

    final maxValue = activityByDay.values.fold(0, (max, v) => v > max ? v : max);
    final entries = activityByDay.entries.toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: AppColors.accent,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'WATCH ACTIVITY',
                style: TextStyle(
                  color: AppColors.textSub,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: entries.map((entry) {
                final percentage = maxValue > 0 ? entry.value / maxValue : 0.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (entry.value > 0)
                          Text(
                            '${entry.value}m',
                            style: TextStyle(
                              color: AppColors.textSub.withOpacity(0.7),
                              fontSize: 10,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Flexible(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            width: double.infinity,
                            height: percentage > 0 ? (80 * percentage).clamp(8, 80) : 4,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: percentage > 0
                                    ? [
                                        AppColors.accent,
                                        AppColors.accent.withOpacity(0.6),
                                      ]
                                    : [
                                        AppColors.border,
                                        AppColors.border,
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: percentage > 0
                                  ? [
                                      BoxShadow(
                                        color: AppColors.accent.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.key,
                          style: TextStyle(
                            color: AppColors.textSub.withOpacity(0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.bar_chart_rounded,
            color: AppColors.textSub.withOpacity(0.3),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'No watch activity yet',
            style: TextStyle(
              color: AppColors.textSub.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start watching to see your activity here',
            style: TextStyle(
              color: AppColors.textSub.withOpacity(0.4),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
