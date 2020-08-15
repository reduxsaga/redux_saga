# Dispatching actions to the store

Taking the previous example further, let's say that after each save, we want to dispatch some action
to notify the Store that the fetch has succeeded (we'll omit the failure case for the moment).

We could pass the Store's `dispatch` function to the Generator. Then the
Generator could invoke it after receiving the fetch response:

```dart
// ...

fetchProducts(dispatch) sync* {
  var products = Result();
  yield Call(Api.fetch, args: ['/products'], result: products);
  dispatch(ProductsReceived(products.value));
}
```

However, this solution has the same drawbacks as invoking functions directly from inside the Generator (as discussed in the previous section). If we want to test that `fetchProducts` performs
the dispatch after receiving the AJAX response, we'll need again to mock the `dispatch`
function.

Instead, we need the same declarative solution. Create an Object to instruct the
middleware that we need to dispatch some action, and let the middleware perform the real
dispatch. This way we can test the Generator's dispatch in the same way: by inspecting
the yielded Effect and making sure it contains the correct instructions.

The library provides, for this purpose, another function `Put` which creates the dispatch
Effect.

```dart
import 'package:redux_saga/redux_saga.dart';

// ...

fetchProducts() sync* {
  var products = Result();
  yield Call(Api.fetch, args: ['/products'], result: products);
  // create and yield a dispatch Effect
  yield Put(ProductsReceived(products.value));
}
```

Now, we can test the Generator easily as in the previous section

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
          reason: "Call effect arguments must be './products'");

      iterator.moveNext();

      expect(iterator.current, equals(TypeMatcher<Put>()),
          reason: "fetchProducts should return a Put effect");

      expect(iterator.current.action, equals(TypeMatcher<ProductsReceived>()),
          reason: "Put must dispatch a 'ProductsReceived' action");

      iterator.moveNext();

      expect(iterator.moveNext(), false, reason: 'fetchProducts Saga must be done');
    });
  });
}
```

Note that outside the middleware environment, we have total control over the Generator, we can simulate a real environment by mocking results and resuming the Generator with them. Mocking data is a lot easier than mocking functions and spying calls.
