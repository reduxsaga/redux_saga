part of redux_saga;

/// Returns from a Generator function like a return statement in a normal function.
/// Generator stops to instruct remaining statements and immediately returns with the provided [result] value.
class Return extends Effect {
  /// Value to return.
  final dynamic resultValue;

  /// Creates an instance of a Return effect.
  Return([this.resultValue]) : super();

  @override
  void _run(_SagaMiddleware middleware, _TaskCallback cb,
      _ExecutingContext executingContext) {
    if (resultValue is Future) {
      _resolveFuture(resultValue as Future, cb);
      return;
    } else if (resultValue is FutureWithCancel) {
      _resolveFutureWithCancel(resultValue as FutureWithCancel, cb);
      return;
    }

    cb.next(arg: resultValue);
  }

  @override
  void _setResult(_Task task, dynamic value, bool isErr) {
    task.taskResult = value;
  }

  @override
  Map<String, dynamic> getDefinition() {
    var kv = <String, dynamic>{};
    kv['type'] = 'Return';
    kv['resultValue'] = resultValue;
    return kv;
  }
}
