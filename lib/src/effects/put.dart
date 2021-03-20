part of redux_saga;

///  Creates an Effect description that instructs the middleware to schedule the dispatching of an
///  [action] to the store. This dispatch may not be immediate since other tasks might lie ahead
///  in the saga task queue or still be in progress.
///
///  You can, however, expect the store to be updated in the current stack frame
///  (i.e. by the next line of code after `yield Put(action)`) unless you have other Redux
///  middlewares with asynchronous flows that delay the propagation of the action.
///
///  Downstream errors (e.g. from the reducer) will be bubbled up.
///
///  If a [channel] is provided then action will be put to the provided [channel].
///  Then effect is blocking if the put is *not* buffered but immediately
///  consumed by takers. If an error is thrown in any of these takers it will bubble back
///  into the saga.
///
///  If [resolve] is true then effect is blocking (if Future is returned from `dispatch` it will
///  wait for its resolution) and will bubble up errors from downstream.
///
class Put extends EffectWithResult {
  /// Action object to dispatch.
  final dynamic action;

  /// Channel to dispatch action.
  final Channel? channel;

  /// If true effect will block until resolve.
  final bool resolve;

  /// Creates an instance of a Put effect.
  Put(this.action, {this.channel, this.resolve = false, Result? result})
      : super(result: result);

  @override
  void _run(_SagaMiddleware middleware, _TaskCallback cb,
      _ExecutingContext executingContext) {
    //Schedule the put in case another saga is holding a lock.
    //The put will be executed atomically. ie nested puts will execute after
    //this put has terminated.
    asap(() {
      dynamic result;
      try {
        if (channel == null) {
          result = middleware.dispatch!(action);
        } else {
          channel!.put(action);
        }
      } catch (e, s) {
        cb.next(arg: _createSagaException(e, s), isErr: true);
        return;
      }

      if (resolve && (result != null) && (result is Future)) {
        _resolveFuture(result, cb);
      } else if (resolve && (result != null) && (result is FutureWithCancel)) {
        _resolveFutureWithCancel(result, cb);
      } else {
        cb.next(arg: result);
      }
    });

    // Put effects are non cancellables
  }

  @override
  Map<String, dynamic> getDefinition() {
    var kv = <String, dynamic>{};
    kv['type'] = 'Put';
    kv['action'] = action;
    kv['channel'] = channel;
    kv['resolve'] = resolve;
    kv['result'] = result;
    return kv;
  }
}
