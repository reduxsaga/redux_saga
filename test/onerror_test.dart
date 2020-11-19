import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/store.dart';
import 'helpers/utils.dart';

void main() {
  group('onerror tests', () {
    test('saga onError is optional', () {
      dynamic error;
      String stack;

      var sagaMiddleware =
          createMiddleware(options: Options(onError: (dynamic e, String s) {
        error = e;
        stack = s;
      }));
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield Call(() sync* {
          throw exceptionToBeCaught;
        }, name: 'child');
      }, name: 'main');

      //saga must return a rejected future if generator throws an uncaught error
      expect(task.toFuture(), throwsA(exceptionToBeCaught));

      //middleware on error must be invoked
      expect(task.toFuture().catchError((dynamic e) => error),
          completion(exceptionToBeCaught));

      expect(
          task.toFuture().catchError((dynamic e) =>
              stack != null &&
              stack
                  .contains('#0      The above error occurred in task child') &&
              stack.contains('#1       created by main')),
          completion(true));
    });

    test('saga onError is called for uncaught error (thrown Error instance)',
        () {
      dynamic actual;

      var sagaMiddleware =
          createMiddleware(options: Options(onError: (dynamic e, String s) {
        actual = e;
      }));
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield Call(() sync* {
          throw exceptionToBeCaught;
        }, name: 'child');
      }, name: 'main');

      expect(task.toFuture(), throwsA(exceptionToBeCaught));

      // saga passes thrown Error instance in onError handler
      expect(task.toFuture().catchError((dynamic e) => e),
          completion(exceptionToBeCaught));

      //middleware on error must be invoked
      expect(task.toFuture().catchError((dynamic e) => actual),
          completion(exceptionToBeCaught));
    });

    test('saga onError is not called for caught errors', () {
      dynamic actual;
      dynamic caught;

      var sagaMiddleware =
          createMiddleware(options: Options(onError: (dynamic e, String s) {
        actual = e;
      }));
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield Call(() sync* {
          throw exceptionToBeCaught;
        }, Catch: (dynamic e, StackTrace s) {
          caught = e;
        }, name: 'child');
      }, name: 'main');

      expect(task.toFuture().then<dynamic>((dynamic value) => caught),
          completion(exceptionToBeCaught));

      //saga must not call onError
      expect(task.toFuture().then<dynamic>((dynamic value) => actual),
          completion(null));
    });
  });
}
