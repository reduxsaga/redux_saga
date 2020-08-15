# Using Saga Helpers

`redux_saga` provides some helper effects wrapping internal functions to spawn tasks when some specific actions are dispatched to the Store.

The helper functions are built on top of the lower level API. In the advanced section, we'll see how those functions can be implemented.

The first function, `TakeEvery` is the most familiar and provides a behavior similar to `redux-thunk`.

Let's illustrate with the common AJAX example. On each click on a Fetch button we dispatch a `FetchRequested` action. We want to handle this action by launching a task that will fetch some data from the server.

First we create the task that will perform the asynchronous action:

```dart
import 'package:redux_saga/redux_saga.dart';
import 'api.dart';

fetchData(action) sync* {
  yield Try(() sync* {
    var data = Result();
    yield Call(Api.fetchUser, args: [action.payload.url], result: data);
    yield Put(FetchSucceed(data.value));
  }, Catch: (error) sync* {
    yield Put(FetchFailed(error));
  });
}
```

To launch the above task on each `FetchRequested` action:

```dart
import 'package:redux_saga/redux_saga.dart';

watchFetchData() sync* {
  yield TakeEvery(fetchData, pattern: FetchRequested);
}
```

In the above example, `TakeEvery` allows multiple `fetchData` instances to be started concurrently. At a given moment, we can start a new `fetchData` task while there are still one or more previous `fetchData` tasks which have not yet terminated.

If we want to only get the response of the latest request fired (e.g. to always display the latest version of data) we can use the `TakeLatest` helper:

```dart
import 'package:redux_saga/redux_saga.dart';

watchFetchData() sync* {
  yield TakeLatest(fetchData, pattern: FetchRequested);
}
```

Unlike `TakeEvery`, `TakeLatest` allows only one `fetchData` task to run at any moment. And it will be the latest started task. If a previous task is still running when another `fetchData` task is started, the previous task will be automatically cancelled.

If you have multiple Sagas watching for different actions, you can create multiple watchers with those built-in helpers, which will behave like there was `fork` used to spawn them (we'll talk about `fork` later. For now, consider it to be an Effect that allows us to start multiple sagas in the background).

For example:

```dart
import 'package:redux_saga/redux_saga.dart';

// FetchUsers
fetchUsers(action) sync* { ... }

// CreateUser
createUser(action) sync* { ... }

// use them in parallel
rootSaga() sync* {
  yield TakeEvery(fetchUsers, pattern: FetchUsers);
  yield TakeEvery(createUser, pattern: CreateUser);
}
```
