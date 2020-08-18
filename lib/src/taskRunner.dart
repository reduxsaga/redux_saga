part of redux_saga;

bool _shouldTerminate(dynamic value) => value == Terminate;

bool _shouldCancel(dynamic value) => value == TaskCancel;

bool _shouldComplete(dynamic value) =>
    _shouldTerminate(value) || _shouldCancel(value);

typedef _DigestEffectHandler = void Function(
    dynamic effect, int parentEffectId, _TaskCallback cb,
    [dynamic label]);

typedef _RunEffectHandler = void Function(
    dynamic effect, int effectId, _TaskCallback currCb);
typedef _RunEffectFinalizer = _RunEffectHandler Function(_RunEffectHandler);

class _ExecutingContext {
  _Task task;
  _DigestEffectHandler digestEffect;

  _ExecutingContext(this.task, this.digestEffect);
}

enum _CodeBlock { mainCode, errorCode, finallyCode }

class _taskRunner {
  _SagaMiddleware middleware;

  Iterator iterator;

  SagaContext parentContext;
  int parentEffectId;
  SagaMeta meta;
  bool isRoot;

  _TaskCallback continueCallback;

  final Function onError;
  bool onErrorExecuted = false;

  final Function onFinally;
  bool onFinallyExecuted = false;

  var codeBlock = _CodeBlock.mainCode;

  _RunEffectHandler finalRunEffect;

  _taskRunner(
      this.middleware,
      this.parentContext,
      this.iterator,
      this.onError,
      this.onFinally,
      this.parentEffectId,
      this.meta,
      this.isRoot,
      this.continueCallback);

  _InternalTask mainTask;
  _ExecutingContext executingContext;

  _Task _task;

  _Task createTask() {
    finalRunEffect = middleware.getRunEffectFinalizer()(runEffect);

    /// Tracks the current effect and its cancellation
    /// Each time the generator progresses. calling runEffect will set a new value
    /// on cancel. It allows propagating cancellation to child effects
    var starterNextCallback = _TaskCallback(next, _noop);

    // cancellation of the main task. We'll simply resume the Generator with a TaskCancel
    var cancelMain = () {
      if (mainTask.status == _TaskStatus.Running) {
        mainTask.status = _TaskStatus.Cancelled;
        starterNextCallback.next(arg: TaskCancel);
      }
    };

    //Creates a main task to track the main flow
    mainTask = _InternalTask(meta, cancelMain, _TaskStatus.Running);

    //Creates a new task descriptor for this generator.
    //A task is the aggregation of it's mainTask and all it's forked tasks.
    _task = _Task(middleware, parentContext, mainTask, parentEffectId, meta,
        isRoot, continueCallback);

    mainTask.task = _task;

    executingContext = _ExecutingContext(_task, digestEffect);

    //attaches cancellation logic to this task's continuation
    //this will permit cancellation to propagate down the call chain
    if (continueCallback != null) {
      continueCallback.cancelHandler = () {
        _task.cancel();
      };
    }

    // kicks up the generator
    starterNextCallback.next();

    return _task;
  }

  _SagaInternalException currentException;

  String currentSagaStack;
  bool throwException = false;
  dynamic sendAfterFinally;
  bool sendAfterFinallyErr;

  void storeException(_SagaInternalException e) {
    currentException = e;
    currentSagaStack = middleware.errorStack.toString();
  }

  void clearException() {
    currentException = null;
    currentSagaStack = null;
  }

  void clearCurrentExecution(_TaskCallback ncb) {
    iterator = null;
    ncb.effect = null;
  }

  void switchToOnError(_TaskCallback ncb) {
    try {
      clearCurrentExecution(ncb);
      onErrorExecuted = true;
      codeBlock = _CodeBlock.errorCode;
      processFunctionReturn(ncb, _callErrorFunction(onError, currentException),
          !_isFunctionVoid(onError));
    } catch (e, s) {
      ncb.next(arg: _createSagaException(e, s), isErr: true);
    }
  }

  void switchToOnFinally(_TaskCallback callback) {
    try {
      clearCurrentExecution(callback);
      onFinallyExecuted = true;
      codeBlock = _CodeBlock.finallyCode;
      processFunctionReturn(callback, _callFinallyFunction(onFinally),
          !_isFunctionVoid(onFinally));
    } catch (e, s) {
      callback.next(arg: _createSagaException(e, s), isErr: true);
    }
  }

  void processFunctionReturn(
      _TaskCallback callback, dynamic fr, bool assignTaskResult) {
    if (fr is Future || fr is FutureWithCancel) {
      var tcb =
          _TaskCallback(({_TaskCallback invoker, dynamic arg, bool isErr}) {
        if (!isErr) {
          if (assignTaskResult) mainTask.task.taskResult = arg;
        }
        callback.next(arg: arg, isErr: isErr);
      }, () {
        callback.cancel();
      });

      if (fr is Future) {
        _resolveFuture(fr, tcb);
      } else if (fr is FutureWithCancel) {
        _resolveFutureWithCancel(fr, tcb);
      }
    } else if (fr is Iterable) {
      //assign new iterator
      iterator = fr.iterator;
      callback.next();
    } else {
      if (assignTaskResult) mainTask.task.taskResult = fr;
      callback.next(arg: fr);
    }
  }

