# Declarative Effects

In `redux_saga`, Sagas are implemented using Generator functions. To express the Saga logic, we yield plain objects from the Generator. We call those objects [*Effects*](/doc/effects/README.md). An Effect is an object that contains some information to be interpreted by the middleware. You can view Effects like instructions to the middleware to perform some operation (e.g., invoke some asynchronous function, dispatch an action to the store, etc.).

In this section and the following, we will introduce some basic Effects. And see how the concept allows the Sagas to be easily tested.

Sagas can yield Effects in multiple forms. The easiest way is to yield a Future.

For example suppose we have a Saga that watches a `ProductsRequested` action. On each matching action, it starts a task to fetch a list of products from a server.

```dart
import 'package:redux_saga/redux_saga.dart';
import 'api.dart';

watchFetchProducts() sync* {
  yield TakeEvery(fetchProducts, pattern: ProductsRequested);
}

fetchProducts({dynamic action}) sync* {
  var products = Result();
  yield Call(() => Api.fetch('/products'), result: products);
  print(products.value);
}
```

In the example above, we are invoking `Api.fetch` using Call effect inside the Generator (In Generator functions, any expression at the right of `yield` is evaluated then the result is yielded to the caller).

`Api.fetch('/products')` triggers an AJAX request and returns a Future that will resolve with the resolved response, the AJAX request will be executed immediately. Simple and idiomatic, but...

Suppose we want to test the generator above:

```dart
    Iterable gen = fetchProducts();
    Iterator iterator = gen.iterator;
    iterator.moveNext();
    expect(iterator.current, ??) // what do we expect ?
```

We want to check the result of the first value yielded by the generator. In our case it's the result of running `Api.fetch('/products')` which is a Future . Executing the real service during tests is neither a viable nor practical approach, so we have to *mock* the `Api.fetch` function, i.e. we'll have to replace the real function with a fake one which doesn't actually run the AJAX request but only checks that we've called `Api.fetch` with the right arguments (`'/products'` in our case).

Mocks make testing more difficult and less reliable. On the other hand, functions that return values are easier to test, since we can use a simple `equals()` to check the result. This is the way to write the most reliable tests.

Not convinced? I encourage you to read [Eric Elliott's article](https://medium.com/javascript-scene/what-every-unit-test-needs-f6cd34d9836d#.4ttnnzpgc):

> (...)`equals()`, by nature answers the two most important questions every unit test must answer,
but most don’t:
- What is the actual output?
- What is the expected output?
>
> If you finish a test without answering those two questions, you don’t have a real unit test. You have a sloppy, half-baked test.

What we actually need to do is make sure the `fetchProducts` task yields a call with the right function and the right arguments.

Instead of invoking the asynchronous function directly from inside the Generator, **we can yield only a description of the function invocation**. i.e. We'll yield an object which looks like

```dart
// Effect -> call the function Api.fetch with `./products` as argument
Call(Api.fetch, args: ['./products'])
```

Put another way, the Generator will yield plain Objects containing *instructions*, and the `redux_saga` middleware will take care of executing those instructions and giving back the result of their execution to the Generator. This way, when testing the Generator, all we need to do is to check that it yields the expected instruction by doing a simple `equals` on the yielded Object.

For this reason, the library provides a different way to perform asynchronous calls.

```dart
import 'package:redux_saga/redux_saga.dart';
import 'api.dart';

fetchProducts({dynamic action}) sync* {
  var products = Result();
  yield Call(Api.fetch, args: ['/products'], result: products);
  // ...
}
```

We're using now the `Call` object. **The difference from the preceding example is that now we're not executing the fetch call immediately, instead, `Call` creates a description of the effect**. Just as in Redux you use action creators to create a plain object describing the action that will get executed by the Store, `Call` creates a plain object describing the function call. The redux_saga middleware takes care of executing the function call and resuming the generator with the resolved response.

This allows us to easily test the Generator outside the Redux environment. Because `Call` is just a function which returns a plain Object.

```dart
import 'package:redux_saga/redux_saga.dart';
import 'api.dart';
import 'package:test/test.dart';

void main() {
  group('Middleware tests', () {
    test('fetchProducts Saga test', () {
      Iterable gen = fetchProducts();

      Iterator iterator = gen.iterator;

      iterator.moveNext();

      expect(iterator.current, equals(TypeMatcher<Call>()),
          reason: "fetchProducts should return a Call effect");

      expect(iterator.current.args, equals(['/products']),
          reason: "Call effect arguments must be '/products'");

      iterator.moveNext();

      expect(iterator.moveNext(), false, reason: 'fetchProducts Saga must be done');
    });
  });
}
```

Now we don't need to mock anything, and a basic equality test will suffice.

The advantage of those *declarative calls* is that we can test all the logic inside a Saga by iterating over the Generator and doing an `equals` test on the values yielded successively. This is a real benefit, as your complex asynchronous operations are no longer black boxes, and you can test in detail their operational logic no matter how complex it is.

`Call` is well suited for functions that return Future results. Another effect `Cps` can be used to handle Node style functions (e.g. `fn(callback, args: [...])` where `callback` is of the form `CPSCallback cb`). `Cps` stands for Continuation Passing Style.

For example:

```dart
import 'package:redux_saga/redux_saga.dart';

var content = Result();
yield CPS(readFile, args: ['/path/to/file'], result: content);
```

And of course you can test it just like you test `Call`:

```dart
import 'package:redux_saga/redux_saga.dart';
import 'api.dart';
import 'package:test/test.dart';

void main() {
  group('Middleware tests', () {
    test('fetchSaga Saga test', () {
      Iterable gen = fetchSaga();

      Iterator iterator = gen.iterator;

      iterator.moveNext();

      expect(iterator.current, equals(TypeMatcher<CPS>()),
          reason: "fetchSaga should return a CPS effect");

      expect(iterator.current.args, equals(['/path/to/file']),
          reason: "Call effect arguments must be '/path/to/file'");

      iterator.moveNext();

      expect(iterator.moveNext(), false, reason: 'fetchSaga Saga must be done');
    });
  });
}
```

`CPS` also supports the same method invocation form as `Call`.

A full list of declarative effects can be found in the [API Reference](https://pub.dev/documentation/redux_saga).

