part of redux_saga;

/// Result value of an Effect after resolved. It keeps data on [value].
class Result<T> {
  /// Value of result.
  T value;

  @override
  String toString() {
    return '$value';
  }
}
