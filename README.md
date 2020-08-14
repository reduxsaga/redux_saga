# redux_saga

`redux_saga` for dart and flutter is a library that aims to make application side effects (i.e. asynchronous things like data fetching and impure things like accessing the browser cache) easier to manage, more efficient to execute, easy to test, and better at handling failures.

The mental model is that a saga is like a separate thread in your application that's solely responsible for side effects. `redux_saga` is a redux middleware, which means this thread can be started, paused and cancelled from the main application with normal redux actions, it has access to the full redux application state and it can dispatch redux actions as well.

It uses synchronous generator functions to make those asynchronous flows easy to read, write and test. By doing so, these asynchronous flows look like your standard synchronous code. (kind of like `async`/`await`, but generators have a few more awesome features we need)

You might've used `redux_thunk` before to handle your data fetching. Contrary to redux thunk, you don't end up in callback hell, you can test your asynchronous flows easily and your actions stay pure.

`redux_saga` is ported and compatible with javascript redux-saga implementation and its documentation. If you use Javascript redux-saga before than you can check [Migration from Javascript](/doc/migration/README.md) documentation to get help about migration.

### Usage Example

Suppose we have a UI to fetch some user data from a remote server when a button is clicked. (For brevity, we'll just show the action triggering code.)

```dart
class MyComponent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    ...
    RaisedButton(
      onPressed: () => StoreProvider.of(context).dispatch(UserFetchRequested()),
      child: Text('Fetch Users'),
    )
    ...
    );
  }
}
```

The Component dispatches a plain Object action to the Store. We'll create a Saga that watches for all `UserFetchRequested` actions and triggers an API call to fetch the user data.

#### `sagas.dart`

```dart
import 'package:redux_saga/redux_saga.dart';
import 'Api.dart';

// worker Saga: will be fired on UserFetchRequested actions
fetchUser(action) sync* {
  yield Try(() sync* {
    var user = Result();
    yield Call(Api.fetchUser, args: [action.payload.userId], result: user);
    yield Put(UserFetchSuceeded(user: user.value));
  }, Catch: (e) sync* {
    yield Put(UserFetchFailed(message: e.message));
  });
}


//  Starts fetchUser on each dispatched `UserFetchRequested` action.
//  Allows concurrent fetches of user.
mySaga() sync* {
  yield TakeEvery(fetchUser, pattern: UserFetchRequested);
}


//  Alternatively you may use TakeLatest.
//
//  Does not allow concurrent fetches of user. If "UserFetchRequested" gets
//  dispatched while a fetch is already pending, that pending fetch is cancelled
//  and only the latest one will be run.
mySaga() sync* {
  yield TakeLatest(fetchUser, pattern: UserFetchRequested);
}

```

To run our Saga, we'll have to connect it to the Redux Store using the `redux_saga` middleware.

#### `main.dart`

```dart
import 'package:redux/redux.dart';
import 'package:redux_saga/redux_saga.dart';

// create the saga middleware
var sagaMiddleware = createSagaMiddleware();

// Create store and apply middleware
final store = Store(
    counterReducer,
    initialState: 0,
    middleware: [applyMiddleware(sagaMiddleware)],
);

//connect to store
sagaMiddleware.setStore(store);

// then run the saga
sagaMiddleware.run(mySaga);

// render the application
```

### Documentation

* [Introduction](/doc/introduction/README.md)
  * [Beginner Tutorial](/doc/introduction/BeginnerTutorial.md)
  * [Saga background](/doc/introduction/SagaBackground.md)
* [Basic Concepts](/doc/basics/README.md)
  * [Using Saga Helpers](/doc/basics/UsingSagaHelpers.md)
  * [Declarative Effects](/doc/basics/DeclarativeEffects.md)
  * [Dispatching actions](/doc/basics/DispatchingActions.md)
  * [Error handling](/doc/basics/ErrorHandling.md)
  * [A common abstraction: Effect](/doc/basics/Effect.md)
* [Migration from Javascript](/doc/migration/README.md)
* [API Reference](https://pub.dev/documentation/redux_saga)

### Examples

#### Vanilla Counter

Web based counter demo.

[vanilla_counter](https://github.com/reduxsaga/vanilla_counter)

#### Counter

Demo using `flutter` and high-level API `TakeEvery`.

[counter](https://github.com/reduxsaga/counter)

#### Shopping Cart

A basic shopping cart example using `flutter`.

[shopping_cart](https://github.com/reduxsaga/shopping_cart)

#### Async App

A demo using async functions to fetch reddit posts.

[async_app](https://github.com/reduxsaga/async_app)

### License
Copyright (c) 2020 Bilal Uslu.

Licensed under The MIT License (MIT).

