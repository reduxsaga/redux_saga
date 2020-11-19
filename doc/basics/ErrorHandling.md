# Error handling

In this section we'll see how to handle the failure case from the previous example. Let's suppose that our API function `Api.fetch` returns a Future which gets rejected when the remote fetch fails for some reason.

We want to handle those errors inside our Saga by dispatching a `ProductsRequestFailed` action to the Store.

We can catch errors inside the Saga using by `Try` effect like `try/catch` syntax.

```dart
import 'package:redux_saga/redux_saga.dart';
import 'api.dart';

// ...

fetchProducts() sync* {
  yield Try(() sync* {
    var products = Result();
    yield Call(Api.fetch, args: ['/products'], result: products);
    yield Put(ProductsReceived(products.value));
  }, Catch: (e, s) sync* {
    yield Put(ProductsRequestFailed(e));
  });
}
```

In order to test the failure case, we'll use the `Catch` Generator ot the `Try` effect.

```dart
import 'package:redux_saga/redux_saga.dart';
import 'api.dart';
import 'package:test/test.dart';

import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import '../bin/reduxtest.dart';

void main() {
  group('Middleware tests', () {
    test('fetchProducts Saga test', () {
      Iterable gen = fetchProducts();

      var iterator = gen.iterator;

      iterator.moveNext();

      expect(iterator.current, equals(TypeMatcher<Try>()),
          reason: "fetchProducts should return a Try effect");

      //get body iterator
      var iteratorTry = iterator.current.fn().iterator;

      iteratorTry.moveNext();

      expect(iteratorTry.current, equals(TypeMatcher<Call>()),
          reason: "fetchProducts should return a Call effect");

      expect(iteratorTry.current.args, equals(['/products']),
          reason: "Call effect arguments must be './products'");

      iteratorTry.moveNext();

      expect(iteratorTry.current, equals(TypeMatcher<Put>()),
          reason: 'fetchProducts should return a Put effect');

      expect(iteratorTry.current.action, equals(TypeMatcher<ProductsReceived>()),
          reason: "Put must dispatch a 'ProductsReceived' action");

      iteratorTry.moveNext();

      expect(iteratorTry.moveNext(), false, reason: 'fetchProducts Try Saga must be done');

      //get Catch iterator with a fake error
      var iteratorCatch = iterator.current.Catch(Exception('fake'), null).iterator;

      iteratorCatch.moveNext();

      expect(iteratorCatch.current, equals(TypeMatcher<Put>()),
          reason: 'fetchProducts Catch should return a Put effect');

      expect(iteratorCatch.current.action, equals(TypeMatcher<ProductsRequestFailed>()),
          reason: "Put must dispatch a 'ProductsRequestFailed' action");

      iteratorCatch.moveNext();

      expect(iteratorCatch.moveNext(), false, reason: 'fetchProducts Catch Saga must be done');

    });
  });
}

```

In this case, we're call `Catch` method by passing a fake error. Testing of `Try` block is same as testing of `Catch` block.

Of course, you're not forced to handle your API errors inside `Try`/`Catch` blocks. You can also make your API service return a normal value with some error flag on it. For example, you can catch Future rejections and map them to an object with an error field.

```dart
import 'package:redux/redux.dart';
import 'package:redux_saga/redux_saga.dart';

//...

//Mock Api
class Api {
  static Future fetch(url) {
    return Future(() => 'data');
  }
}

class FetchResult {
  final dynamic response;
  final dynamic error;
  final bool success;

  FetchResult({this.response, this.success, this.error});
}

Future<FetchResult> fetchProductsApi() {
  return Api.fetch('/products')
      .then((value) => FetchResult(response: value, success: true))
      .catchError((error) => FetchResult(error: error, success: false));
}

fetchProducts() sync* {
  var products = Result<FetchResult>();
  yield Call(fetchProductsApi, result: products);
  if (products.value.success) {
    yield Put(ProductsReceived(products.value.response));
  } else {
    yield Put(ProductsRequestFailed(products.value.error));
  }
}
```

## onError hook
Errors in forked tasks [bubble up to their parents - Error propagation](https://pub.dev/documentation/redux_saga/latest/redux_saga/Fork-class.html)
until it is caught or reaches the root saga.
If an error propagates to the root saga the whole saga tree is already **terminated**. The preferred approach, in this case, to use [onError hook](https://pub.dev/documentation/redux_saga/latest/redux_saga/Options-class.html) to report an exception, inform a user about the problem and gracefully terminate your app.

Why can't I use `onError` hook as a global error handler?
Usually, there is no one-size-fits-all solution, as exceptions are context dependent. Consider `onError` hook as the last resort that helps you to handle **unexpected** errors.

