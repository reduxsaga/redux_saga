# Beginner Tutorial

## Objectives of this tutorial

This tutorial attempts to introduce redux_saga in a (hopefully) accessible way.

For our getting started tutorial, we are going to use the trivial Counter demo from the Redux repo. The application is quite basic but is a good fit to illustrate the basic concepts of redux_saga without being lost in excessive details.

### The initial setup

Before we start, clone the [tutorial repository](https://github.com/reduxsaga/redux_saga_beginner_tutorial).

Sample application is flutters most basic counter example.

> The final code of this tutorial is located in the `sagas` branch.

Then in the command line, run:

```sh
$ cd redux_saga_beginner_tutorial
$ flutter run
```

We are starting with the most basic use case: 2 buttons to `Increment` and `Decrement` a counter. Later, we will introduce asynchronous calls.

If things go well, you should see 2 buttons `Increment` and `Decrement` along with a message below showing `Counter: 0`.

> In case you encountered an issue with running the application. Feel free to create an issue on the [tutorial repo](https://github.com/reduxsaga/redux_saga_beginner_tutorial/issues).

## Hello Sagas!

We are going to create our first Saga. Following the tradition, we will write our 'Hello, world' version for Sagas.

Create a file `sagas.dart` then add the following snippet:

```dart
helloSaga() sync* {
  print('Hello Sagas!');
}
```

So nothing scary, just a normal function (except for the `sync*`). All it does is print a greeting message into the console.

In order to run our Saga, we need to:

- create a Saga middleware with a list of Sagas to run (so far we have only one `helloSaga`)
- connect the Saga middleware to the Redux store

First we need to add required packages to `pubspec.yaml`:

```yaml
dependencies:
...
  redux_saga: ^1.0.7
```

Then in the command line, run to get packages:

```sh
$ pub get
```

We will make the changes to `main.dart`:

```dart
// ...
import 'package:redux_saga/redux_saga.dart';
import 'sagas.dart';

void main() {
  var sagaMiddleware = createSagaMiddleware();

  // Create store and apply middleware
  final store = Store(
    counterReducer,
    initialState: 0,
    middleware: [applyMiddleware(sagaMiddleware)],
  );

  sagaMiddleware.setStore(store);

  sagaMiddleware.run(helloSaga);

  runApp(MyApp(store: store));
}

// rest unchanged
```

First we import our Saga from the `sagas.dart` module. Then we create a middleware using the factory function `createSagaMiddleware` exported by the `redux_saga` library.

Before running our `helloSaga`, we must connect our middleware to the Store using `applyMiddleware` and `sagaMiddleware.setStore`. Then we can use the `sagaMiddleware.run(helloSaga)` to start our Saga.

So far, our Saga does nothing special. It just logs a message then exits.

## Making Asynchronous calls

Now let's add something closer to the original Counter demo. To illustrate asynchronous calls, we will add another button to increment the counter 1 second after the click.

First we should add a new action named `IncrementAsyncAction` to the `actions.dart`

```dart
//...

class IncrementAsyncAction {}

//...
```

Then, we'll provide an additional button and dispatch an `IncrementAsyncAction` action on button press.

```dart
class MyHomePage extends StatelessWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
            ),
            StoreConnector<dynamic, String>(
              converter: (store) => store.state.toString(),
              builder: (context, count) {
                return new Text(
                  count,
                  style: Theme.of(context).textTheme.headline4,
                );
              },
            ),
            RaisedButton(
              onPressed: () => StoreProvider.of(context).dispatch(IncrementAction()),
              child: Text('Increase'),
            ),
            RaisedButton(
              onPressed: () => StoreProvider.of(context).dispatch(DecrementAction()),
              child: Text('Decrease'),
            ),
            StoreConnector<dynamic, VoidCallback>(
              converter: (store) {
                return () {
                  if (store.state % 2 != 0) {
                    store.dispatch(IncrementAction());
                  }
                };
              },
              builder: (context, callback) {
                return RaisedButton(
                  onPressed: callback,
                  child: Text('IncreamentIfOdd'),
                );
              },
            ),
            //add button here
            RaisedButton(
              onPressed: () => StoreProvider.of(context).dispatch(IncrementAsyncAction()),
              child: Text('IncrementAsync'),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => StoreProvider.of(context).dispatch(IncrementAction()),
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }
}
```

Note that unlike in redux-thunk, our component dispatches a plain object action.

Now we will introduce another Saga to perform the asynchronous call. Our use case is as follows:

> On each `IncrementAsyncAction` action, we want to start a task that will do the following

> - Wait 1 second then increment the counter

Add the following code to the `sagas.dart` module:

```dart
import 'package:redux_saga/redux_saga.dart';
import 'actions.dart';

// ...

Future<bool> delay(Duration duration) {
  return Future<bool>.delayed(duration, () => true);
}

// Our worker Saga: will perform the async increment task
incrementAsync() sync* {
  yield delay(Duration(seconds: 1));
  yield Put(IncrementAction());
}

// Our watcher Saga: spawn a new incrementAsync task on each IncrementAsyncAction
watchIncrementAsync() sync* {
  yield TakeEvery(incrementAsync, pattern: IncrementAsyncAction);
}
```

Time for some explanations.

We create a `delay` function that returns a [Future](https://dart.dev/codelabs/async-await) that will resolve after a specified duration. We'll use this function to *block* the Generator.

Sagas are implemented as [synchronous generator functions](https://dart.dev/guides/language/language-tour#generators) that *yield* objects to the redux_saga middleware. The yielded objects are a kind of instruction to be interpreted by the middleware. When a Future is yielded to the middleware, the middleware will suspend the Saga until the Future completes. In the above example, the `IncrementAsyncAction` Saga is suspended until the Future returned by `delay` resolves, which will happen after 1 second.

Once the Future is resolved, the middleware will resume the Saga, executing code until the next yield. In this example, the next statement is another yielded object: the result of calling `Put(IncrementAction())`, which instructs the middleware to dispatch an `IncrementAction` action.

`Put` is one example of what we call an *Effect*. Effects are plain Dart objects which contain instructions to be fulfilled by the middleware. When a middleware retrieves an Effect yielded by a Saga, the Saga is paused until the Effect is fulfilled.

So to summarize, the `incrementAsync` Saga sleeps for 1 second via the call to `delay(Duration(seconds: 1))`, then dispatches an `IncrementAction` action.

Next, we created another Saga `watchIncrementAsync`. We use `TakeEvery`, a helper function provided by `redux_saga`, to listen for dispatched `IncrementAsyncAction` actions and run `incrementAsync` each time.

Now we have 2 Sagas, and we need to start them both at once. To do that, we'll add a `rootSaga` that is responsible for starting our other Sagas. In the same file `sagas.dart`, refactor the file as follows:

```dart
import 'package:redux_saga/redux_saga.dart';
import 'actions.dart';

helloSaga() sync* {
  print('Hello Sagas!');
}

Future delay(Duration duration) {
  return Future.delayed(duration, () => true);
}

incrementAsync() sync* {
  yield delay(Duration(seconds: 1));
  yield Put(IncrementAction());
}

watchIncrementAsync() sync* {
  yield TakeEvery(incrementAsync, pattern: IncrementAsyncAction);
}

// single entry point to start all Sagas at once
rootSaga() sync* {
  yield All({
    #hello: helloSaga(),
    #watch: watchIncrementAsync(),
  });
}
```

This Saga yields an array with the results of calling our two sagas, `helloSaga` and `watchIncrementAsync`. This means the two resulting Generators will be started in parallel. Now we only have to invoke `sagaMiddleware.run` on the root Saga in `main.dart`.

```dart
// ...

import 'sagas.dart';

void main() {
  var sagaMiddleware = createSagaMiddleware();

  // Create store and apply middleware
  final store = ...

  sagaMiddleware.setStore(store);

  sagaMiddleware.run(rootSaga);

  runApp(MyApp(store: store));
}

// ...
```

To make clear we used a Future returning `delay` function in the tutorial. In a real app you use `yield Delay(Duration(seconds: 1));` instead. `Delay` is a pure saga effect.
Now, lets remove the `delay` function and use effect. To use effect just change the `yield delay(Duration(seconds: 1))` to `Delay(Duration(seconds: 1))` in `incrementAsync` saga. By using effect instead also makes easier to write test for your sagas.

```dart

...

incrementAsync() sync* {
  yield Delay(Duration(seconds: 1));
  yield Put(IncrementAction());
}

...

```

## Making our code testable

First we need to add required packages to `pubspec.yaml`:

```yaml
dev_dependencies:
...
  test: ^1.14.4
```

Then in the command line, run to get packages:

```sh
$ pub get
```

We want to test our `incrementAsync` Saga to make sure it performs the desired task.

Create another file `test\sagas_test.dart`:

```dart
import 'package:redux_saga/redux_saga.dart';
import 'package:redux_saga_beginner_tutorial/actions.dart';
import 'package:redux_saga_beginner_tutorial/sagas.dart';
import 'package:test/test.dart';

void main() {
  group('Middleware Tests', () {
    test('incrementAsync Saga test', () {
      Iterable gen = incrementAsync();

      Iterator iterator = gen.iterator;

       // now what ?
    });
  });
}
```

`incrementAsync` is a generator function. When run, it returns an iterator object, and the iterator's `moveNext` method iterates through effect on every invoke. Effects can be accessed by iterator's `current` method.

```dart
    iterator.moveNext();
    var effect = iterator.current;
```

The `current` method provides the yielded effect,
if there are still more 'yield' expressions then `moveNext` returns true otherwise it returns false;

In the case of `incrementAsync`, the generator yields 2 values consecutively:

1. `yield Delay(Duration(seconds: 1))`
2. `yield Put(IncrementAction())`

So if we invoke the next method of the generator 3 times consecutively we get the following
results:

```dart
iterator.moveNext()       //true
iterator.current          //{type : Delay, duration : 0:00:01.000000, value : null, result : null, }
iterator.moveNext()       //true
iterator.current          //{type : Put, action : Instance of 'IncrementAction',
                          // channel : null, resolve : false, result : null, }
iterator.moveNext()       //false
iterator.current          //null
```

The first 2 invocations return the results of the yield expressions. On the 3rd invocation
since there is no more yield the `moveNext` method returns false. And since the `incrementAsync`

So now, in order to test the logic inside `incrementAsync`, we'll have to iterate
over the returned Generator and check the values yielded by the generator.

```dart
    ...

    test('incrementAsync Saga test', () {
      Iterable gen = incrementAsync();

      Iterator iterator = gen.iterator;

      iterator.moveNext();

      expect(iterator.current, TypeMatcher<Delay>(),
          reason: 'incrementAsync should return a Delay effect');
      expect(iterator.current.duration, Duration(seconds: 1),
          reason: 'Delay effect must resolve after 1 second');


    });

    ...
```

What happens is that the middleware examines the type of each yielded Effect then decides how to fulfill that Effect. If the Effect type is a `Put` then it will dispatch an action to the Store.

This separation between Effect creation and Effect execution makes it possible to test our Generator in a surprisingly easy way:

```dart
    ...

    test('incrementAsync Saga test', () {
      Iterable gen = incrementAsync();

      Iterator iterator = gen.iterator;

      iterator.moveNext();

      expect(iterator.current, TypeMatcher<Delay>(),
          reason: 'incrementAsync should return a Delay effect');
      expect(iterator.current.duration, Duration(seconds: 1),
          reason: 'Delay effect must resolve after 1 second');

      iterator.moveNext();

      expect(iterator.current, TypeMatcher<Put>(),
          reason: 'incrementAsync should return a Put effect');
      expect(iterator.current.action, TypeMatcher<IncrementAction>(),
          reason: 'incrementAsync Saga must dispatch an IncrementAction action');

      expect(iterator.moveNext(), false, reason: 'incrementAsync Saga must be done');
    });

    ...
```

Since `Delay` and `Put` return plain objects, we can reuse the same functions in our test code. And to test the logic of `incrementAsync`, we iterate over the generator and do tests on its values.

In order to run the above test, run:

```sh
$ flutter test test/sagas_test.dart
```

which should report the results on the console.
