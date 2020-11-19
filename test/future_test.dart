import 'dart:async';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/utils.dart';
import 'helpers/store.dart';

void main() {
  group('future handling tests', () {
    test('saga future handling', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield Try(() sync* {
          var result = Result<int>();
          yield Call(() => Future<int>.value(1), result: result);
          actual.add(result.value);

          var result2 = Result<dynamic>();
          yield Call(() => Future<int>.error(exceptionToBeCaught),
              result: result2);
          actual.add(result2.value);
        }, Catch: (dynamic e, StackTrace s) sync* {
          actual.add(e);
        });
      });

      // saga should handle future resolved/rejected values
      expect(task.toFuture().then((dynamic value) => actual),
          completion([1, exceptionToBeCaught]));
    });
  });
}
