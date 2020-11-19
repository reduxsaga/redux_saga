import 'package:redux/redux.dart';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/utils.dart';
import 'helpers/store.dart';

void main() {
  group('call test', () {
    test('saga handles call effects and resume with the resolved values', () {
      var actual = <dynamic>[];

      var inst1 = _C(1);
      var inst2 = _C(2);

      Iterable<Effect> subGen(int arg) sync* {
        yield Call(() => Future<void>.value(null));
        yield Return(arg);
      }

      Symbol identity(Symbol arg) {
        return arg;
      }

      var four = #four;

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        var result = Result<dynamic>();

        yield Call(inst1.method, result: result);
        actual.add(result.value);

        yield Apply(inst2.method, result: result);
        actual.add(result.value);

        yield Call(subGen, args: <dynamic>[3], result: result);
        actual.add(result.value);

        yield Call(identity, args: <dynamic>[four], result: result);
        actual.add(result.value);
      });

      //saga must fulfill declarative call effects
      expect(task.toFuture().then((dynamic value) => actual),
          completion([1, 2, 3, #four]));
    });

    test(
        'saga handles call effects and throw the rejected values inside the generator',
        () {
      var actual = <dynamic>[];

      Future<dynamic> fail(dynamic msg) {
        return Future<dynamic>.error(msg);
      }

      var sagaMiddleware = createSagaMiddleware();

      var store = Store<EmptyState>(
        (EmptyState state, dynamic action) {
          actual.add(action.type);
          return EmptyState();
        },
        initialState: EmptyState(),
        middleware: [
          applyMiddleware(sagaMiddleware),
        ],
      );

      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield Put(_Action('start'));
        yield Call(fail, args: <dynamic>['failure']);
        yield Put(_Action('success'));
      }, Catch: (dynamic e, StackTrace s) sync* {
        yield Put(_Action(e));
      });

      //saga dispatches appropriate actions
      expect(task.toFuture().then((dynamic value) => actual),
          completion(['start', 'failure']));
    });

    test(
        'saga handles call\'s synchronous failures and throws in the calling generator (1)',
        () {
      var actual = <dynamic>[];

      void failfn() {
        throw exceptionToBeCaught;
      }

      var sagaMiddleware = createSagaMiddleware();

      var store = Store<EmptyState>(
        (EmptyState state, dynamic action) {
          actual.add(action.type);
          return EmptyState();
        },
        initialState: EmptyState(),
        middleware: [
          applyMiddleware(sagaMiddleware),
        ],
      );

      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield Put(_Action('start parent'));
        //call child generator
        yield Call(() sync* {
          yield Put(_Action('start child'));
          yield Call(failfn);
          yield Put(_Action('success child'));
        }, Catch: (dynamic e, StackTrace s) sync* {
          yield Put(_Action('failure child'));
        });
        yield Put(_Action('success parent'));
      }, Catch: (dynamic e, StackTrace s) sync* {
        yield Put(_Action('failure parent'));
      });

      //saga dispatches appropriate actions
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            'start parent',
            'start child',
            'failure child',
            'success parent'
          ]));
    });

    test(
        'saga handles call\'s synchronous failures and throws in the calling generator (2)',
        () {
      var actual = <dynamic>[];

      void failfn() {
        throw exceptionToBeCaught;
      }

      var sagaMiddleware = createSagaMiddleware();

      var store = Store<EmptyState>(
        (EmptyState state, dynamic action) {
          actual.add(action.type);
          return EmptyState();
        },
        initialState: EmptyState(),
        middleware: [
          applyMiddleware(sagaMiddleware),
        ],
      );

      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield Put(_Action('start parent'));
        //call child generator
        yield Call(() sync* {
          yield Put(_Action('start child'));
          yield Call(failfn);
          yield Put(_Action('success child'));
        }, Catch: (dynamic e, StackTrace s) sync* {
          yield Put(_Action('failure child'));
          throw e;
        });
        yield Put(_Action('success parent'));
      }, Catch: (dynamic e, StackTrace s) sync* {
        yield Put(_Action('failure parent'));
      });

      //saga dispatches appropriate actions
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            'start parent',
            'start child',
            'failure child',
            'failure parent'
          ]));
    });

    test(
        'saga handles call\'s synchronous failures and throws in the calling generator (3)',
        () {
      var actual = <dynamic>[];

      Iterable<Effect> failGen() sync* {
        throw exceptionToBeCaught;
      }

      var sagaMiddleware = createSagaMiddleware();

      var store = Store<EmptyState>(
        (EmptyState state, dynamic action) {
          actual.add(action.type);
          return EmptyState();
        },
        initialState: EmptyState(),
        middleware: [
          applyMiddleware(sagaMiddleware),
        ],
      );

      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield Put(_Action('start parent'));
        //call child generator
        yield Call(failGen);
        yield Put(_Action('success parent'));
      }, Catch: (dynamic e, StackTrace s) sync* {
        yield Put(_Action(e));
        yield Put(_Action('failure parent'));
      });

      //saga should bubble synchronous call errors parent
      expect(task.toFuture().then((dynamic value) => actual),
          completion(['start parent', exceptionToBeCaught, 'failure parent']));
    });

    test('simple call test', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);

        var result = Result<dynamic>();
        yield Call(() sync* {
          execution.add(1);
          yield Return(value1);
        }, result: result);

        execution.add(2);

        yield Return(result.value);
        execution.add(3);
      }, Catch: (dynamic e, StackTrace s) {
        execution.add(4);
      }, Finally: () {
        execution.add(5);
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
            [0, 1, 2, 5]
          ]));
    });

    test('simple call test', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);

        var result = Result<dynamic>();
        yield Call(() {
          execution.add(1);
          return value1;
        }, result: result);

        execution.add(2);

        yield Return(result.value);
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
            [0, 1, 2]
          ]));
    });

    test('simple call test', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);

        var result = Result<dynamic>();
        yield Call(() async {
          execution.add(1);
          return value1;
        }, result: result);

        execution.add(2);

        yield Return(result.value);
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
            [0, 1, 2]
          ]));
    });

    test('simple call test throws', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);

        var result = Result<dynamic>();
        yield Call(() sync* {
          execution.add(1);
          throw exceptionToBeCaught;
        }, result: result);

        execution.add(2);

        yield Return(result.value);
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
            [0, 1]
          ]));
    });

    test('simple call test throws', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);

        var result = Result<dynamic>();
        yield Call(() {
          execution.add(1);
          throw exceptionToBeCaught;
        }, result: result);

        execution.add(2);

        yield Return(result.value);
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
            [0, 1]
          ]));
    });

    test('simple call test throws', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);

        var result = Result<dynamic>();
        yield Call(() async {
          execution.add(1);
          throw exceptionToBeCaught;
        }, result: result);

        execution.add(2);

        yield Return(result.value);
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
            [0, 1]
          ]));
    });

    test('simple call test throws', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);

        var result = Result<dynamic>();
        yield Call(() sync* {
          execution.add(1);
          yield Return(value1);
        }, Finally: () sync* {
          execution.add(2);
        }, result: result);

        execution.add(3);

        yield Return(result.value);
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
            [0, 1, 2, 3]
          ]));
    });

    test('simple call test throws', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);

        var result = Result<dynamic>();
        yield Call(() sync* {
          execution.add(1);
          yield Return(value1);
        }, Finally: () sync* {
          execution.add(2);
          yield Return(value2);
        }, result: result);

        execution.add(3);

        yield Return(result.value);
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
            [0, 1, 2, 3]
          ]));
    });

    test('simple call test', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);

        var result = Result<dynamic>();
        yield Call(() sync* {
          execution.add(1);
          yield Return(value1);
        }, Finally: () {
          execution.add(2);
        }, result: result);

        execution.add(3);

        yield Return(result.value);
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
            [0, 1, 2, 3]
          ]));
    });

    test('simple call test', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);

        var result = Result<dynamic>();
        yield Call(() sync* {
          execution.add(1);
          yield Return(value1);
        }, Finally: () sync* {
          execution.add(2);
          yield Return(value2);
        }, result: result);

        execution.add(3);

        yield Return(result.value);
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
            [0, 1, 2, 3]
          ]));
    });

    test('simple call test', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);

        var result = Result<dynamic>();
        yield Call(() sync* {
          execution.add(1);
          yield Return(value1);
        }, Finally: () async {
          execution.add(2);
        }, result: result);

        execution.add(3);

        yield Return(result.value);
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
            [0, 1, 2, 3]
          ]));
    });

    test('simple call test', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);

        var result = Result<dynamic>();
        yield Call(() sync* {
          execution.add(1);
          yield Return(value1);
        }, Finally: () sync* {
          execution.add(2);
          yield Return(value2);
        }, result: result);

        execution.add(3);

        yield Return(result.value);
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
            [0, 1, 2, 3]
          ]));
    });

    test('simple call test throws', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);

        var result = Result<dynamic>();
        yield Call(() sync* {
          execution.add(1);
          yield Return(value1);
        }, Finally: () sync* {
          execution.add(2);
          throw exceptionToBeCaught;
        }, result: result);

        execution.add(3);

        yield Return(result.value);
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

    test('simple call test throws', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);

        var result = Result<dynamic>();
        yield Call(() sync* {
          execution.add(1);
          yield Return(value1);
        }, Finally: () {
          execution.add(2);
          throw exceptionToBeCaught;
        }, result: result);

        execution.add(3);

        yield Return(result.value);
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

    test('simple call test throws', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);

        var result = Result<dynamic>();
        yield Call(() sync* {
          execution.add(1);
          yield Return(value1);
        }, Finally: () async {
          execution.add(2);
          throw exceptionToBeCaught;
        }, result: result);

        execution.add(3);

        yield Return(result.value);
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

    test('simple call test', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);

        var result = Result<dynamic>();
        yield Call(() sync* {
          execution.add(1);
          yield Return(value1);
        }, Catch: (dynamic e, StackTrace s) sync* {
          execution.add(2);
        }, Finally: () sync* {
          execution.add(3);
        }, result: result);

        execution.add(4);

        yield Return(result.value);
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
            [0, 1, 3, 4]
          ]));
    });

    test('simple call test', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);

        var result = Result<dynamic>();
        yield Call(() sync* {
          execution.add(1);
          throw exceptionToBeCaught;
        }, Catch: (dynamic e, StackTrace s) sync* {
          execution.add(2);
        }, Finally: () sync* {
          execution.add(3);
        }, result: result);

        execution.add(4);

        yield Return(result.value);
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
            [0, 1, 2, 3, 4]
          ]));
    });

    test('simple call test', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);

        var result = Result<dynamic>();
        yield Call(() {
          execution.add(1);
          throw exceptionToBeCaught;
        }, Catch: (dynamic e, StackTrace s) {
          execution.add(2);
        }, Finally: () {
          execution.add(3);
        }, result: result);

        execution.add(4);

        yield Return(result.value);
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
            [0, 1, 2, 3, 4]
          ]));
    });

    test('simple call test throws', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);

        var result = Result<dynamic>();
        yield Call(() async {
          execution.add(1);
          throw exceptionToBeCaught;
        }, Catch: (dynamic e, StackTrace s) async {
          execution.add(2);
        }, Finally: () async {
          execution.add(3);
        }, result: result);

        execution.add(4);

        yield Return(result.value);
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
            [0, 1, 2, 3, 4]
          ]));
    });

    test('simple call test', () {
      var execution = <int>[];
      dynamic caught;

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        var result = Result<dynamic>();
        yield Call(() sync* {
          execution.add(1);
          throw exceptionToBeCaught;
        }, Catch: (dynamic e, StackTrace s) sync* {
          caught = e;
          execution.add(2);
        }, Finally: () sync* {
          execution.add(3);
        }, result: result);

        execution.add(4);

        yield Return(result.value);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution,
                caught
              ]),
          completion([
            null,
            null,
            false,
            false,
            false,
            [0, 1, 2, 3, 4],
            exceptionToBeCaught
          ]));
    });

    test('simple call test throws', () {
      var execution = <int>[];
      dynamic caught;
      bool stackTraceIsNull;

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        var result = Result<dynamic>();
        yield Call(() sync* {
          execution.add(1);
          throw exceptionToBeCaught;
        }, Catch: (dynamic e, StackTrace s) sync* {
          caught = e;
          stackTraceIsNull = s == null;
          execution.add(2);
        }, Finally: () sync* {
          execution.add(3);
        }, result: result);

        execution.add(4);

        yield Return(result.value);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution,
                caught,
                stackTraceIsNull
              ]),
          completion([
            null,
            null,
            false,
            false,
            false,
            [0, 1, 2, 3, 4],
            exceptionToBeCaught,
            false
          ]));
    });

    test('simple call test', () {
      var execution = <int>[];
      dynamic caught;
      bool stackTraceIsNull;

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        var result = Result<dynamic>();
        yield Call(() {
          execution.add(1);
          throw exceptionToBeCaught;
        }, Catch: (dynamic e, StackTrace s) {
          caught = e;
          stackTraceIsNull = s == null;
          execution.add(2);
        }, Finally: () {
          execution.add(3);
        }, result: result);

        execution.add(4);

        yield Return(result.value);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution,
                caught,
                stackTraceIsNull
              ]),
          completion([
            null,
            null,
            false,
            false,
            false,
            [0, 1, 2, 3, 4],
            exceptionToBeCaught,
            false
          ]));
    });

    test('simple call test', () {
      var execution = <int>[];
      dynamic caught;
      bool stackTraceIsNull;

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        var result = Result<dynamic>();
        yield Call(() async {
          execution.add(1);
          throw exceptionToBeCaught;
        }, Catch: (dynamic e, StackTrace s) async {
          caught = e;
          stackTraceIsNull = s == null;
          execution.add(2);
        }, Finally: () async {
          execution.add(3);
        }, result: result);

        execution.add(4);

        yield Return(result.value);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                execution,
                caught,
                stackTraceIsNull
              ]),
          completion([
            null,
            null,
            false,
            false,
            false,
            [0, 1, 2, 3, 4],
            exceptionToBeCaught,
            false
          ]));
    });

    test('simple call cancel', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        var result = Result<dynamic>();
        yield Call(() sync* {
          execution.add(1);
          yield Cancel();
          yield Return(value1);
        }, Catch: (dynamic e, StackTrace s) async {
          execution.add(2);
        }, Finally: () async {
          execution.add(3);
        }, result: result);

        execution.add(4);

        yield Return(result.value);
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
            [0, 1, 3],
          ]));
    });

    test('simple call cancel', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        var result = Result<dynamic>();
        yield Call(() sync* {
          execution.add(1);
          yield Return(value1);
        }, Catch: (dynamic e, StackTrace s) sync* {
          execution.add(2);
        }, Finally: () sync* {
          execution.add(3);
          yield Cancel();
          execution.add(4);
        }, result: result);

        execution.add(5);

        yield Return(result.value);
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
            [0, 1, 3],
          ]));
    });

    test('call test', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        var result = Result<dynamic>();
        yield Call(() sync* {
          execution.add(1);
          var result2 = Result<dynamic>();
          yield Call(() sync* {
            execution.add(2);
            var result1 = Result<dynamic>();
            yield Call(() sync* {
              execution.add(3);
              yield Return(value1);
            }, result: result1);
            yield Return(result1.value);
          }, result: result2);
          yield Return(result2.value);
        }, result: result);

        execution.add(4);

        yield Return(result.value);
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
            [0, 1, 2, 3, 4],
          ]));
    });

    test('call test', () {
      var execution = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        execution.add(0);
        var result = Result<dynamic>();
        yield Call(() sync* {
          execution.add(1);
          var result2 = Result<dynamic>();
          yield Call(() sync* {
            execution.add(2);
            var result1 = Result<dynamic>();
            yield Call(() sync* {
              execution.add(3);
              yield Cancel();
              yield Return(value1);
            }, result: result1);
            yield Return(result1.value);
          }, result: result2);
          yield Return(result2.value);
        }, result: result);

        execution.add(4);

        yield Return(result.value);
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
            [0, 1, 2, 3],
          ]));
    });

    test('call test with context', () {
      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      sagaMiddleware.setContext(<dynamic, dynamic>{#api: SampleAPI(0)});

      var task = sagaMiddleware.run(() sync* {
        var context = Result<SampleAPI>();
        yield GetContext(#api, result: context);
        var result = Result<dynamic>();
        yield Call(context.value.increase);
        yield Call(context.value.increase);
        yield Call(context.value.increase);
        yield Call(context.value.getId, result: result);
        yield Return(result.value);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
              ]),
          completion([
            3,
            3,
            false,
            false,
            false,
          ]));
    });

    test('call test with context', () {
      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      sagaMiddleware.setContext(<dynamic, dynamic>{#api: SampleAPI(0)});
      var result1 = Result<int>();
      var result2 = Result<int>();

      var task = sagaMiddleware.run(() sync* {
        var context = Result<SampleAPI>();
        yield GetContext(#api, result: context);
        yield Call(context.value.increase);
        yield Call(context.value.increase);
        yield Call(context.value.increase);
        yield Call(context.value.getId, result: result1);

        yield SetContext(<dynamic, dynamic>{#api2: SampleAPI(5)});
        yield GetContext(#api2, result: context);
        yield Call(context.value.increase);
        yield Call(context.value.increase);
        yield Call(context.value.increase);
        yield Call(context.value.getId, result: result2);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                result1.value,
                result2.value
              ]),
          completion([null, null, false, false, false, 3, 8]));
    });
  });
}

class _C {
  int val;

  _C(this.val);

  Future<int> method() {
    return Future<int>.value(val);
  }
}

class _Action {
  dynamic type;

  _Action(this.type);
}
