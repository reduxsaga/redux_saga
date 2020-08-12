part of redux_saga;

/// Base Saga effect type. All effects are inherited from this class.
abstract class Effect {
  void _setResult(_Task task, dynamic value, bool isErr) {}

  void _run(_SagaMiddleware middleware, _TaskCallback cb,
      _ExecutingContext executingContext);

  @override
  String toString() {
    var sb = StringBuffer();
    sb.write('{');
    var kv = getDefinition();
    for (var k in getDefinition().keys) {
      sb.write('$k : ${kv[k]}, ');
    }
    sb.write('}');
    return sb.toString();
  }

  /// Returns all properties of effect as a dictionary object
  Map<String, dynamic> getDefinition();
}
