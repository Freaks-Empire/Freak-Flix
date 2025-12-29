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
      _delayedCleanup(id);
      notifyListeners();
      return result;
    } catch (e) {
      task.state = TaskState.failed;
      task.errorMessage = e.toString();
      debugPrint('Task "$title" failed: $e');
      _delayedCleanup(id, delay: const Duration(seconds: 10)); // Keep errors longer
      notifyListeners();
      rethrow;
    }
  }

  void _delayedCleanup(String id, {Duration delay = const Duration(seconds: 5)}) {
    Future.delayed(delay, () {
      _tasks.removeWhere((t) => t.id == id);
      notifyListeners();
    });
  }
}
