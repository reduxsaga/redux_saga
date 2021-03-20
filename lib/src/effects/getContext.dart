part of redux_saga;

/// Creates an effect that instructs the middleware to return a specific property of saga's context.
class GetContext extends EffectWithResult {
  /// Name of context value to get
  final dynamic name;

  /// Creates an instance of a GetContext effect.
  GetContext(this.name, {Result? result}) : super(result: result);

  @override
  void _run(_SagaMiddleware middleware, _TaskCallback cb,
      _ExecutingContext executingContext) {
    cb.next(arg: executingContext.task.context[name]);
  }

  @override
  Map<String, dynamic> getDefinition() {
    var kv = <String, dynamic>{};
    kv['type'] = 'GetContext';
    kv['name'] = name;
    kv['result'] = result;
    return kv;
  }
}
