import 'dart:async';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/utils.dart';
import 'helpers/store.dart';

void main() {
  group('effect middlewares tests', () {
    test('middleware run', () {
      var actual = <dynamic>[];

      var apiCall = Call(() => Future(() {}));

      var effectMiddleware = (dynamic effect, NextMiddlewareHandler next) {
        if (effect == apiCall) {
          Future(() {}).then((value) => next('injected value'));
          return;
        }
        return next(effect);
      };

      Iterable<Effect> fnA() sync* {
        var result = <dynamic>[];

        var takeResult = Result<dynamic>();
        yield Take(pattern: TestActionA, result: takeResult);
        result.add(takeResult.value.payload);

        yield Take(pattern: TestActionB, result: takeResult);
        result.add(takeResult.value.payload);

        yield Return(result);
      }

      var sagaMiddleware = createMiddleware(
          options: Options(effectMiddlewares: [effectMiddleware]));
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        var all = AllResult();
        yield All(<dynamic, Effect>{#call: Call(fnA), #apiCall: apiCall},
            result: all);
        actual.add(all.value);
      });

      ResolveSequentially([
        callF(() => store.dispatch(TestActionA(1))),
        callF(() => store.dispatch(TestActionB(2))),
      ]);

      //effectMiddleware must be able to intercept and resolve effect in a custom way
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            <dynamic, dynamic>{
              #call: [1, 2],
              #apiCall: 'injected value'
            }
          ]));
    });

    test('effectMiddlewares - multiple', () {
      var actual = <dynamic>[];

      var apiCall1 = Call(() => Future(() {}), result: Result<dynamic>());

      var effectMiddleware1 = (dynamic effect, NextMiddlewareHandler next) {
        actual.addAll(<dynamic>['middleware1 received', effect]);

        if (effect == apiCall1) {
          Future(() {}).then((value) => next('middleware1 injected value'));
          return;
        }

        actual.addAll(<dynamic>['middleware1 passed trough', effect]);
        return next(effect);
      };

      var apiCall2 = Call(() => Future(() {}), result: Result<dynamic>());

      var effectMiddleware2 = (dynamic effect, NextMiddlewareHandler next) {
        actual.addAll(<dynamic>['middleware2 received', effect]);

        if (effect == apiCall2) {
          Future(() {}).then((value) => next('middleware2 injected value'));
          return;
        }

        actual.addAll(<dynamic>['middleware2 passed trough', effect]);
        return next(effect);
      };

      var returnA = Return('fnA result');

      Iterable<Effect> fnA() sync* {
        yield returnA;
      }

      var callA = Call(fnA, result: Result<dynamic>());

      var sagaMiddleware = createMiddleware(
          options: Options(
              effectMiddlewares: [effectMiddleware1, effectMiddleware2]));
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield apiCall1;
        actual.addAll(<dynamic>['effect\'s result is', apiCall1.result.value]);

        yield callA;
        actual.addAll(<dynamic>['effect\'s result is', callA.result.value]);

        yield apiCall2;
        actual.addAll(<dynamic>['effect\'s result is', apiCall2.result.value]);
      });

      //multiple effectMiddlewares must create a chain
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion(<dynamic>[
            'middleware1 received',
            apiCall1,
            'middleware2 received',
            'middleware1 injected value',
            'middleware2 passed trough',
            'middleware1 injected value',
            "effect's result is",
            'middleware1 injected value',
            'middleware1 received',
            callA,
            'middleware1 passed trough',
            callA,
            'middleware2 received',
            callA,
            'middleware2 passed trough',
            callA,
            'middleware1 received',
            returnA,
            'middleware1 passed trough',
            returnA,
            'middleware2 received',
            returnA,
            'middleware2 passed trough',
            returnA,
            "effect's result is",
            'fnA result',
            'middleware1 received',
            apiCall2,
            'middleware1 passed trough',
            apiCall2,
            'middleware2 received',
            apiCall2,
            "effect's result is",
            'middleware2 injected value',
          ]));
    });

    test('effectMiddlewares - nested task', () {
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

      var sagaMiddleware = createMiddleware(
          options: Options(effectMiddlewares: [effectMiddleware]));
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        var result = Result<dynamic>();
        yield Call(fnA, result: result);
        actual.add(result.value);
      });

      ResolveSequentially([
        callF(() => store.dispatch(TestActionA(1))),
        callF(() => store.dispatch(TestActionB(2))),
      ]);

      //effectMiddleware must be able to intercept effects from non-root sagas
      expect(task.toFuture().then((dynamic value) => actual),
          completion(<dynamic>[1, 2, 'injected value', 'result']));
    });
  });
}
