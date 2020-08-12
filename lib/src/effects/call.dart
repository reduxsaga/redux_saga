part of redux_saga;

///  Creates an Effect description that instructs the middleware to call the
///  function [fn] with [args] and [namedArgs] as arguments.
///
///  - [fn] is a Generator function, or normal function which
///  returns a Future as result, or any other value.
///
///  - [args] and [namedArgs] are values to be passed as arguments to [fn]
///
///  - [Catch] will be invoked for uncaught errors.
///
///  - [Finally] will be invoked in any case after call.
///
///  - [name] is an optional name for the task meta.
///
///  ### Notes
///
///  [fn] can be either a *normal* or a Generator function.
///
///  The middleware invokes the function and examines its result.
///
///  If the result is an Iterator object, the middleware will run that Generator function, just like it did with the
///  startup Generators (passed to the middleware on startup). The parent Generator will be
///  suspended until the child Generator terminates normally, in which case the parent Generator
///  is resumed with the value returned by the child Generator. Or until the child aborts with some
///  error, in which case an error will be thrown inside the parent Generator.
///
///  If [fn] is a normal function and returns a Future, the middleware will suspend the Generator until the Future is
///  settled. After the future is resolved the Generator is resumed with the resolved value, or if the Future
///  is rejected an error is thrown inside the Generator.
///
///  If the result is not an Iterator object nor a Future, the middleware will immediately return that
///  value back to the saga, so that it can resume its execution synchronously.
///
///  When an error is thrown, if it has a [Try] block surrounding the
///  current `yield` instruction, the control will be passed to the [Catch] block. Otherwise,
///  the Generator aborts with the raised error, and if this Generator was called by another
///  Generator, the error will propagate to the calling Generator.
class Call extends EffectWithResult {
  /// Meta name of function
  final String name;

  /// A Generator function or a normal function to call.
  final Function fn;

  /// Arguments of the function to call
  final List<dynamic> args;

  /// Named arguments of the function to call
  final Map<Symbol, dynamic> namedArgs;

  /// A Generator function or a normal function to invoke for uncaught errors.
  final Function Catch;

  /// A Generator function or a normal function to invoke in any case after call.
  final Function Finally;

  /// Creates an instance of a Call effect.
  Call(this.fn,
      {this.args,
      this.namedArgs,
      this.Catch,
      this.Finally,
      this.name,
      Result result})
      : super(result: result);

  @override
  void _run(_SagaMiddleware middleware, _TaskCallback cb,
      _ExecutingContext executingContext) {
    if (Catch == null && Finally == null) {
      try {
        dynamic result = _callFunction(fn, args, namedArgs);

        if (result is Iterable) {
          // resolve iterator
          middleware._createTask(
              executingContext.task.context,
              result.iterator,
              Catch,
              Finally,
              middleware.uniqueId.currentEffectId(),
              SagaMeta(name, middleware.uniqueId.currentEffectId()),
              false,
              cb);
          return;
        } else {
          if (result is Future) {
            _resolveFuture(result, cb);
            return;
          } else if (result is FutureWithCancel) {
            _resolveFutureWithCancel(result, cb);
            return;
          }
          cb.next(arg: result);
        }
      } catch (e, s) {
        cb.next(arg: _createSagaException(e, s), isErr: true);
      }
    } else {
      var taskIterator = _createTaskIterator(fn, args, namedArgs);
      middleware._createTask(
          executingContext.task.context,
          taskIterator.iterator,
          Catch,
          Finally,
          middleware.uniqueId.currentEffectId(),
          SagaMeta(name, middleware.uniqueId.currentEffectId()),
          false,
          cb);
      return;
    }
  }

  @override
  Map<String, dynamic> getDefinition() {
    var kv = <String, dynamic>{};
    kv['type'] = 'Call';
    kv['fn'] = fn;
    kv['args'] = args;
    kv['namedArgs'] = namedArgs;
    kv['onError'] = Catch;
    kv['onFinally'] = Finally;
    kv['name'] = name;
    kv['result'] = result;
    return kv;
  }
}
