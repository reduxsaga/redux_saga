part of redux_saga;

///  Creates an Effect description that instructs the middleware to wait for the result
///  of a previously forked tasks.
///
///  - [tasks] is a dictionary of tasks that each member is returned by a previous [Fork].
///
///  `Join` effect returns a [JoinResult]. It contains each Tasks return value.
///
///  ### Notes
///
///  [Join] will resolve to the same outcome of the joined task (success or error). If the joined
///  task is cancelled, the cancellation will also propagate to the Saga executing the join
///  effect. Similarly, any potential callers of those joiners will be cancelled as well.
///
class Join extends EffectWithResult {
  /// A dictionary of tasks that each is returned by a previous fork.
  final Map<dynamic, Task> tasks;

  /// Creates an instance of a Join effect.
  Join(this.tasks, {JoinResult result}) : super(result: result);

  @override
  void _run(_SagaMiddleware middleware, _TaskCallback cb, _ExecutingContext executingContext) {
    if (tasks.isEmpty) {
      cb.next(arg: <dynamic, dynamic>{});
      return;
    }

    var childCallbacks = _createAllStyleChildCallbacks(tasks, cb);
    for (var key in tasks.keys) {
      _joinSingleTask(executingContext.task, tasks[key], childCallbacks[key]);
    }
  }

  void _joinSingleTask(Task task, Task taskToJoin, _TaskCallback cb) {
    if (taskToJoin.isRunning) {
      var joiner = _TaskJoin(task, cb);
      cb.cancelHandler = () {
        if (taskToJoin.isRunning) (taskToJoin as _Task).joiners.remove(joiner);
      };
      (taskToJoin as _Task).joiners.add(joiner);
    } else {
      if (taskToJoin.isAborted) {
        cb.next(arg: taskToJoin.error, isErr: true);
      } else {
        cb.next(arg: taskToJoin.result);
      }
    }
  }

  @override
  Map<String, dynamic> getDefinition() {
    var kv = <String, dynamic>{};
    kv['type'] = 'Join';
    kv['tasks'] = tasks;
    return kv;
  }
}

/// Result of an [Join] effect
///
/// Its value is a dictionary containing entries for every joined Tasks result.
class JoinResult extends Result<Map<dynamic, dynamic>> {}

Map<dynamic, _TaskCallback> _createAllStyleChildCallbacks(
    Map<dynamic, dynamic> shape, _TaskCallback parentCallback) {
  var keys = shape.keys;
  var totalCount = keys.length;

  var completedCount = 0;
  var completed = false;
  var results = <dynamic, dynamic>{};
  var childCallbacks = <dynamic, _TaskCallback>{};

  var checkEnd = () {
    if (completedCount == totalCount) {
      completed = true;
      parentCallback.next(arg: results);
    }
  };

  for (var key in keys) {
    var chCbAtKey = _TaskCallback(
      ({_TaskCallback invoker, dynamic arg, bool isErr}) {
        if (completed) {
          return;
        }
        if (isErr || _shouldComplete(arg)) {
          parentCallback.cancel();
          parentCallback.next(arg: arg, isErr: isErr);
        } else {
          results[key] = arg;
          completedCount++;
          checkEnd();
        }
      },
      _noop,
    );
    childCallbacks[key] = chCbAtKey;
  }

  parentCallback.cancelHandler = () {
    if (!completed) {
      completed = true;
      for (var key in keys) {
        childCallbacks[key].cancel();
      }
    }
  };

  return childCallbacks;
}
