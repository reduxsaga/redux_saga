part of redux_saga;

/// Result value for a cancelled [Task]
final TaskCancel = TaskResult('TaskCancel');

/// Result value for a terminated [Task]
final Terminate = TaskResult('Terminate');

/// Represents possible result of a [Task]
class TaskResult {
  /// Result description
  final String description;

  /// Creates an instance of [TaskResult] with a definition of [description]
  TaskResult([this.description]);

  @override
  String toString() {
    return description;
  }
}
