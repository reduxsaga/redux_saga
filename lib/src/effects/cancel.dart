part of redux_saga;

///  If [tasks] provided then creates an Effect description that instructs the middleware to cancel
///  a previously forked tasks, otherwise creates an Effect description that instructs the middleware
///  to cancel a task in which it has been yielded (self-cancellation). Self-cancellation allows to reuse
///  destructor-like logic inside a `Finally` blocks.
///
///  - [tasks] is a list of tasks that each member is returned by a previous [Fork].
///
///  ### Notes
///
///  To cancel a running task, the middleware will stop underlying Generator object. This will cancel
///  the current Effect in the task and jump to the finally block (if defined).
///
///  Inside the finally block, you can execute any cleanup logic or dispatch some action to keep the
///  store in a consistent state (e.g. reset the state of a spinner to false when an ajax request
///  is cancelled). You can check inside the finally block if a Saga was cancelled by issuing
///  a `yield Cancelled()`.
///
///  Cancellation propagates downward to child sagas. When cancelling a task, the middleware will also
///  cancel the current Effect (where the task is currently blocked). If the current Effect
///  is a call to another Saga, it will be also cancelled. When cancelling a Saga, all *attached
///  forks* (sagas forked using `yield Fork()`) will be cancelled. This means that cancellation
///  effectively affects the whole execution tree that belongs to the cancelled task.
///
///  `Cancel` is a non-blocking Effect. i.e. the Saga executing it will resume immediately after
///  performing the cancellation.
///
///  For functions which return Future results, you can plug your own cancellation logic
///  by using [FutureWithCancel] type.
///
///  The following example shows how to attach cancellation logic to a Future result:
///
///```
///  import 'package:redux_saga/redux_saga.dart';
///  import 'Api.dart';
///
///  //...
///
///  myApi() {
///    Future result = myXhr(...);
///
///    var cancelCallback = () {
///      myXhr.abort();
///    };
///
///    return FutureWithCancel(result, cancelCallback);
///  }
///
///  mySaga() sync* {
///    var task = Result<Task>();
///    yield Fork(myApi, result: task);
///
///    // ... later
///    // will call cancelCallback on the result of myApi
///    yield Cancel([task.value]);
///  }
///```
///
/// The following example shows how to self-cancel task and check cancellation
/// if task is cancelled at finally block.
///
///```
///  import 'package:redux_saga/redux_saga.dart';
///  import 'Api.dart';
///
///  //...
///
///  deleteRecord({ payload }) sync* {
///    yield Try(() sync* {
///      var result = Result();
///      yield Call(prompt, result: result);
///      if (result.value == confirm) {
///        yield Put(DeleteRecord('confirm', payload));
///      }
///      if (result.value == deny) {
///        yield Cancel();
///      }
///    }, Catch: (e) {
///      // handle failure
///    }, Finally: () sync* {
///      var cancelled = Result();
///      yield Cancelled(result: cancelled);
///      if (cancelled.value) {
///        // shared cancellation logic
///        yield Put(DeleteRecord('cancel', payload));
///      }
///    });
///  }
///```
///
class Cancel extends Effect {
  /// List of tasks to cancel.
  final List<Task> tasks;

  /// Creates an instance of a Cancel effect.
  Cancel([this.tasks]) : super();

  @override
  void _run(_SagaMiddleware middleware, _TaskCallback cb, _ExecutingContext executingContext) {
    if (tasks == null) {
      _cancelSingleTask(executingContext.task);
    } else {
      tasks.forEach(_cancelSingleTask);
    }
    cb.next();
    // cancel effects are non cancellables
  }

  void _cancelSingleTask(Task task) {
    if (task.isRunning) {
      task.cancel();
    }
  }

  @override
  Map<String, dynamic> getDefinition() {
    var kv = <String, dynamic>{};
    kv['type'] = 'Cancel';
    kv['tasks'] = tasks;
    return kv;
  }
}
