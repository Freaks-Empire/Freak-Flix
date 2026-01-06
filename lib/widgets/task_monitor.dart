import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'settings_widgets.dart'; // Reuse AppColors

class TaskMonitorCard extends StatefulWidget {
  final String taskName;
  final double progress; // 0.0 to 1.0
  final List<String> logs;

  const TaskMonitorCard({
    Key? key,
    required this.taskName,
    required this.progress,
    required this.logs,
  }) : super(key: key);

  @override
  State<TaskMonitorCard> createState() => _TaskMonitorCardState();
}

class _TaskMonitorCardState extends State<TaskMonitorCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, // Zinc 900 (Matches your theme)
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border), // Zinc 800
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // 1. THE HEADER (Always Visible)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Spinning Loader Icon
                    SizedBox(
                      height: 16, width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppColors.accent)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.taskName, 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)
                      ),
                    ),
                    // Toggle Button
                    IconButton(
                      icon: Icon(_expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 18, color: AppColors.textSub),
                      onPressed: () => setState(() => _expanded = !_expanded),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // The Progress Bar (Cyan/Blue or Accent)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: widget.progress > 0 ? widget.progress : null, // Indeterminate if 0? Actually let's assume valid range 0-1
                    backgroundColor: AppColors.bg,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF22d3ee)), // Cyan-400
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${(widget.progress * 100).toInt()}% Complete", style: const TextStyle(color: AppColors.textSub, fontSize: 12)),
                    if (!_expanded)
                      GestureDetector(
                        onTap: () => setState(() => _expanded = true),
                        child: const Text("View Details", style: TextStyle(color: AppColors.textSub, fontSize: 12, decoration: TextDecoration.underline)),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // 2. THE LOGS (Hidden by default, integrated design)
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0, width: double.infinity),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF101012), // Zinc 925 (Slightly darker than surface, but NOT black)
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("ACTIVITY LOG", style: TextStyle(color: AppColors.textSub, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  // Log List
                  if (widget.logs.isEmpty)
                    const Text("No logs available.", style: TextStyle(color: AppColors.textSub, fontSize: 12, fontStyle: FontStyle.italic))
                  else
                    ...widget.logs.take(10).map((log) => Padding( // Limit logs to prevent overflow/lag
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        log, 
                        style: TextStyle(
                          fontFamily: 'monospace', // Monospace font looks "tech" but clean
                          color: log.contains("[ERROR]") ? Colors.redAccent : (log.contains("[DEBUG]") ? AppColors.textSub : AppColors.textMain),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    )).toList(),
                ],
              ),
            ),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}
