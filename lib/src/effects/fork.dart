part of redux_saga;

///  Creates an Effect description that instructs the middleware to perform a *non-blocking call* on [fn]
///
///  - [fn] is a Generator function, or normal function which
///  returns a Future as result.
///
///  - [args] and [namedArgs] are values to be passed as arguments to [fn]
///
///  - [Catch] will be invoked for uncaught errors.
///
///  - [Finally] will be invoked in any case after call.
///
///  - [detached] determines if the [Task] is attached or not. If false then task is attached and
///  when the parent terminates it also terminates. If true then it is [Spawn] effect which is
///  independent from its parent. By default it is false.
///
///  - [name] is an optional name for the [Task] meta.
///
///  `Fork` effects returns a [Task] object.
///
///  ### Notes
///
///  [Fork], like [Call], can be used to invoke both normal and Generator functions. But, the calls are
///  non-blocking, the middleware doesn't suspend the Generator while waiting for the result of [fn].
///  Instead as soon as [fn] is invoked, the Generator resumes immediately.
///
///  `Fork`, alongside [Race], is a central Effect for managing concurrency between Sagas.
///
///  The result of `yield Fork(fn, args:[...])` is a [Task] object.  An object with some useful
///  methods and properties.
///
///  All forked tasks are *attached* to their parents. When the parent terminates the execution of its
///  own body of instructions, it will wait for all forked tasks to terminate before returning.
///
///  ### Error propagation
///  Errors from child tasks automatically bubble up to their parents. If any forked task raises an uncaught error, then
///  the parent task will abort with the child Error, and the whole Parent's execution tree (i.e. forked tasks + the
///  *main task* represented by the parent's body if it's still running) will be cancelled.
///
///  Cancellation of a forked Task will automatically cancel all forked tasks that are still executing. It'll
///  also cancel the current Effect where the cancelled task was blocked (if any).
///
///  If a forked task fails *synchronously* (ie: fails immediately after its execution before performing any
///  async operation), then no Task is returned, instead the parent will be aborted as soon as possible (since both
///  parent and child execute in parallel, the parent will abort as soon as it takes notice of the child failure).
///
///  To create *detached* forks, use [Spawn] instead or set [detached] to true.
class Fork extends EffectWithResult {
  /// Meta name of function
  final String? name;

  /// A Generator function or a normal function to call.
  final Function fn;

  /// Arguments of the function to call
  final List<dynamic>? args;

  /// Named arguments of the function to call
  final Map<Symbol, dynamic>? namedArgs;

  /// A Generator function or a normal function to invoke for uncaught errors.
  final Function? Catch;

  /// A Generator function or a normal function to invoke in any case after call.
  final Function? Finally;

  /// Determines if returning Task is attached or not.
  final bool detached;

  /// Creates an instance of a Fork effect.
  Fork(this.fn,
      {this.args,
      this.namedArgs,
      this.Catch,
      this.Finally,
      this.name,
      this.detached = false,
      Result? result})
      : super(result: result);

  @override
  void _run(_SagaMiddleware middleware, _TaskCallback cb,
      _ExecutingContext executingContext) {
    var parent = executingContext.task;

    var taskIterator = _createTaskIterator(fn, args, namedArgs);

    immediately(() {
      var child = middleware._createTask(
          executingContext.task.context,
          taskIterator.iterator,
          Catch,
          Finally,
          middleware.uniqueId.currentEffectId(),
          SagaMeta(name, middleware.uniqueId.currentEffectId()),
          detached,
          null);

      if (detached) {
        cb.next(arg: child);
      } else {
        if (child.isRunning) {
          parent.forkedTasks.addTask(child);
          cb.next(arg: child);
        } else if (child.isAborted) {
          parent.forkedTasks.abort(child.error);
        } else {
          cb.next(arg: child);
        }
      }
      return child;
    });

    // Fork effects are non cancellables
  }

  @override
  Map<String, dynamic> getDefinition() {
    var kv = <String, dynamic>{};
    kv['type'] = 'Fork';
    kv['fn'] = fn;
    kv['args'] = args;
    kv['namedArgs'] = namedArgs;
    kv['onError'] = Catch;
    kv['onFinally'] = Finally;
    kv['name'] = name;
    kv['detached'] = detached;
    kv['result'] = result;
    return kv;
  }
}

Iterable _createTaskIterator(
    Function function, List<dynamic>? args, Map<Symbol, dynamic>? namedArgs) {
  // catch synchronous failures
  try {
    dynamic result = _callFunction(function, args, namedArgs);

    // i.e. a generator function returns an iterator
    if (result is Iterable) {
      return result;
    }
    return _iteratorAdapter(result);
  } catch (e, s) {
    // do not bubble up synchronous failures for detached forks
    // instead create a failed task.
    return _iteratorAdapterThrows(_createSagaException(e, s));
  }
}

Iterable<Effect> _iteratorAdapter(dynamic value) sync* {
  yield Return(value);
}

Iterable<Effect> _iteratorAdapterThrows(_SagaInternalException error) sync* {
  throw error;
}
