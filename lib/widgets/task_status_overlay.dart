import 'package:flutter/material.dart';
import '../services/task_queue_service.dart';

class TaskStatusOverlay extends StatefulWidget {
  const TaskStatusOverlay({super.key});

  @override
  State<TaskStatusOverlay> createState() => _TaskStatusOverlayState();
}

class _TaskStatusOverlayState extends State<TaskStatusOverlay> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TaskQueueService.instance,
      builder: (context, _) {
        final tasks = TaskQueueService.instance.tasks;
        final active = TaskQueueService.instance.activeTasks;
        
        if (tasks.isEmpty) return const SizedBox.shrink();

        return Positioned(
          bottom: 20,
          right: 20,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            clipBehavior: Clip.antiAlias,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: _expanded ? 350 : 250,
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       GestureDetector(
                         onTap: () => setState(() => _expanded = !_expanded),
                         child: Row(
                           children: [
                             Text(
                               'Tasks (${active.isNotEmpty ? "${active.length} running" : "${tasks.length} done"})', 
                               style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                             ),
                             Icon(_expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, size: 16),
                           ],
                         ),
                       ),
                       Row(
                         children: [
                           if (active.isNotEmpty)
                              const SizedBox(
                                width: 12, height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                           if (_expanded && active.isEmpty)
                              InkWell(
                                onTap: () => TaskQueueService.instance.clearCompleted(),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Icon(Icons.clear_all, size: 18),
                                ),
                              )
                         ],
                       ),
                     ],
                   ),
                   if (_expanded) ...[
                     const SizedBox(height: 8),
                     const Divider(),
                     Container(
                       constraints: const BoxConstraints(maxHeight: 400),
                       child: ListView.separated(
                         shrinkWrap: true,
                         itemCount: tasks.length,
                         separatorBuilder: (_, __) => const Divider(height: 1),
                         itemBuilder: (context, index) {
                           final task = tasks[index];
                           IconData icon;
                           Color color;
                           
                           switch (task.state) {
                             case TaskState.running:
                               icon = Icons.sync;
                               color = Colors.blue;
                               break;
                             case TaskState.completed:
                               icon = Icons.check_circle;
                               color = Colors.green;
                               break;
                             case TaskState.failed:
                               icon = Icons.error;
                               color = Colors.red;
                               break;
                           }

                           return ListTile(
                             contentPadding: EdgeInsets.zero,
                             dense: true,
                             leading: Icon(icon, size: 16, color: color),
                             title: Text(task.title, style: const TextStyle(fontSize: 12)),
                             subtitle: Text(
                               task.errorMessage ?? task.state.name, 
                               style: TextStyle(fontSize: 10, color: color),
                             ),
                           );
                         },
                       ),
                     ),
                   ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
