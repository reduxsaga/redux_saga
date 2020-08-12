part of redux_saga;

/// Main task and its forked tasks
class _ForkedTasks {
  List<dynamic> tasks;
  _TaskCallback continueCallback;
  Callback onAbort;
  bool completed;
  dynamic result;
  _InternalTask mainTask;

  _ForkedTasks(this.mainTask, this.onAbort, this.continueCallback) {
    tasks = <dynamic>[];
    completed = false;
    addTask(mainTask);
  }

  List<String> getTaskNames() {
    var list = <String>[];

    for (var t in tasks) {
      list.add(t.meta.toString());
    }
    return list;
  }

  void abort(dynamic err) {
    onAbort();
    cancelAll();
    continueCallback.next(arg: err, isErr: true);
  }

  void cancelAll() {
    if (completed) {
      return;
    }
    completed = true;

    for (var t in tasks) {
      t.continueCallback.nextHandler = _noopNext;
      t.cancel();
    }
    tasks = <dynamic>[];
  }

  void addTask(dynamic task) {
    tasks.add(task);
    task.continueCallback = _TaskCallback((
        {_TaskCallback invoker, dynamic arg, bool isErr = false}) {
      if (completed) {
        return;
      }

      tasks.remove(task);
      task.continueCallback.nextHandler = _noopNext;
      if (isErr) {
        abort(arg);
      } else {
        if (task == mainTask) {
          result = task.result;
        }

        if (tasks.isEmpty) {
          completed = true;
          continueCallback.next(arg: result);
        }
      }
    });
  }
}
