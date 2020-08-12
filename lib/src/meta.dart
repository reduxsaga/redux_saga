part of redux_saga;

/// Meta info for saga.
/// If name is not provided then id is used to identify a saga.
class SagaMeta {
  /// name of saga
  final String name;

  /// id of saga
  final int id;

  /// Creates an instance of [SagaMeta] with [name] and [id] provided
  SagaMeta(this.name, this.id);

  @override
  String toString() {
    return name ?? 'saga#$id';
  }
}
