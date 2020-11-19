# Non-blocking calls

In the previous section, we saw how the `Take` Effect allows us to better describe a non-trivial flow in a central place.

Revisiting the login flow example:

```dart
loginFlow() sync* {
  while (true) {
    yield Take(pattern: Login);
    // ... perform the login logic
    yield Take(pattern: Logout);
    // ... perform the logout logic
  }
}
```

Let's complete the example and implement the actual login/logout logic. Suppose we have an API which permits us to authorize the user on a remote server. If the authorization is successful, the server will return an authorization token which will be stored by our application using DOM storage (assume our API provides another service for DOM storage).

When the user logs out, we'll delete the authorization token stored previously.

### First try

So far we have all Effects needed to implement the above flow. We can wait for specific actions in the store using the `Take` Effect. We can make asynchronous calls using the `Call` Effect. Finally, we can dispatch actions to the store using the `Put` Effect.

Let's give it a try:

> Note: the code below has a subtle issue. Make sure to read the section until the end.

```dart
import 'package:redux_saga/redux_saga.dart';
import 'api.dart';

authorize(user, password) sync* {
  yield Try(() sync* {
    var token = Result();
    yield Call(Api.authorize, args: [user, password], result: token);
    yield Put(LoginSuccess(token.value));
    yield Return(token);
  }, Catch: (e, s) sync* {
    yield Put(LoginError(e));
  });
}

loginFlow() sync* {
  while (true) {
    var credentials = Result<Credentials>();
    yield Take(pattern: LoginRequest, result: credentials);
    var token = Result<Token>();
    yield Call(authorize, args: [credentials.value.user, credentials.value.password], result: token);
    if (token.value.success) {
      yield Call(Api.storeItem, args: [token.value]);
      yield Take(pattern: Logout);
      yield Call(Api.clearItem, args: ['token']);
    }
  }
}
```

First, we created a separate Generator `authorize` which will perform the actual API call and notify the Store upon success.

The `loginFlow` implements its entire flow inside a `while (true)` loop, which means once we reach the last step in the flow (`Logout`) we start a new iteration by waiting for a new `LoginRequest` action.

`loginFlow` first waits for a `LoginRequest` action. Then, it retrieves the credentials in the action payload (`user` and `password`) and makes a `Call` to the `authorize` task.

As you noted, `Call` isn't only for invoking functions returning Futures. We can also use it to invoke other Generator functions. In the above example, **`loginFlow` will wait for authorize until it terminates and returns** (i.e. after performing the api call, dispatching the action and then returning the token to `loginFlow`).

If the API call succeeds, `authorize` will dispatch a `LoginSuccess` action then return the fetched token. If it results in an error, it'll dispatch a `LoginError` action.

If the call to `authorize` is successful, `loginFlow` will store the returned token in the DOM storage and wait for a `Logout` action. When the user logs out, we remove the stored token and wait for a new user login.

If the `authorize` failed, it'll return `success` false, which will cause `loginFlow` to skip the previous process and wait for a new `LoginRequest` action.

Observe how the entire logic is stored in one place. A new developer reading our code doesn't have to travel between various places to understand the control flow. It's like reading a synchronous algorithm: steps are laid out in their natural order. And we have functions which call other functions and wait for their results.

### But there is still a subtle issue with the above approach

Suppose that when the `loginFlow` is waiting for the following call to resolve:

```dart
loginFlow() sync* {
  while (true) {
    // ...
    yield Try(() sync* {
      var token = Result<Token>();
      yield Call(authorize, args: [credentials.value.user, credentials.value.password], result: token);
      // ...
    });
    // ...
  }
}
```

The user clicks on the `Logout` button causing a `Logout` action to be dispatched.

The following example illustrates the hypothetical sequence of the events:

```
UI                              loginFlow
--------------------------------------------------------
LoginRequest....................call authorize.......... waiting to resolve
........................................................
........................................................
Logout.................................................. missed!
........................................................
................................authorize returned...... dispatch a `LoginSuccess`!!
........................................................
```

When `loginFlow` is blocked on the `authorize` call, an eventual `Logout` occurring in between the call and the response will be missed, because `loginFlow` hasn't yet performed the `yield Take(pattern: Logout)`.

The problem with the above code is that `Call` is a blocking Effect. i.e. the Generator can't perform/handle anything else until the call terminates. But in our case we do not only want `loginFlow` to execute the authorization call, but also watch for an eventual `Logout` action that may occur in the middle of this call. That's because `Logout` is *concurrent* to the `authorize` call.

So what's needed is some way to start `authorize` without blocking so `loginFlow` can continue and watch for an eventual/concurrent `Logout` action.

To express non-blocking calls, the library provides another Effect: [`Fork`](https://pub.dev/documentation/redux_saga/latest/redux_saga/Fork-class.html). When we fork a *Task*, the task is started in the background and the caller can continue its flow without waiting for the forked task to terminate.

So in order for `loginFlow` to not miss a concurrent `Logout`, we must not `Call` the `authorize` task, instead we have to `Fork` it.

```dart
loginFlow() sync* {
  while (true) {
    // ...
    yield Try(() sync* {
      // non-blocking call, what's the returned value here ?
      var result = Result();
      yield Fork(authorize, args: [credentials.value.user, credentials.value.password], result: result);
      // ...
    });
    // ...
  }
}

```

The issue now is since our `authorize` action is started in the background, we can't get the `token` result (because we'd have to wait for it). So we need to move the token storage operation into the `authorize` task.

