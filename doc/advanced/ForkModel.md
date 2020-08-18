# redux_saga's fork model

In `redux_saga` you can dynamically fork tasks that execute in the background using 2 Effects

- `Fork` is used to create *attached forks*
- `Spawn` is used to create *detached forks*

## Attached forks (using `Fork`)

Attached forks remain attached to their parent by the following rules

### Completion

- A Saga terminates only after
  - It terminates its own body of instructions
  - All attached forks are themselves terminated

For example say we have the following

```dart
import 'package:redux_saga/redux_saga.dart';
import 'api.dart';

fetchAll() sync* {
  var task1 = Result<Task>();
  yield Fork(fetchResource, args: ['users'], result: task1);

  var task2 = Result<Task>();
  yield Fork(fetchResource, args: ['comments'], result: task2);
  yield Delay(Duration(seconds: 1));
}

fetchResource(resource) sync* {
  var data = Result();
  yield Call(api.fetch, args: [resource], result: data);
  yield Put(ReceiveData(data));
}

mainSaga() sync* {
  yield Call(fetchAll);
}
```

`Call(fetchAll)` will terminate after:

- The `fetchAll` body itself terminates, this means all 3 effects are performed. Since `Fork` effects are non blocking, the
task will block on `Delay(Duration(seconds: 1))`

- The 2 forked tasks terminate, i.e. after fetching the required resources and putting the corresponding `receiveData` actions

So the whole task will block until a delay of 1 second passed *and* both `task1` and `task2` finished their business.

Say for example, the delay of 1 second elapsed and the 2 tasks haven't yet finished, then `fetchAll` will still wait
for all forked tasks to finish before terminating the whole task.

The attentive reader might have noticed the `fetchAll` saga could be rewritten using the parallel Effect

```dart
fetchAll() sync* {
  var result = AllResult();
  yield All({
    #task1: Call(fetchResource, args: ['users']),
    #task2: Call(fetchResource, args: ['comments']),
    #delay: Delay(Duration(seconds: 1)),
  }, result: result);
}
```

In fact, attached forks share the same semantics with the parallel Effect:

- We're executing tasks in parallel
- The parent will terminate after all launched tasks terminate

And this applies for all other semantics as well (error and cancellation propagation). You can understand how
attached forks behave by considering it as a *dynamic parallel* Effect.

## Error propagation

Following the same analogy, Let's examine in detail how errors are handled in parallel Effects

for example, let's say we have this Effect

```dart
  yield All({
    #task1: Call(fetchResource, args: ['users']),
    #task2: Call(fetchResource, args: ['comments']),
    #delay: Delay(Duration(seconds: 1)),
  });
```

The above effect will fail as soon as any one of the 3 child Effects fails. Furthermore, the uncaught error will cause
the parallel Effect to cancel all the other pending Effects. So for example if `Call(fetchResource, args: ['users'])` raises an
uncaught error, the parallel Effect will cancel the 2 other tasks (if they are still pending) then aborts itself with the
same error from the failed call.

Similarly for attached forks, a Saga aborts as soon as

- Its main body of instructions throws an error

- An uncaught error was raised by one of its attached forks

So in the previous example

```dart

//...

fetchAll() sync* {
  var result = AllResult();
  yield All({
    #task1: Call(fetchResource, args: ['users']),
    #task2: Call(fetchResource, args: ['comments']), // task2,
    #delay: Delay(Duration(seconds: 1)),
  }, result: result);
}

fetchResource(resource) sync* {
  var data = Result();
  yield Call(api.fetch, args: [resource], result: data);
  yield Put(ReceiveData(data));
}

mainSaga() sync* {
  yield Try(() sync* {
    yield Call(fetchAll);
  }, Catch: (e) sync* {
    // handle fetchAll errors
  });
}
```

If at a moment, for example, `fetchAll` is blocked on the `Delay(Duration(seconds: 1))` Effect, and say, `task1` failed, then the whole
`fetchAll` task will fail causing

- Cancellation of all other pending tasks. This includes:
  - The *main task* (the body of `fetchAll`): cancelling it means cancelling the current Effect `Delay(Duration(seconds: 1))`
  - The other forked tasks which are still pending. i.e. `task2` in our example.

- The `Call(fetchAll)` will raise itself an error which will be caught in the `Catch` body of `mainSaga`

Note we're able to catch the error from `Call(fetchAll)` inside `mainSaga` only because we're using a blocking call. And that
we can't catch the error directly from `fetchAll`. This is a rule of thumb, **you can't catch errors from forked tasks**. A failure
in an attached fork will cause the forking parent to abort (Just like there is no way to catch an error *inside* a parallel Effect, only from
outside by blocking on the parallel Effect).


## Cancellation

Cancelling a Saga causes the cancellation of:

- The *main task* this means cancelling the current Effect where the Saga is blocked

- All attached forks that are still executing


**WIP**

## Detached forks (using `Spawn`)

Detached forks live in their own execution context. A parent doesn't wait for detached forks to terminate. Uncaught
errors from spawned tasks are not bubbled up to the parent. And cancelling a parent doesn't automatically cancel detached
forks (you need to cancel them explicitly).

In short, detached forks behave like root Sagas started directly using the `middleware.run` API.


**WIP**