  /// This is the generator driver
  /// It's a recursive async/continuation function which calls itself
  /// until the generator terminates or throws
  void next({_TaskCallback invoker, dynamic arg, bool isErr = false}) {
    try {
      bool done;
      dynamic returnValue;

      if (isErr) {
        throw arg;
      } else if (_shouldCancel(arg)) {
        //getting TaskCancel automatically cancels the main task
        //We can get this value here
        //
        //- By cancelling the parent task manually
        //- By joining a Cancelled task
        mainTask.status = _TaskStatus.Cancelled;

        //Cancels the current effect; this will propagate the cancellation down to any called tasks
        invoker.cancel();

        if (shouldRunOnFinally()) {
          sendAfterFinally = arg;
          sendAfterFinallyErr = isErr;
          switchToOnFinally(invoker);
          return;
        }
        done = true;
        returnValue = TaskCancel;
        _task.taskResult = TaskCancel;
      } else if (_shouldTerminate(arg)) {
        if (shouldRunOnFinally()) {
          sendAfterFinally = arg;
          sendAfterFinallyErr = isErr;
          switchToOnFinally(invoker);
          return;
        }
        done = true;
        returnValue = null;
      } else {
        var returnEffect = false;

        if (invoker.effect != null && invoker.effect is Effect) {
          if (invoker.effect is Return || invoker.effect is TryReturn) {
            returnEffect = true;
          }
        }

        var iterating =
            (!returnEffect) && (iterator != null) && iterator.moveNext();

        done = !iterating;

        if (done) {
          if (codeBlock == _CodeBlock.errorCode) {
            clearException();
          } else if (codeBlock == _CodeBlock.finallyCode) {
            if (throwException) {
              throw currentException;
            } else if (sendAfterFinally != null) {
              invoker.next(arg: sendAfterFinally, isErr: sendAfterFinallyErr);
              return;
            }
          }

          if (shouldRunOnFinally()) {
            switchToOnFinally(invoker);
            return;
          }
        }

        returnValue = iterating ? iterator.current : null;
      }

      if (!done) {
        digestEffect(returnValue, parentEffectId, invoker);
      } else {
        if (mainTask.status == _TaskStatus.Cancelled) {
          mainTask.continueCallback.next(arg: TaskCancel);
        } else {
          //not cancelled
          mainTask.status = _TaskStatus.Done;
          mainTask.continueCallback.next(arg: _task.result);
        }
      }
    } catch (e, s) {
      if (!isSagaError(e)) storeException(_createSagaException(e, s));

      if (shouldRunOnError()) {
        switchToOnError(invoker);
      } else if (shouldRunOnFinally()) {
        throwException = true;
        switchToOnFinally(invoker);
      } else {
        if (mainTask.status == _TaskStatus.Cancelled) {
          if (isSagaError(e)) {
            throw currentException;
          } else {
            rethrow;
          }
        }

        mainTask.status = _TaskStatus.Aborted;

        mainTask.continueCallback.next(
            arg: isSagaError(e) ? currentException : _createSagaException(e, s),
            isErr: true);
      }
    }
  }

  bool shouldRunOnError() =>
      (codeBlock == _CodeBlock.mainCode) &&
      (onError != null) &&
      (!onErrorExecuted);

  bool shouldRunOnFinally() => (onFinally != null) && (!onFinallyExecuted);

  void runEffect(dynamic effect, int effectId, _TaskCallback currCb) {
    if (effect is Future) {
      _resolveFuture(effect, currCb);
    } else if (effect is FutureWithCancel) {
      _resolveFutureWithCancel(effect, currCb);
    } else if (effect is Iterable) {
      middleware._createTask(_task.context, effect.iterator, null, null,
          effectId, meta, false, currCb);
    } else if (effect != null && effect is Effect) {
      effect._run(middleware, currCb, executingContext);
    } else {
      currCb.next(arg: effect);
    }
  }

  void digestEffect(dynamic effect, int parentEffectId, _TaskCallback callback,
      [dynamic label = '']) {
    var effectId = middleware.uniqueId.nextSagaId();
    if (middleware.monitoring) {
      middleware.sagaMonitor
          .effectTriggered(effectId, parentEffectId, label, effect);
    }

    var effectSettled = false;

    // Completion callback passed to the appropriate effect runner
    var currentCallback = _TaskCallback((
        {_TaskCallback invoker, dynamic arg, bool isErr = false}) {
      if (effectSettled) {
        return;
      }

      effectSettled = true;
      callback.cancelHandler = _noop; // defensive measure
      if (middleware.monitoring) {
        if (isErr) {
          middleware.sagaMonitor.effectRejected(
              effectId, arg is _SagaInternalException ? arg.message : arg);
        } else {
          middleware.sagaMonitor.effectResolved(effectId, arg);
        }
      }

      if (isErr) {
        middleware.errorStack.setCrashedEffect(effect);
      }

      if (callback.effect != null &&
          callback.effect is Effect &&
          (!isErr) &&
          (!_shouldComplete(arg))) {
        (callback.effect as Effect)._setResult(_task, arg, isErr);
      }

      callback.next(arg: arg, isErr: isErr);
    });

    // tracks down the current cancel
    currentCallback.cancelHandler = _noop;

    // setup cancellation logic on the parent callback
    callback.cancelHandler = () {
      // prevents cancelling an already completed effect
      if (effectSettled) {
        return;
      }

      effectSettled = true;

      currentCallback.cancelHandler(); // propagates cancel downward
      currentCallback.cancelHandler = _noop; // defensive measure

      if (middleware.monitoring) {
        middleware.sagaMonitor.effectCancelled(effectId);
      }
    };

    callback.effect = effect;

    finalRunEffect(effect, effectId, currentCallback);
  }
}
