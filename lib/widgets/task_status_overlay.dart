import 'package:flutter/material.dart';
import '../services/task_queue_service.dart';

class TaskStatusOverlay extends StatelessWidget {
  const TaskStatusOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TaskQueueService.instance,
      builder: (context, _) {
        final tasks = TaskQueueService.instance.tasks;
        final active = TaskQueueService.instance.activeTasks;
        
        if (tasks.isEmpty) return const SizedBox.shrink();

        // Show completed tasks for a few seconds (handled by service cleanup),
        // so we just display the whole list but styled.
        
        return Positioned(
          bottom: 20,
          right: 20,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Text(
                         'Background Tasks (${active.length})', 
                         style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                       ),
                       if (active.isNotEmpty)
                          const SizedBox(
                            width: 12, height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                     ],
                   ),
                   const SizedBox(height: 8),
                   Container(
                     constraints: const BoxConstraints(maxHeight: 200),
                     child: ListView.separated(
                       shrinkWrap: true,
                       itemCount: tasks.length,
                       separatorBuilder: (_, __) => const Divider(height: 8),
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

                         return Row(
                           children: [
                             Icon(icon, size: 16, color: color),
                             const SizedBox(width: 8),
                             Expanded(
                               child: Text(
                                 task.title,
                                 style: const TextStyle(fontSize: 12),
                                 maxLines: 1,
                                 overflow: TextOverflow.ellipsis,
                               ),
                             ),
                           ],
                         );
                       },
                     ),
                   ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
