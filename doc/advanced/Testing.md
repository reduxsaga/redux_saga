# Testing Sagas

There are two main ways to test Sagas: testing the saga generator function step-by-step or running the full saga and
asserting the side effects.

## Testing the Saga Generator Function

Suppose we have the following actions:

```dart
class ChooseColor {
  dynamic payload;

  ChooseColor(this.payload);
}

class ChangeUI {
  dynamic payload;

  ChangeUI(this.payload);
}
```

We want to test the saga:

```dart
changeColorSaga() sync* {
  var action = Result<ChooseColor>();
  yield Take(pattern: ChooseColor, result: action);
  yield Put(ChangeUI(action.value.color));
}
```

Since Sagas always yield an Effect, and these effects have basic factory functions (e.g. Put, Take etc.) a test may
inspect the yielded effect and compare it to an expected effect. To get the first yielded value from a saga,
call its `moveNext()`:

```dart
Iterable gen = changeColorSaga();

var iterator = gen.iterator;

iterator.moveNext();

expect(iterator.current, equals(TypeMatcher<Take>()), reason: 'should return Take effect');

expect(iterator.current.pattern, equals(ChooseColor),
  reason: 'it should wait for a user to choose a color');
```

A value must then be returned to assign to the `action` constant, which is used for the argument to the `Put` effect:

```dart
expect(iterator.current, TypeMatcher<Put>(), reason: 'expected Put effect');

expect(iterator.current.action, equals(TypeMatcher<ChangeUI>()),
  reason: 'it should dispatch an action to change the ui');
```

Since there are no more `yield`s, then next time `next()` is called, the generator will be done:

```dart
expect(iterator.moveNext(), false, reason: 'Saga must be done');
```

### Branching Saga

Sometimes your saga will have different outcomes. To test the different branches without repeating all the steps that lead to it you can use the utility function **CloneableGenerator**

This time we add two new actions, `ChooseNumber` and `DoStuff`, with a related action creators:

```dart
class ChooseNumber {
  int number;

  ChooseNumber(this.number);
}

class DoStuff {}
```

Now the saga under test will put two `DoStuff` actions before waiting for a `ChooseNumber` action and then putting
either `ChangeUI('red')` or `ChangeUI('blue')`, depending on whether the number is even or odd.

```dart
doStuffThenChangeColor() sync* {
  yield Put(DoStuff());
  yield Put(DoStuff());
  var action = Result<ChooseNumber>();
  yield Take(pattern: ChooseNumber, result: action);
  if (action.value.number % 2 == 0) {
    yield Put(ChangeUI('red'));
  } else {
    yield Put(ChangeUI('blue'));
  }
}
```

The test is as follows:

```dart
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import '../bin/main.dart';

void main() {
  group('doStuffThenChangeColor Saga test', () {

    CloneableGenerator gen;

    setUp(() {
      gen = CloneableGenerator(doStuffThenChangeColor);

      gen.moveNext(); //DoStuff
      gen.moveNext(); //DoStuff
      gen.moveNext(); //ChooseNumber
    });

    test('user choose an even number', () {
      // cloning the generator before sending data
      var clone = gen.clone();

      clone.setResult(ChooseNumber(2));

      clone.moveNext();

      expect(clone.current, TypeMatcher<Put>(), reason: 'expected Put effect');

      expect(clone.current.action, equals(TypeMatcher<ChangeUI>()),
          reason: 'should dispatch a ChangeUI');

      expect(clone.current.action.color, equals('red'), reason: 'should change the color to red');

      expect(clone.moveNext(), false, reason: 'Saga must be done');
    });

    test('user choose an odd number', () {
      // cloning the generator before sending data
      var clone = gen.clone();

      clone.setResult(ChooseNumber(3));

      clone.moveNext();

      expect(clone.current, TypeMatcher<Put>(), reason: 'expected Put effect');

      expect(clone.current.action, equals(TypeMatcher<ChangeUI>()),
          reason: 'should dispatch a ChangeUI');

      expect(clone.current.action.color, equals('blue'), reason: 'should change the color to blue');

      expect(clone.moveNext(), false, reason: 'Saga must be done');
    });

  });
}
```

See also: [Task cancellation](TaskCancellation.md) for testing fork effects

## Testing the full Saga

Although it may be useful to test each step of a saga, in practise this makes for brittle tests. Instead, it may be
preferable to run the whole saga and assert that the expected effects have occurred.

Suppose we have a basic saga which calls an HTTP API:

```dart
callApi(url) sync* {
  var someValue = Result();
  yield Select(selector: somethingFromState, result: someValue);
  yield TryReturn(() sync* {
    var resultJson = Result<ResultJson>();
    yield Call(myApi, args: [url, someValue.value], result: resultJson);
    yield Put(SuccessAction(resultJson.value.json()));
    yield Return(resultJson.value.status);
  }, Catch: (e) sync* {
    yield Put(ErrorAction(e));
    yield Return(-1);
  });
}
```

