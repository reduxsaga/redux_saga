# Migration Guide From Javascript

## Objectives of this guide

Through this guide you will understand the differences between Dart Redux_Saga and Javascript Redux-Saga. Then you can transform any Saga written in Javascript to Dart easily.
Since transforming sagas is equal to transforming the whole middleware, then migrating an application becomes easier than ever.
This guide does not introduce anything about philosophy of Reactive Programing, Flutter and Redux Store usage.

### Differences about the logic

Redux_Saga uses the exactly same logic to its Javascript implementation. That means the behaviour is same. The middleware and all the effects are verified through its Javascript equivalent tests.
Also additional test are provided. With nearly more than +250 unit tests, Redux_Saga provides a stable middleware.

### Differences about the effects

Redux_Saga provides all the effects provided by its Javascript implementation. Also there are some additional Effects also.

### Differences about the syntax

Since Javascript and Dart are different languages there are differences between usages. Especially main difference is about generator functions.
Both languages provide generators basically. While yield is a statement in Dart, it is an expression in Javascript.
It makes impossible to get a return value through a yield statement in Dart. Generator can not return a value except yielding values.
It is also impossible to throw an exception in to a generator.

Fortunately we had overcome all the obstacles and Redux_Saga for Dart implementation can handle all of it.
There are some natural syntax changes between both implementations as well. But we will not focus all of them. We will focus only important differences in this guide.

### Generators

In Javascript we can basically create a generator by;

```javascript
export function* helloSaga() {
  console.log('Hello Sagas!')
}
```

Its Dart equivalent is;

```dart
helloSaga() sync* {
  print('Hello Sagas!');
}
```

Nearly same. While Javascript needs a `*` after `function` keyword, Dart requires a `sync*` keyword before function body declaration.

### Returning a value from generator

In Javascript we can return a value from a saga by return keyword;

```javascript
export function* gen() {
  return value;
}
```

Its Dart equivalent is;

```dart
gen() sync* {
  yield Return(value);
}
```

We use `Return` effect to handle it.

### Returning a value from and effect

In Javascript we can return a value from an effect directly;

```javascript
export function* gen() {
    ...
    const posts = yield call(fetchPostsApi)

    dosomething(posts);
    ...
}
```

Its Dart equivalent is;

```dart
gen() sync* {
  ...
  var posts = Result();
  yield Call(fetchPostsApi, result: posts);

  dosomething(posts.value);
  ...
}
```

We use optional `result` effect parameter to handle this. First we create a variable and pass it to effect result argument. Now returned value is stored in the `value` property of result object.
In this case `Call` effect returns value to the posts objects. Posts can be accessed through `posts.value`.

### try/catch/finally usage

In Javascript we can use try/catch/finally blocks to handle exception handling.

```javascript
export function* checkout() {
  try {
    const cart = yield select(getCart)
    yield call(api.buyProducts, cart)
    yield put(actions.checkoutSuccess(cart))
  } catch (error) {
    yield put(actions.checkoutFailure(error))
  }
  finally {
    yield put(actions.checkoutEnd())
  }
}
```

Its Dart equivalent is;

```dart
checkout() sync* {
  yield Try(() sync* {
    var cart = Result<Cart>();
    yield Select(selector: getCart, result: cart);
    yield Call(buyProductsAPI, args: [cart.value]);
    yield Put(CheckoutSuccess(cart.value));
  }, Catch: (error) sync* {
    yield Put(CheckoutFailure(error));
  }, Finally: () sync* {
    yield Put(CheckoutEnd());
  });
}
```

We use same blocks through yielding a `Try` effect. `Catch` and `Finally` are optional and you can use either of them you want. Not that functions can be either a generator or a normal function.

### Returning from a try/catch/finally

If you want to return from a returned value from a Try/Catch/Finally block then use `TryReturn`.

 In the following example the saga returns value returned
```dart
  saga() sync* {
    yield TryReturn(() sync* { //returns saga
      //...
      yield Return(somevalue1); //returns from Try. Does not return from saga
    }, Catch: (error) sync* {
      //...
      yield Return(somevalue2); //returns from Try. Does not return from saga
    });
  }
```

Equivalent code with `Try`

```dart
  saga() sync* {
    var result = Result();
    yield Try(() sync* {
      //...
      yield Return(somevalue1); //returns from Try. Does not return from saga
    }, Catch: (error) sync* {
      //...
      yield Return(somevalue2); //returns from Try. Does not return from saga
    }, result: result);
    yield Return(result.value); //returns from saga
  }
```

As you see `Return` effect only returns from its own code block. In the example, to return from whole saga you should use `TryReturn`.
Since `Try` is an alias for `Call` effect, it is same as returning a value from a `Call` effect directly.

### Conclusion

As you can see above that is all, there are a few differences and it is very easy to migrate sagas to Dart.
You can check examples and [API Reference](https://pub.dev/documentation/redux_saga) in order to get more information.

Examples:

*[vanilla_counter](https://github.com/reduxsaga/vanilla_counter)

*[counter](https://github.com/reduxsaga/counter)

*[shopping_cart](https://github.com/reduxsaga/shopping_cart)

*[async_app](https://github.com/reduxsaga/async_app)




