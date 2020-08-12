part of redux_saga;

/// The Task interface specifies the result of running a Saga using [Fork],
/// [SagaMiddleware.run]
abstract class Task<T> {
  /// Returns true if the task hasn't yet returned or thrown an error
  bool get isRunning;

  /// Returns true if the task has been cancelled
  bool get isCancelled;

  /// Returns true if the task has been aborted
  bool get isAborted;

  /// Returns task return value. `null` if task is still running
  T get result;

  /// Returns task thrown error. `null` if task is still running
  dynamic get error;

  /// Returns a Future which is either:
  /// - resolved with task's return value
  /// - rejected with task's thrown error
  Future<T> toFuture();

  /// Cancels the task (If it is still running)
  void cancel();

  /// Sets the task context.
  /// It does not replace context, instead it extends tasks context with
  /// provided [context].
  void setContext(Map<String, dynamic> context);

  /// Tasks meta data. It identifies saga.
  SagaMeta meta;
}

enum _TaskStatus { Running, Cancelled, Aborted, Done }

class _Task extends Task<dynamic> {
  _SagaMiddleware middleware;
  _InternalTask mainTask;
  SagaContext context;
  int parentEffectId;
  bool isRoot;
  _TaskCallback continueCallback;

  @override
  final SagaMeta meta;

  //SagaContext _context;
  _TaskStatus status;

  _ForkedTasks forkedTasks;

  dynamic taskResult;

  dynamic taskError;
  StackTrace taskStackTrace;

  Completer<dynamic> futureEnd;
  var cancelledDueToErrorTasks = <String>[];

  var joiners = <_TaskJoin>[];

  int get id => parentEffectId;

  _Task(this.middleware, SagaContext parentContext, this.mainTask,
      this.parentEffectId, this.meta, this.isRoot,
      [this.continueCallback]) {
    context = SagaContext();
    context._extend(parentContext.objects);

    continueCallback ??= _noopTaskCallback;

    status = _TaskStatus.Running;

    forkedTasks = _ForkedTasks(mainTask, () {
      cancelledDueToErrorTasks = forkedTasks.getTaskNames();
    }, _TaskCallback(end));
  }

  void _completeWithError() {
    futureEnd.completeError(taskError, taskStackTrace);
  }

  void _completeWithTaskResult() {
    futureEnd.complete(taskResult);
  }

  void end({_TaskCallback invoker, dynamic arg, bool isErr = false}) {
    if (!isErr) {
      // The status here may be Running or Cancelled
      // If the status is Cancelled, then we do not need to change it here
      if (arg == TaskCancel) {
        status = _TaskStatus.Cancelled;
        taskResult = arg;
      } else if (status != _TaskStatus.Cancelled) {
        status = _TaskStatus.Done;
      }

      if (futureEnd != null) {
        _completeWithTaskResult();
      }
    } else {
      status = _TaskStatus.Aborted;

      taskResult = null; //added ***

      middleware.errorStack
          .addSagaFrame(_SagaFrame(meta, cancelledDueToErrorTasks));

      if (isRoot) {
        if (arg is _SagaInternalException) {
          middleware.onError(
              arg.message, '${arg.stackTrace}\n${middleware.errorStack}');
        } else {
          middleware.onError(arg, '${middleware.errorStack}');
        }
      }

      if (arg is _SagaInternalException) {
        taskError = arg.message;
        taskStackTrace = arg.stackTrace;
      } else {
        taskError = arg;
        taskStackTrace =
            StackTrace.fromString(middleware.errorStack.toString());
      }

      if (futureEnd != null) {
        _completeWithError();
      }
    }
    continueCallback.next(arg: arg, isErr: isErr);

    for (var joiner in joiners) {
      joiner.callback.next(arg: arg, isErr: isErr);
    }

    joiners.clear();
  }

  @override
  void cancel() {
    if (status == _TaskStatus.Running) {
      status = _TaskStatus.Cancelled;
      forkedTasks.cancelAll();
      end(arg: TaskCancel, isErr: false);
    }
  }

  @override
  dynamic get error => taskError;

  @override
  bool get isCancelled =>
      status == _TaskStatus.Cancelled ||
      (status == _TaskStatus.Running &&
          mainTask.status == _TaskStatus.Cancelled);

  @override
  bool get isRunning => status == _TaskStatus.Running;

  @override
  bool get isAborted => status == _TaskStatus.Aborted;

  @override
  dynamic get result => taskResult;

  @override
  void setContext(Map<String, dynamic> context) {
    middleware.setContext(context);
  }

  @override
  Future<dynamic> toFuture() {
    if (futureEnd != null) {
      return futureEnd.future;
    }

    futureEnd = Completer<dynamic>();

    if (status == _TaskStatus.Aborted) {
      _completeWithError();
    } else if (status != _TaskStatus.Running) {
      _completeWithTaskResult();
    }

    return futureEnd.future;
  }

  @override
  String toString() {
    return 'Task{Running:$isRunning, Cancelled:$isCancelled, Aborted:$isAborted, Result:$result, Error:$error}';
  }
}

class _InternalTask {
  SagaMeta meta;
  final Callback _cancel;
  _TaskStatus status;
  _TaskCallback continueCallback;
  _Task task;

  void cancel() {
    _cancel();
  }

  dynamic get result => task.result;

  _InternalTask(this.meta, this._cancel, this.status);
}

class _TaskJoin {
  Task task;
  _TaskCallback callback;

  _TaskJoin(this.task, this.callback);
}

/// Creates an object that mocks a [Task] for testing purposes only
class MockTask extends Task<dynamic> {
  dynamic _error;
  bool _aborted = false;
  bool _cancelled = false;
  bool _running = true;
  bool _result = true;

  @override
  void cancel() {}

  @override
  dynamic get error => _error;

  @override
  bool get isAborted => _aborted;

  @override
  bool get isCancelled => _cancelled;

  @override
  bool get isRunning => _running;

  @override
  dynamic get result => _result;

  @override
  void setContext(Map<String, dynamic> context) {}

  @override
  Future toFuture() {
    throw InvalidOperation();
  }

  /// Sets error value
  void setError(bool value) {
    _error = value;
  }

  /// Sets isAborted value
  void setAborted(bool value) {
    _aborted = value;
  }

  /// Sets isCancelled value
  void setCancelled(bool value) {
    _cancelled = value;
  }

  /// Sets isRunning value
  void setRunning(bool value) {
    _running = value;
  }

  /// Sets result value
  void setResult(bool value) {
    _result = value;
  }
}
