import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import 'task_monitor.dart'; // The new card widget

/// A high-fidelity, production-ready Activity Command Center widget.
/// Now uses the collapsible TaskMonitorCard for a cleaner look.
class ActivityCommandCenter extends StatelessWidget {
  const ActivityCommandCenter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, child) {
        
        // 1. Determine State
        final bool isLoading = library.isLoading;
        
        // 2. Map Progress
        double progress = 0.0;
        if (library.totalToScan > 0) {
           progress = library.scannedCount / library.totalToScan;
        } else if (isLoading) {
           progress = 0.0; // Indeterminate state handled by LinearProgressIndicator logic in Card if needed, 
                           // or we can pass 0.0 and let the card show a specific indeterminate animation if we enhanced it.
                           // For now, the card uses `value: progress` if > 0.
        }

        // 3. Map Title
        final String taskName = isLoading 
            ? (library.scanningStatus.isNotEmpty ? library.scanningStatus : 'Processing...')
            : 'System Idle';

        // 4. Map Logs
        // LibraryProvider might not expose a list of logs directly in the snippets I saw, 
        // but the previous code mocked them. Let's try to get real logs or mock them elegantly.
        // The previous code had: `if (lib.error != null) ...`
        
        List<String> logs = [];
        if (library.error != null) {
          logs.add("[ERROR] ${DateTime.now().toIso8601String()}");
          logs.add(library.error.toString());
          logs.add("[CRITICAL] Process halted.");
        }
        if (isLoading) {
           logs.add("[INFO] Task Started by User");
           logs.add("[INFO] Status: ${library.scanningStatus}");
           if (library.currentScanItem != null) {
              logs.add("[DEBUG] Processing: ${library.currentScanItem}");
           }
           logs.add("[INFO] Processed ${library.scannedCount} / ${library.totalToScan} items");
        } else {
           logs.add("[SYSTEM] Ready.");
           logs.add("[SYSTEM] Waiting for commands...");
        }

        // 5. Build Widget
        // If idle, we might want to hide it OR show "Idle".
        // The user said "Show only Progress Bar + Title by default". 
        // Seeing "System Idle" is fine.
        
        return TaskMonitorCard(
          taskName: taskName,
          progress: progress,
          logs: logs,
          isVisible: isLoading || library.error != null, // Show if loading OR if there's an error to display
        );
      },
    );
  }
}
