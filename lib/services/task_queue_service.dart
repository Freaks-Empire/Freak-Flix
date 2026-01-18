import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

enum TaskState { running, completed, failed }

class BackgroundTask {
  final String id;
  final String title;
  final DateTime startTime;
  TaskState state;
  String? errorMessage;

  BackgroundTask({
    required this.id,
    required this.title,
    required this.startTime,
    this.state = TaskState.running,
  });
}

class TaskQueueService extends ChangeNotifier {
  static final TaskQueueService instance = TaskQueueService._();
  TaskQueueService._();

  final List<BackgroundTask> _tasks = [];
  
  List<BackgroundTask> get tasks => List.unmodifiable(_tasks);
  List<BackgroundTask> get activeTasks => _tasks.where((t) => t.state == TaskState.running).toList();

  /// Adds a future to the queue and tracks its execution.
  /// [title] Description shown to user.
  /// [action] The async function to execute.
  Future<T> run<T>(String title, Future<T> Function() action) async {
    final id = const Uuid().v4();
    final task = BackgroundTask(
      id: id,
      title: title,
      startTime: DateTime.now(),
    );

    _tasks.insert(0, task); // Add to top
    notifyListeners();

    try {
      final result = await action();
      task.state = TaskState.completed;
      // _delayedCleanup(id); // Don't auto-remove, let user clear or cap logic handle it
      _enforceLogLimit();
      notifyListeners();
      return result;
    } catch (e) {
      task.state = TaskState.failed;
      task.errorMessage = e.toString();
      debugPrint('Task "$title" failed: $e');
      _enforceLogLimit(); // Keep errors in log
      notifyListeners();
      rethrow;
    }
  }

  void _enforceLogLimit() {
    if (_tasks.length > 50) {
      // Prioritize keeping running tasks.
      // Remove completed/failed tasks that are pushing us over the limit (from the bottom/oldest).
      
      // 1. Identify tasks to keep: All running tasks + up to 50 completed ones
      final running = _tasks.where((t) => t.state == TaskState.running).toList();
      final content = _tasks.where((t) => t.state != TaskState.running).take(50).toList();
      
      if (running.length + content.length < _tasks.length) {
         // Rebuild list if we are trimming
         _tasks.clear();
         _tasks.addAll(running);
         _tasks.addAll(content);
         
         // Sort by start time desc to maintain order? 
         // Originally insert(0) makes it new->old.
         // running tasks are likely new? Not necessarily.
         _tasks.sort((a, b) => b.startTime.compareTo(a.startTime));
      }
    }
  }

  void clearCompleted() {
    _tasks.removeWhere((t) => t.state != TaskState.running);
    notifyListeners();
  }
}