We can run the saga with mocked values:

```dart
//Create a test middleware
var sagaMiddleware = createTestMiddleware();

var dispatched = [];

sagaMiddleware.dispatch = (dynamic action) {
  dispatched.add(action);
};

sagaMiddleware.getState = () {
  return 'test';
};

var task = sagaMiddleware.run(callApi, args: ['http://url']);
```

A saga and test could then be written to assert the dispatched actions and mock calls:

```dart
import 'package:redux_saga/redux_saga.dart';

class ErrorAction {
  dynamic error;

  ErrorAction(this.error);
}

class SuccessAction {
  String json;

  SuccessAction(this.json);
}

dynamic somethingFromState(dynamic state) {
  return state;
}

class ResultJson {
  final int status;
  final String data;

  ResultJson(this.data, this.status);

  String json() {
    return data;
  }
}

ResultJson myApi(String url, dynamic someValue) {
  return ResultJson('json data from $url', 0);
}

callApi(url) sync* {
  var someValue = Result();
  yield Select(selector: somethingFromState, result: someValue);

  yield TryReturn(() sync* {
    var resultJson = Result<ResultJson>();
    yield Call(myApi, args: [url, someValue.value], result: resultJson);
    yield Put(SuccessAction(resultJson.value.json()));
    yield Return(resultJson.value.status);
  }, Catch: (e) sync* {
    yield Put(ErrorAction(e));
    yield Return(-1);
  });
}
```

Its test with mocked calls and values:

```dart
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import '../bin/main.dart';

void main() {
  group('Middleware tests', () {
    test('callApi test', () async {
      var sagaMiddleware = createTestMiddleware();

      var dispatched = [];

      sagaMiddleware.dispatch = (dynamic action) {
        dispatched.add(action);
      };

      sagaMiddleware.getState = () {
        return 'test';
      };

      var task = sagaMiddleware.run(callApi, args: ['http://url']);
      expect(task.toFuture(), completion(equals(0)));
      expect(
          task.toFuture().then((value) => dispatched), completion([TypeMatcher<SuccessAction>()]));
    });
  });
}

```

See also: Repository Examples:

https://github.com/reduxsaga/counter/blob/master/test/middleware_test.dart

## `effectMiddlewares`
Provides a native way to perform integration like testing.

The idea is that you can create a real redux store with saga middleware in your test file. The saga middleware takes an object as an argument. That object would have an `EffectMiddlewares` value: a function where you can intercept/hijack any effect and resolve it on your own - passing it very redux-style to the next middleware.

In your test, you would start a saga, intercept/resolve async effects with effectMiddlewares and assert on things like state updates to test integration between your saga and a store.

Here's an example from the [api](https://pub.dev/documentation/redux_saga/latest/redux_saga/EffectMiddlewareHandler.html):

```dart
import 'package:redux/redux.dart';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';

void main() {
  group('Middleware tests', () {
    test('effectMiddleware', () {
      var actual = <dynamic>[];

      var apiCall = Call(() => Future(() {}), result: Result<dynamic>());

      var effectMiddleware = (dynamic effect, NextMiddlewareHandler next) {
        if (effect == apiCall) {
          Future(() {}).then((value) => next('injected value'));
          return;
        }

        return next(effect);
      };

      Iterable<Effect> fnA() sync* {
        var result = Result<dynamic>();
        yield Take(pattern: TestActionA, result: result);
        actual.add(result.value.payload);

        yield Take(pattern: TestActionB, result: result);
        actual.add(result.value.payload);

        yield apiCall;
        actual.add(apiCall.result.value);

        yield Return('result');
      }

      var sagaMiddleware = createTestMiddleware(Options(effectMiddlewares: [effectMiddleware]));

      var task = sagaMiddleware.run(() sync* {
        var result = Result<dynamic>();
        yield Call(fnA, result: result);
        actual.add(result.value);
      });

      Future f = Future<void>.sync(() => null);
      f = f.then<dynamic>((dynamic v) => sagaMiddleware.dispatch(TestActionA(1)));
      f = f.then<dynamic>((dynamic v) => sagaMiddleware.dispatch(TestActionB(2)));

      //effectMiddleware must be able to intercept effects from non-root sagas
      expect(task.toFuture().then((dynamic value) => actual),
          completion(<dynamic>[1, 2, 'injected value', 'result']));
    });
  });
}

class TestActionA {
  final int payload;

  TestActionA(this.payload);

  @override
  String toString() {
    return '$payload';
  }
}

class TestActionB {
  final int payload;

  TestActionB(this.payload);

  @override
  String toString() {
    return '$payload';
  }
}
```
