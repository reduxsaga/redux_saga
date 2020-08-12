part of redux_saga;

///  Creates an effect that instructs the middleware to update its own context. This effect extends
///  saga's context instead of replacing it.
class SetContext extends Effect {
  /// New context to set
  final Map<dynamic, dynamic> context;

  /// Creates an instance of a SetContext effect.
  SetContext(this.context) : super();

  @override
  void _run(_SagaMiddleware middleware, _TaskCallback cb,
      _ExecutingContext executingContext) {
    executingContext.task.context._extend(context);
    cb.next();
  }

  @override
  Map<String, dynamic> getDefinition() {
    var kv = <String, dynamic>{};
    kv['type'] = 'SetContext';
    kv['context'] = context;
    return kv;
  }
}
