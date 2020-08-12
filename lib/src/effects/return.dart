part of redux_saga;

/// Returns from a Generator function like a return statement in a normal function.
/// Generator stops to instruct remaining statements and immediately returns with the provided [result] value.
class Return extends Effect {
  /// Value to return.
  final dynamic result;

  /// Creates an instance of a Return effect.
  Return([this.result]) : super();

  @override
  void _run(_SagaMiddleware middleware, _TaskCallback cb,
      _ExecutingContext executingContext) {
    if (result is Future) {
      _resolveFuture(result as Future, cb);
      return;
    } else if (result is FutureWithCancel) {
      _resolveFutureWithCancel(result as FutureWithCancel, cb);
      return;
    }

    cb.next(arg: result);
  }

  @override
  void _setResult(_Task task, dynamic value, bool isErr) {
    task.taskResult = value;
  }

  @override
  Map<String, dynamic> getDefinition() {
    var kv = <String, dynamic>{};
    kv['type'] = 'Return';
    kv['result'] = result;
    return kv;
  }
}
