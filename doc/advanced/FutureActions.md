# Pulling future actions

Until now we've used the helper effect `TakeEvery` in order to spawn a new task on each incoming action. This mimics somewhat the behavior of `redux-thunk`: each time a Component, for example, invokes a `fetchProducts` Action Creator, the Action Creator will dispatch a thunk to execute the control flow.

In reality, `TakeEvery` is just a wrapper effect for internal helper function built on top of the lower-level and more powerful API. In this section we'll see a new Effect, `Take`, which makes it possible to build complex control flow by allowing total control of the action observation process.

## A basic logger

Let's take a basic example of a Saga that watches all actions dispatched to the store and logs them to the console.

Using `TakeEvery(pattern: '*')` (with the wildcard `*` pattern), we can catch all dispatched actions regardless of their types.

```dart
watchAndLog() sync* {
  yield TakeEvery(({action}) sync* {
    var state = Result();
    yield Select(result: state);

    print('action : $action');
    print('state after : ${state.value}');
  }, pattern: '*');
}
```

Now let's see how to use the `Take` Effect to implement the same flow as above:

```dart
watchAndLog() sync* {
  while (true) {
    var action = Result();
    yield Take(pattern: '*', result: action);

    var state = Result();
    yield Select(result: state);

    print('action : $action');
    print('state after : ${state.value}');
  }
}
```

The `Take` is just like `Call` and `Put` we saw earlier. It creates another command object that tells the middleware to wait for a specific action. The resulting behavior of the `Call` Effect is the same as when the middleware suspends the Generator until a Future resolves. In the `Take` case, it'll suspend the Generator until a matching action is dispatched. In the above example, `watchAndLog` is suspended until any action is dispatched.

Note how we're running an endless loop `while (true)`. Remember, this is a Generator function, which doesn't have a run-to-completion behavior. Our Generator will block on each iteration waiting for an action to happen.

Using `Take` has a subtle impact on how we write our code. In the case of `TakeEvery`, the invoked tasks have no control on when they'll be called. They will be invoked again and again on each matching action. They also have no control on when to stop the observation.

In the case of `Take`, the control is inverted. Instead of the actions being *pushed* to the handler tasks, the Saga is *pulling* the action by itself. It looks as if the Saga is performing a normal function call `action = getNextAction()` which will resolve when the action is dispatched.

This inversion of control allows us to implement control flows that are non-trivial to do with the traditional *push* approach.

As a basic example, suppose that in our Todo application, we want to watch user actions and show a congratulation message after the user has created their first three todos.

```dart
watchFirstThreeTodosCreation() sync* {
  for (var i = 0; i < 3; i++) {
    var action = Result();
    yield Take(pattern: TodoCreated, result: action);
  }
  yield Put(ShowCongratulation());
}
```

Instead of a `while (true)`, we're running a `for` loop, which will iterate only three times. After taking the first three `TodoCreted` actions, `watchFirstThreeTodosCreation` will cause the application to display a congratulation message then terminate. This means the Generator will be garbage collected and no more observation will take place.

Another benefit of the pull approach is that we can describe our control flow using a familiar synchronous style. For example, suppose we want to implement a login flow with two actions: `Login` and `Logout`. Using `TakeEvery` (or `redux-thunk`), we'll have to write two separate tasks (or thunks): one for `Login` and the other for `Logout`.

The result is that our logic is now spread in two places. In order for someone reading our code to understand it, they would have to read the source of the two handlers and make the link between the logic in both in their head. In other words, it means they would have to rebuild the model of the flow in their head by rearranging mentally the logic placed in various places of the code in the correct order.

Using the pull model, we can write our flow in the same place instead of handling the same action repeatedly.

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

The `loginFlow` Saga more clearly conveys the expected action sequence. It knows that the `Login` action should always be followed by a `Logout` action, and that `Logout` is always followed by a `Login` (a good UI should always enforce a consistent order of the actions, by hiding or disabling unexpected actions).
