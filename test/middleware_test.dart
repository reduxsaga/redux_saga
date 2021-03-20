import 'package:redux/redux.dart';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/store.dart';
import 'helpers/utils.dart';

void main() {
  group('middleware tests', () {
    test('Basic', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            null,
            null,
            false,
            false,
            false,
            [0]
          ]));
    });

    test('Basic with finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
      }, Finally: () sync* {
        execution.add(1);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            null,
            null,
            false,
            false,
            false,
            [0, 1]
          ]));
    });

    test('Basic with catch and finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
      }, Catch: (dynamic e, StackTrace s) sync* {
        execution.add(1); //no error. will not execute
      }, Finally: () sync* {
        execution.add(2);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            null,
            null,
            false,
            false,
            false,
            [0, 2]
          ]));
    });

    test('Throw exception', () {
      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        throw exceptionToBeCaught;
      });

      expect(
          task.toFuture().catchError((dynamic error) => <dynamic>[
                error,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
              ]),
          completion([
            exceptionToBeCaught,
            null,
            false,
            false,
            true,
          ]));
    });

    test('Throw exception with catch caught', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        throw exceptionToBeCaught;
      }, Catch: (dynamic e, StackTrace s) sync* {
        execution.add(1);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution,
              ]),
          completion([
            null,
            null,
            false,
            false,
            false,
            [0, 1],
          ]));
    });

    test('Throw exception with catch rethrowed', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        throw exceptionToBeCaught;
      }, Catch: (dynamic e, StackTrace s) sync* {
        execution.add(1);
        throw sagaError;
      });

      expect(
          task.toFuture().catchError((dynamic error) => <dynamic>[
                error,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution,
              ]),
          completion([
            exceptionToBeCaught,
            null,
            false,
            false,
            true,
            [0, 1],
          ]));
    });

    test('Throw exception with catch rethrowed', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        throw exceptionToBeCaught;
      }, Catch: (Object e, StackTrace s) sync* {
        execution.add(1);
        throw e;
      });

      expect(
          task.toFuture().catchError((dynamic error) => <dynamic>[
                error,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution,
              ]),
          completion([
            exceptionToBeCaught,
            null,
            false,
            false,
            true,
            [0, 1],
          ]));
    });

    test('Throw exception with catch and finally rethrowed', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        throw exceptionToBeCaught;
      }, Catch: (Object e, StackTrace s) sync* {
        execution.add(1);
        throw e;
      });

      expect(
          task.toFuture().catchError((dynamic error) => <dynamic>[
                error,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution,
              ]),
          completion([
            exceptionToBeCaught,
            null,
            false,
            false,
            true,
            [0, 1],
          ]));
    });

    test('Throw exception with catch and finally caught', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        throw exceptionToBeCaught;
      }, Catch: (dynamic e, StackTrace s) sync* {
        execution.add(1);
      }, Finally: () sync* {
        execution.add(2);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution,
              ]),
          completion([
            null,
            null,
            false,
            false,
            false,
            [0, 1, 2],
          ]));
    });

    test('Throw exception with catch and finally rethrowed', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        throw exceptionToBeCaught;
      }, Catch: (dynamic e, StackTrace s) sync* {
        execution.add(1);
        throw sagaError;
      }, Finally: () sync* {
        execution.add(2);
      });

      expect(
          task.toFuture().catchError((dynamic error) => <dynamic>[
                error,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution,
              ]),
          completion([
            exceptionToBeCaught,
            null,
            false,
            false,
            true,
            [0, 1, 2],
          ]));
    });

    test('Throw exception with catch and finally rethrowed', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        throw exceptionToBeCaught;
      }, Catch: (Object e, StackTrace s) sync* {
        execution.add(1);
        throw e;
      }, Finally: () sync* {
        execution.add(2);
      });

      expect(
          task.toFuture().catchError((dynamic error) => <dynamic>[
                error,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution,
              ]),
          completion([
            exceptionToBeCaught,
            null,
            false,
            false,
            true,
            [0, 1, 2],
          ]));
    });

    test('Throw exception with catch and finally rethrowed', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        throw exceptionToBeCaught;
      }, Catch: (Object e, StackTrace s) sync* {
        execution.add(1);
        throw e;
      }, Finally: () sync* {
        execution.add(2);
      });

      expect(
          task.toFuture().catchError((dynamic error) => <dynamic>[
                error,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution,
              ]),
          completion([
            exceptionToBeCaught,
            null,
            false,
            false,
            true,
            [0, 1, 2],
          ]));
    });

    test('Return value', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        yield Return(value1); //must return from here
        execution.add(1);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution,
              ]),
          completion([
            value1,
            value1,
            false,
            false,
            false,
            [0],
          ]));
    });

    test('Cancel', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        yield Cancel(); //must cancel from here
        execution.add(1);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution,
              ]),
          completion([
            TaskCancel,
            TaskCancel,
            false,
            true,
            false,
            [0],
          ]));
    });

    test('Cancel with finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        yield Cancel();
        execution.add(1);
      }, Finally: () {
        execution.add(2);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution,
              ]),
          completion([
            TaskCancel,
            TaskCancel,
            false,
            true,
            false,
            [0, 2],
          ]));
    });

    test('Call iterator', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      Iterable<Effect> testIterator(List<int> execution) sync* {
        execution.add(1);
        yield Return(value1);
        execution.add(2);
      }

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        yield* testIterator(execution);
        execution.add(3);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution,
              ]),
          completion([
            value1,
            value1,
            false,
            false,
            false,
            [0, 1],
          ]));
    });

    test('Basic', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        yield Return(value1);
        execution.add(1);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            value1,
            value1,
            false,
            false,
            false,
            [0]
          ]));
    });

    test('Basic with finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        yield Return(value1);
        execution.add(1);
      }, Finally: () sync* {
        execution.add(2);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            value1,
            value1,
            false,
            false,
            false,
            [0, 2]
          ]));
    });

    test('Basic with finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
      }, Finally: () sync* {
        execution.add(1);
        yield Return(value1);
        execution.add(2);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            value1,
            value1,
            false,
            false,
            false,
            [0, 1]
          ]));
    });

    test('Basic with finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        yield Return(value1);
        execution.add(1);
      }, Finally: () sync* {
        execution.add(2);
        yield Return(value2);
        execution.add(3);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            value2,
            value2,
            false,
            false,
            false,
            [0, 2]
          ]));
    });

    test('Basic with catch and finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        yield Return(value1);
        execution.add(1);
      }, Catch: (dynamic e, StackTrace s) sync* {
        execution.add(2); //no error. will not execute
      }, Finally: () sync* {
        execution.add(3);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            value1,
            value1,
            false,
            false,
            false,
            [0, 3]
          ]));
    });

    test('Basic with catch and finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        yield Return(value1);
        execution.add(1);
      }, Catch: (dynamic e, StackTrace s) sync* {
        execution.add(2); //no error. will not execute
      }, Finally: () sync* {
        execution.add(3);
        yield Return(value2);
        execution.add(4);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            value2,
            value2,
            false,
            false,
            false,
            [0, 3]
          ]));
    });

    test('Basic with catch and finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        throw exceptionToBeCaught;
      }, Catch: (dynamic e, StackTrace s) sync* {
        execution.add(1);
        yield Return(value1);
        execution.add(2);
      }, Finally: () sync* {
        execution.add(3);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            value1,
            value1,
            false,
            false,
            false,
            [0, 1, 3]
          ]));
    });

    test('Basic with catch and finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        throw exceptionToBeCaught;
      }, Catch: (dynamic e, StackTrace s) sync* {
        execution.add(1);
        yield Return(value1);
        execution.add(2);
      }, Finally: () sync* {
        execution.add(3);
        yield Return(value2);
        execution.add(4);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            value2,
            value2,
            false,
            false,
            false,
            [0, 1, 3]
          ]));
    });

    test('Basic with catch and finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        throw exceptionToBeCaught;
      }, Catch: (dynamic e, StackTrace s) sync* {
        execution.add(1);
        throw sagaError;
      }, Finally: () sync* {
        execution.add(3);
        yield Return(value1);
        execution.add(4);
      });

      expect(
          task.toFuture().catchError((dynamic error) => <dynamic>[
                error,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            exceptionToBeCaught,
            null,
            false,
            false,
            true,
            [0, 1, 3]
          ]));
    });

    test('Cancel', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        yield Cancel(); //must cancel from here
        execution.add(1);
      }, Catch: (dynamic e, StackTrace s) sync* {
        execution.add(2); //no error. will not execute
      }, Finally: () sync* {
        execution.add(3);
        yield Return(value1);
        execution.add(4);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            TaskCancel,
            TaskCancel,
            false,
            true,
            false,
            [0, 3]
          ]));
    });

    test('Cancel', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        yield Return(value1);
        execution.add(1);
      }, Catch: (dynamic e, StackTrace s) sync* {
        execution.add(2); //no error. will not execute
      }, Finally: () sync* {
        execution.add(3);
        yield Cancel();
        execution.add(4);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            TaskCancel,
            TaskCancel,
            false,
            true,
            false,
            [0, 3]
          ]));
    });

    test('Cancel', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        throw exceptionToBeCaught;
      }, Catch: (dynamic e, StackTrace s) sync* {
        execution.add(1);
        yield Cancel();
        execution.add(2);
      }, Finally: () sync* {
        execution.add(3);
        yield Return(value1);
        execution.add(4);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            TaskCancel,
            TaskCancel,
            false,
            true,
            false,
            [0, 1, 3]
          ]));
    });

    test('Basic with catch and finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        yield Return(value1);
        execution.add(1);
      }, Catch: (dynamic e, StackTrace s) {
        execution.add(2);
      }, Finally: () {
        execution.add(3);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            value1,
            value1,
            false,
            false,
            false,
            [0, 3]
          ]));
    });

    test('Basic with catch and finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        yield Return(value1);
        execution.add(1);
      }, Catch: (dynamic e, StackTrace s) {
        execution.add(2);
      }, Finally: () {
        execution.add(3);
        return;
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            value1,
            value1,
            false,
            false,
            false,
            [0, 3]
          ]));
    });

    test('Basic with catch and finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        yield Return(value1);
        execution.add(1);
      }, Catch: (dynamic e, StackTrace s) {
        execution.add(2);
      }, Finally: () sync* {
        execution.add(3);
        yield Return(value2);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            value2,
            value2,
            false,
            false,
            false,
            [0, 3]
          ]));
    });

    test('Basic with catch and finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        yield Return(value1);
        execution.add(1);
      }, Catch: (dynamic e, StackTrace s) {
        execution.add(2);
      }, Finally: () {
        execution.add(3);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            value1,
            value1,
            false,
            false,
            false,
            [0, 3]
          ]));
    });

    test('Basic with catch and finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        yield Return(value1);
        execution.add(1);
      }, Catch: (dynamic e, StackTrace s) {
        execution.add(2);
      }, Finally: () async {
        execution.add(3);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            value1,
            value1,
            false,
            false,
            false,
            [0, 3]
          ]));
    });

    test('Basic with catch and finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        yield Return(value1);
        execution.add(1);
      }, Catch: (dynamic e, StackTrace s) {
        execution.add(2);
      }, Finally: () sync* {
        execution.add(3);
        yield Return(value2);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            value2,
            value2,
            false,
            false,
            false,
            [0, 3]
          ]));
    });

    test('Basic with catch and finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        yield Return(value1);
        execution.add(1);
      }, Catch: (dynamic e, StackTrace s) {
        execution.add(2);
      }, Finally: () async {
        execution.add(3);
        return;
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            value1,
            value1,
            false,
            false,
            false,
            [0, 3]
          ]));
    });

    test('Basic with catch and finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        throw exceptionToBeCaught;
      }, Catch: (dynamic e, StackTrace s) {
        execution.add(1);
      }, Finally: () {
        execution.add(2);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            null,
            null,
            false,
            false,
            false,
            [0, 1, 2]
          ]));
    });

    test('Basic with catch and finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        throw exceptionToBeCaught;
      }, Catch: (dynamic e, StackTrace s) {
        execution.add(1);
        throw sagaError;
      }, Finally: () {
        execution.add(2);
        return value1;
      });

      expect(
          task.toFuture().catchError((dynamic error) => <dynamic>[
                error,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            exceptionToBeCaught,
            null,
            false,
            false,
            true,
            [0, 1, 2]
          ]));
    });

    test('Basic with catch and finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        throw exceptionToBeCaught;
      }, Catch: (dynamic e, StackTrace s) {
        execution.add(1);
        throw sagaError;
      }, Finally: () {
        execution.add(2);
        throw exceptionToBeCaught2;
      });

      expect(
          task.toFuture().catchError((dynamic error) => <dynamic>[
                error,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            exceptionToBeCaught2,
            null,
            false,
            false,
            true,
            [0, 1, 2]
          ]));
    });

    test('Basic with catch and finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        throw exceptionToBeCaught;
      }, Catch: (dynamic e, StackTrace s) async {
        execution.add(1);
        throw sagaError;
      }, Finally: () async {
        execution.add(2);
        throw exceptionToBeCaught2;
      });

      expect(
          task.toFuture().catchError((dynamic error) => <dynamic>[
                error,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            exceptionToBeCaught2,
            null,
            false,
            false,
            true,
            [0, 1, 2]
          ]));
    });

    test('Basic with catch and finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        throw exceptionToBeCaught;
      }, Catch: (dynamic e, StackTrace s) async {
        execution.add(1);
        throw sagaError;
      }, Finally: () {
        execution.add(2);
        throw exceptionToBeCaught2;
      });

      expect(
          task.toFuture().catchError((dynamic error) => <dynamic>[
                error,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            exceptionToBeCaught2,
            null,
            false,
            false,
            true,
            [0, 1, 2]
          ]));
    });

    test('Basic with catch and finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        throw exceptionToBeCaught;
      }, Catch: (dynamic e, StackTrace s) sync* {
        execution.add(1);
        yield Return(value1);
      }, Finally: () sync* {
        execution.add(2);
        yield Return(value2);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            value2,
            value2,
            false,
            false,
            false,
            [0, 1, 2]
          ]));
    });

    test('Basic with catch and finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        throw exceptionToBeCaught;
      }, Catch: (dynamic e, StackTrace s) sync* {
        execution.add(1);
        yield Return(value1);
      }, Finally: () sync* {
        execution.add(2);
        yield Return(value2);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            value2,
            value2,
            false,
            false,
            false,
            [0, 1, 2]
          ]));
    });

    test('Basic with catch and finally', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        throw exceptionToBeCaught;
      }, Catch: (dynamic e, StackTrace s) sync* {
        execution.add(1);
        yield Return(value1);
      }, Finally: () sync* {
        execution.add(2);
        yield Return(value2);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution
              ]),
          completion([
            value2,
            value2,
            false,
            false,
            false,
            [0, 1, 2]
          ]));
    });

    test('middleware run', () {
      var sagaMiddleware = createSagaMiddleware();
      //middleware.run must throw when executed before connected to a Store
      expect(() => sagaMiddleware.run(() sync* {}),
          throwsA(TypeMatcher<SagaMustBeConnectedToTheStore>()));

      var store = Store<AppState>(
        appReducer,
        initialState: AppState.initial(),
        middleware: [
          applyMiddleware(sagaMiddleware),
        ],
      );

      //middleware.run must throw when executed before store property set
      expect(() => sagaMiddleware.run(() sync* {}),
          throwsA(TypeMatcher<SagaStoreMustBeSet>()));

      sagaMiddleware.setStore(store);

      //middleware.run must throw when saga is not generator
      expect(() => sagaMiddleware.run(() {}),
          throwsA(TypeMatcher<SagaFunctionMustBeGeneratorException>()));

      dynamic actual;

      Iterable<Effect> saga(dynamic arg) sync* {
        actual = arg;
      }

      //middleware.run must return a Task
      expect(sagaMiddleware.run(saga, args: <dynamic>[value1]),
          equals(TypeMatcher<Task<dynamic>>()));

      //middleware must run the Saga and provides it with the given arguments
      expect(actual, equals(value1));
    });

    test('middleware options', () {
      dynamic actual;

      var sagaMiddleware =
          createSagaMiddleware(Options(onError: (dynamic e, String s) {
        actual = e;
      }));
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      Iterable<Effect> saga() sync* {
        throw exceptionToBeCaught;
      }

      sagaMiddleware.run(saga);

      //options.onError is called appropriately
      expect(actual, equals(exceptionToBeCaught));
    });

    test('enhance channel.put with an emitter', () {
      var actual = <Map<String, dynamic>>[];

      Iterable<Effect> saga() sync* {
        yield TakeEvery(({dynamic action}) sync* {
          actual.add(<String, dynamic>{'saga': true, 'got': action.type});
          yield Put(_PongAction('pong_${action.type}'));
        }, pattern: _PingAction);
        yield TakeEvery(({dynamic action}) sync* {
          actual.add(<String, dynamic>{'saga': true, 'got': action.type});
        }, pattern: _PongAction);
      }

      var sagaMiddleware = createSagaMiddleware();

      var store = Store<EmptyState>(
        (EmptyState state, dynamic action) {
          actual.add(<String, dynamic>{'reducer': true, 'got': action.type});
          return EmptyState();
        },
        initialState: EmptyState(),
        middleware: [
          applyMiddleware(sagaMiddleware),
        ],
      );

      sagaMiddleware.setStore(store);

      sagaMiddleware.run(saga);

      store.dispatch(_PingAction('a'));
      store.dispatch(_PingAction('b'));
      store.dispatch(_PingAction('c'));
      store.dispatch(_PingAction('d'));

      //saga must be able to take actions emitted by middleware's custom emitter
      expect(
          actual,
          equals(<Map<String, dynamic>>[
            <String, dynamic>{'reducer': true, 'got': 'a'},
            <String, dynamic>{'saga': true, 'got': 'a'},
            <String, dynamic>{'reducer': true, 'got': 'pong_a'},
            <String, dynamic>{'saga': true, 'got': 'pong_a'},
            <String, dynamic>{'reducer': true, 'got': 'b'},
            <String, dynamic>{'saga': true, 'got': 'b'},
            <String, dynamic>{'reducer': true, 'got': 'pong_b'},
            <String, dynamic>{'saga': true, 'got': 'pong_b'},
            <String, dynamic>{'reducer': true, 'got': 'c'},
            <String, dynamic>{'saga': true, 'got': 'c'},
            <String, dynamic>{'reducer': true, 'got': 'pong_c'},
            <String, dynamic>{'saga': true, 'got': 'pong_c'},
            <String, dynamic>{'reducer': true, 'got': 'd'},
            <String, dynamic>{'saga': true, 'got': 'd'},
            <String, dynamic>{'reducer': true, 'got': 'pong_d'},
            <String, dynamic>{'saga': true, 'got': 'pong_d'}
          ]));
    });
  });
}

class _PingAction {
  final String type;

  _PingAction(this.type);
}

class _PongAction {
  final String type;

  _PongAction(this.type);
}
