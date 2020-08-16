# Task cancellation

We saw already an example of cancellation in the [Non blocking calls](NonBlockingCalls.md) section. In this section we'll review cancellation in more detail.

Once a task is forked, you can abort its execution using `yield Cancel([task])`.

To see how it works, let's consider a basic example: A background sync which can be started/stopped by some UI commands. Upon receiving a `StartBackgroundSync` action, we fork a background task that will periodically sync some data from a remote server.

The task will execute continually until a `StopBackgroundSync` action is triggered. Then we cancel the background task and wait again for the next `StartBackgroundSync` action.

```dart
import 'package:redux_saga/redux_saga.dart';
import 'api.dart';

bgSync() sync* {
  yield Try(() sync* {
    while (true) {
      yield Put(actions.requestStart());
      var result = Result();
      yield Call(someApi, result: result);
      yield Put(actions.requestSuccess(result.value));
      yield Delay(Duration(seconds: 5));
    }
  }, Finally: () sync* {
    var cancelled = Result<bool>();
    yield Cancelled(result: cancelled);
    if (cancelled.value) {
      yield Put(actions.requestFailure('Sync cancelled!'));
    }
  });
}

mainSaga() sync* {
  while (true) {
    yield Take(pattern: StartBackgroundSync);
    // starts the task in the background
    var bgSyncTask = Result<Task>();

    yield Fork(bgSync, result: bgSyncTask);

    // wait for the user stop action
    yield Take(pattern: StopBackgroundSync);

    // user clicked stop. cancel the background task
    // this will cause the forked bgSync task to jump into its finally block
    yield Cancel([bgSyncTask.value]);
  }
}
```

In the above example, cancellation of `bgSyncTask` will cause the Generator to stop and jump directly to the Finally block. Here you can use `yield Cancelled()` to check if the Generator has been cancelled or not.

Cancelling a running task will also cancel the current Effect where the task is blocked at the moment of cancellation.

For example, suppose that at a certain point in an application's lifetime, we have this pending call chain:

```dart
main() sync* {
  var task = Result<Task>();
  yield Fork(subtask, result: task);
  ...
  // later
  yield Cancel([task.value]);
}

subtask() sync* {
  ...
  yield Call(subtask2); // currently blocked on this call
  ...
}

subtask2() sync* {
  ...
  yield Call(someApi); // currently blocked on this call
  ...
}
```

`yield Cancel([task.value])` triggers a cancellation on `subtask`, which in turn triggers a cancellation on `subtask2`.

So we saw that Cancellation propagates downward (in contrast returned values and uncaught errors propagates upward). You can see it as a *contract* between the caller (which invokes the async operation) and the callee (the invoked operation). The callee is responsible for performing the operation. If it has completed (either success or error) the outcome propagates up to its caller and eventually to the caller of the caller and so on. That is, callees are responsible for *completing the flow*.

Now if the callee is still pending and the caller decides to cancel the operation, it triggers a kind of a signal that propagates down to the callee (and possibly to any deep operations called by the callee itself). All deeply pending operations will be cancelled.

There is another direction where the cancellation propagates to as well: the joiners of a task (those blocked on a `yield Join(...)`) will also be cancelled if the joined task is cancelled. Similarly, any potential callers of those joiners will be cancelled as well (because they are blocked on an operation that has been cancelled from outside).

## Testing generators with fork effect

When `Fork` is called it starts the task in the background and also returns task object like we have learned previously. When testing this we can use utility class `CreateMockTask` if needed. Here is test for `mainSaga` generator which is on top of this page.

```dart
test('main Saga test', () {
  Iterable gen = mainSaga();

  var iterator = gen.iterator;

  iterator.moveNext();

  expect(iterator.current, equals(TypeMatcher<Take>()),
      reason: "should return Take effect");

  expect(iterator.current.pattern, equals(StartBackgroundSync),
      reason: "waits for start action");

  iterator.moveNext();

  expect(iterator.current, equals(TypeMatcher<Fork>()),
      reason: "forks the service");

  iterator.moveNext();

  expect(iterator.current, equals(TypeMatcher<Take>()),
      reason: "should return Take effect");

  expect(iterator.current.pattern, equals(StopBackgroundSync),
      reason: "waits for stop action");

  iterator.moveNext();

  expect(iterator.current, equals(TypeMatcher<Cancel>()),
      reason: "should return Cancel effect");
});
```

### Note

It's important to remember that `yield Cancel([tasks])` doesn't wait for the cancelled task to finish (i.e. to perform its finally block). The cancel effect behaves like fork. It returns as soon as the cancel was initiated. Once cancelled, a task should normally return as soon as it finishes its cleanup logic.

## Automatic cancellation

Besides manual cancellation there are cases where cancellation is triggered automatically

1. In a `Race` effect. All race competitors, except the winner, are automatically cancelled.

2. In a parallel effect (`yield All({...})`). The parallel effect is rejected as soon as one of the sub-effects is rejected (as implied by `Future.wait`). In this case, all the other sub-effects are automatically cancelled.
