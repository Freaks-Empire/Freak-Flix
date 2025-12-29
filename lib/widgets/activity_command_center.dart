import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';

/// A high-fidelity, production-ready Activity Command Center widget.
/// Manages complex visual states (Idle, Busy, Expanded) for the media application.
/// 
/// AESTHETIC: DARK_MODE_NETFLIX_CYBERPUNK
class ActivityCommandCenter extends StatefulWidget {
  const ActivityCommandCenter({super.key});

  @override
  State<ActivityCommandCenter> createState() => _ActivityCommandCenterState();
}

class _ActivityCommandCenterState extends State<ActivityCommandCenter> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _showRawLogs = false;

  @override
  Widget build(BuildContext context) {
    // Usage: Consumer ensures we rebuild on LibraryProvider changes
    return Consumer<LibraryProvider>(
      builder: (context, library, child) {
        // --- Simulated State Input Mapping ---
        // Mapping real provider state to the requested input variables
        final bool isLoading = library.isLoading;
        // If status empty, default to "System Idle"
        final String currentTask = library.scanningStatus.isNotEmpty 
            ? library.scanningStatus 
            : 'System Idle';
        
        // Calculate progress if available, else indeterminate (null)
        double? progress; // null for indeterminate
        if (library.totalToScan > 0) {
           progress = library.scannedCount / library.totalToScan;
        } else if (isLoading) {
           progress = null; // Indeterminate
        } else {
           progress = 0.0;
        }

        final int activeTasksCount = isLoading ? 1 : 0; // Simplified for now
        
        // Format Current Time for "Last scan" placeholder
        final String timeString = "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";

        // --- Aesthetics ---
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        
        // "Cyberpunk" accents
        final Color accentColor = isLoading ? const Color(0xFF00E5FF) : Colors.grey; // Cyan when busy
        final Color dangerColor = const Color(0xFFFF2B2B); // Red for errors/logs
        final Color surfaceColor = _isExpanded 
            ? Color.alphaBlend(Colors.black.withOpacity(0.2), colorScheme.surfaceContainerHighest) 
            : colorScheme.surfaceContainerHighest;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0.0),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isExpanded ? accentColor.withOpacity(0.3) : Colors.white10,
              width: 1.0,
            ),
            boxShadow: _isExpanded ? [
               BoxShadow(color: accentColor.withOpacity(0.1), blurRadius: 12, spreadRadius: -2)
            ] : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- HEADS-UP STATE (Collapsed / Header) ---
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(12), // Match container
                child: SizedBox(
                  height: 70,
                  child: Stack(
                    children: [
                      // Main Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            // Left Icon
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: isLoading
                                  ? SizedBox(
                                      key: const ValueKey('busy'),
                                      width: 24, 
                                      height: 24, 
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5, 
                                        color: accentColor,
                                      ),
                                    )
                                  : Icon(
                                      Icons.history, 
                                      key: const ValueKey('idle'),
                                      color: Colors.grey,
                                    ),
                            ),
                            const SizedBox(width: 16),
                            
                            // Center Text
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: isLoading
                                        ? Text(
                                            "Processing: $activeTasksCount Tasks Active",
                                            key: const ValueKey('text_busy'),
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          )
                                        : Text(
                                            "System Idle • Last scan $timeString",
                                            key: const ValueKey('text_idle'),
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: Colors.grey,
                                              // Using roboto/standard for idle text as requested
                                            ),
                                          ),
                                  ),
                                  if (isLoading)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        currentTask, 
                                        maxLines: 1, 
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white70, 
                                          fontSize: 12,
                                          fontFamily: 'monospace' // Fallback for dev/terminal feel
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Expand Chevron
                            AnimatedRotation(
                              turns: _isExpanded ? 0.5 : 0.0,
                              duration: const Duration(milliseconds: 300),
                              child: const Icon(Icons.expand_more, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      
                      // The "Secret" Bottom Progress Bar
                      if (isLoading)
                        Positioned(
                          left: 4, right: 4, bottom: 0,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                            child: LinearProgressIndicator(
                              value: progress, // Null = indeterminate animation
                              minHeight: 2,
                              backgroundColor: Colors.transparent,
                              color: accentColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // --- COMMAND CENTER STATE (Expanded Content) ---
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                child: _isExpanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Divider(height: 1, color: Colors.white10),
                          
                          // SECTION A: Active High-Priority Row
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "ACTIVE TASK", 
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: accentColor, 
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2
                                      )
                                    ),
                                    // Monospace Metadata
                                    Text(
                                      isLoading ? "RUNNING • ${(progress != null ? (progress! * 100).toStringAsFixed(1) : '--')}%" : "WAITING",
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Metadata / Speed (Simulated)
                                if (isLoading) ...[
                                  Text(
                                    currentTask,
                                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    "Rate estimates unavailable", // Placeholder for Speed
                                    style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // Thick Progress Bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 8,
                                      backgroundColor: Colors.black26,
                                      color: accentColor, // "Cyberpunk" Cyan
                                    ),
                                  ),
                                ] else 
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Center(child: Text("No active processes.", style: TextStyle(color: Colors.white38))),
                                  ),
                              ],
                            ),
                          ),

                          // SECTION B: Queue (Simulated for this widget, could be real later)
                          Container(
                            color: Colors.black12,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Text(
                                    "QUEUE (PENDING)", 
                                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.white38)
                                  ),
                                ),
                                if (isLoading && library.totalToScan > library.scannedCount)
                                  _TaskItem(
                                      title: "Pending Item #${library.scannedCount + 1}", 
                                      status: "Queued", 
                                      isDimmed: true
                                  )
                                else
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    child: Text("Empty", style: TextStyle(color: Colors.white24, fontStyle: FontStyle.italic)),
                                  ),
                              ],
                            ),
                          ),

                          // SECTION C: Console Footer
                          InkWell(
                            onTap: () => setState(() => _showRawLogs = !_showRawLogs),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: const BoxDecoration(
                                border: Border(top: BorderSide(color: Colors.white10)),
                              ),
                              child: Row(
                                children: [
                                  Icon(_showRawLogs ? Icons.terminal : Icons.code, size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    _showRawLogs ? "Hide Raw Logs" : "View Raw Logs",
                                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  if (library.error != null)
                                    Icon(Icons.warning_amber_rounded, size: 16, color: dangerColor),
                                ],
                              ),
                            ),
                          ),
                          
                          // Raw Logs View (Terminal Style)
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 200),
                            crossFadeState: _showRawLogs ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                            firstChild: const SizedBox(width: double.infinity),
                            secondChild: Container(
                              width: double.infinity,
                              height: 150,
                              color: const Color(0xFF101010), // Almost black
                              padding: const EdgeInsets.all(12),
                              child: SingleChildScrollView(
                                reverse: true,
                                child: Text(
                                  _buildMockLogs(library),
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: Color(0xFF00FF41), // Terminal Green
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  String _buildMockLogs(LibraryProvider lib) {
    if (lib.error != null) {
      return "[ERROR] ${DateTime.now().toIso8601String()}\n${lib.error}\n[CRITICAL] Process halted.";
    }
    if (lib.isLoading) {
      return "[INFO] Scan initiated by User\n[INFO] Connecting to Metadata Service...\n[DEBUG] Found ${lib.scannedCount} items so far\n[INFO] Processing: ${lib.currentScanItem ?? 'Unknown'}...\n> _";
    }
    return "[SYSTEM] Ready.\n[SYSTEM] Waiting for commands...\n> _";
  }
}

/// Helper widget for Queue items.
/// Dims content to 60% opacity as requested for Section B.
class _TaskItem extends StatelessWidget {
  final String title;
  final String status;
  final bool isDimmed;

  const _TaskItem({
    required this.title,
    required this.status,
    this.isDimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDimmed ? 0.6 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.circle_outlined, size: 12, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 13))),
            Text(status, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
