import 'package:redux_saga/redux_saga.dart' as redux;
import 'package:test/test.dart';
import 'helpers/utils.dart';
import 'helpers/store.dart';

void main() {
  group('retry', () {
    test('retry failing', () {
      final delayMs = 0;
      var called = 0;

      var actual = <List<dynamic>>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield redux.Retry((dynamic arg1) {
          called++;
          actual.add(<dynamic>[arg1, called]);
          throw exceptionToBeCaught;
        },
            args: <dynamic>['a'],
            maxTries: 3,
            duration: Duration(milliseconds: delayMs));
      });

      //should rethrow Error if failed more than the defined number of times
      expect(task.toFuture(), throwsA(equals(exceptionToBeCaught)));

      //should retry only for the defined number of times
      expect(
          task.toFuture().catchError((dynamic e) => actual),
          completion([
            ['a', 1],
            ['a', 2],
            ['a', 3]
          ]));
    });

    test('retry without failing', () {
      final delayMs = 0;
      var called = false;
      var returnedValue = 79;

      var result = redux.Result<dynamic>();

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield redux.Retry(() {
          if (called == false) {
            called = true;
            throw exceptionToBeCaught;
          }
          return returnedValue;
        },
            maxTries: 3,
            duration: Duration(milliseconds: delayMs),
            result: result);
      });

      // should return a result of called function
      expect(task.toFuture().then<dynamic>((dynamic value) => result.value),
          completion(returnedValue));
    });
  });
}