```dart
import 'package:redux_saga/redux_saga.dart';
import 'api.dart';

authorize(user, password) sync* {
  yield Try(() sync* {
    var token = Result();
    yield Call(Api.authorize, args: [user, password], result: token);
    yield Put(LoginSuccess(token.value));
    yield Call(Api.storeItem, args: [token.value]);
    yield Return(token);
  }, Catch: (e, s) sync* {
    yield Put(LoginError(e));
  });
}

loginFlow() sync* {
  while (true) {
    var credentials = Result<Credentials>();
    yield Take(pattern: LoginRequest, result: credentials);
    yield Fork(authorize, args: [credentials.value.user, credentials.value.password]);

    yield Take(pattern: [Logout, LoginError]);
    yield Call(Api.clearItem, args: ['token']);
  }
}
```

We're also doing `yield Take(pattern: [Logout, LoginError])`. It means we are watching for 2 concurrent actions:

- If the `authorize` task succeeds before the user logs out, it'll dispatch a `LoginSuccess` action, then terminate. Our `loginFlow` saga will then wait only for a future `Logout` action (because `LoginError` will never happen).

- If the `authorize` fails before the user logs out, it will dispatch a `LoginError` action, then terminate. So `loginFlow` will take the `LoginError` before the `Logout` then it will enter in a another `while` iteration and will wait for the next `LoginRequest` action.

- If the user logs out before the `authorize` terminates, then `loginFlow` will take a `Logout` action and also wait for the next `LoginRequest`.

Note the call for `Api.clearItem` is supposed to be idempotent. It'll have no effect if no token was stored by the `authorize` call. `loginFlow` makes sure no token will be in the storage before waiting for the next login.

But we're not yet done. If we take a `Logout` in the middle of an API call, we have to **cancel** the `authorize` process, otherwise we'll have 2 concurrent tasks evolving in parallel: The `authorize` task will continue running and upon a successful (resp. failed) result, will dispatch a `LoginSuccess` (resp. a `LoginError`) action leading to an inconsistent state.

In order to cancel a forked task, we use a dedicated Effect [`Cancel`](https://pub.dev/documentation/redux_saga/latest/redux_saga/Cancel-class.html)

```dart

// ...

loginFlow() sync* {
  while (true) {
    var credentials = Result<Credentials>();
    yield Take(pattern: LoginRequest, result: credentials);

    // fork returns a Task object
    var task=Result<Task>();
    yield Fork(authorize, args: [credentials.value.user, credentials.value.password], result: task);

    var action=Result();
    yield Take(pattern: [Logout, LoginError], result: action);

    if (action.value is Logout) {
      yield Cancel([task.value]);
    }

    yield Call(Api.clearItem, args: ['token']);
  }
}
```

`yield Fork` results in a [Task Object](https://pub.dev/documentation/redux_saga/latest/redux_saga/Task-class.html). We assign the returned object into a local constant `task`. Later if we take a `Logout` action, we pass that task to the `Cancel` Effect. If the task is still running, it'll be aborted. If the task has already completed then nothing will happen and the cancellation will result in a no-op. And finally, if the task completed with an error, then we do nothing, because we know the task already completed.

We are *almost* done (concurrency is not that easy; you have to take it seriously).

Suppose that when we receive a `LoginRequest` action, our reducer sets some `isLoginPending` flag to true so it can display some message or spinner in the UI. If we get a `Logout` in the middle of an API call and abort the task by *killing it* (i.e. the task is stopped right away), then we may end up again with an inconsistent state. We'll still have `isLoginPending` set to true and our reducer will be waiting for an outcome action (`LoginSuccess` or `LoginError`).

Fortunately, the `Cancel` Effect won't brutally kill our `authorize` task. Instead, it'll give it a chance to perform its cleanup logic. The cancelled task can handle any cancellation logic (as well as any other type of completion) in its `Finally` block. Since a finally block execute on any type of completion (normal return, error, or forced cancellation), there is an Effect `Cancelled` which you can use if you want handle cancellation in a special way:

```dart
import 'package:redux_saga/redux_saga.dart';
import 'api.dart';

authorize(user, password) sync* {
  yield Try(() sync* {
    var token = Result();
    yield Call(Api.authorize, args: [user, password], result: token);
    yield Put(LoginSuccess(token.value));
    yield Call(Api.storeItem, args: [token.value]);
    yield Return(token);
  }, Catch: (e, s) sync* {
    yield Put(LoginError(e));
  }, Finally: () sync* {
    var cancelled = Result<bool>();
    yield Cancelled(result: cancelled);
    if (cancelled.value) {
      // ... put special cancellation handling code here
    }
  });
}
```

You may have noticed that we haven't done anything about clearing our `isLoginPending` state. For that, there are at least two possible solutions:

- dispatch a dedicated action `ResetLoginPending`
- make the reducer clear the `isLoginPending` on a `Logout` action
