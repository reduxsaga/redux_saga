import 'dart:async';
import 'package:redux/redux.dart';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/store.dart';
import 'helpers/utils.dart';

void main() {
  group('base tests', () {
    test('saga iteration', () {
      var actual = <int?>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        var r = Result<int>();
        yield Call(() => 1, result: r);
        actual.add(r.value);
        yield Call(() => 2, result: r);
        actual.add(r.value);
        yield Return(3);
      });

      // saga should return a Task
      expect(task, TypeMatcher<Task>());

      // saga should return a future of the iterator result
      expect(task.toFuture(), TypeMatcher<Future>());

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.isRunning, // saga's iterator should return false from isRunning
                task.result, // saga returned future should resolve with the iterator Return effect
                actual // saga should collect yielded values from the iterator
              ]),
          completion([
            3,
            false,
            3,
            [1, 2]
          ]));
    });

    test('saga error handling', () {
      dynamic error;

      var sagaMiddleware =
          createMiddleware(options: Options(onError: (dynamic e, String s) {
        error = e;
      }));
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      void fnThrow() {
        throw exceptionToBeCaught;
      }

      //throws
      Iterable<Effect> genThrow() sync* {
        fnThrow();
      }

      var task1 = sagaMiddleware.run(genThrow);

      //saga must return a rejected future if generator throws an uncaught error
      expect(task1.toFuture(), throwsA(exceptionToBeCaught));

      //      //middleware on error must be invoked
      expect(task1.toFuture().catchError((dynamic e) => <dynamic>[e, error]),
          completion([exceptionToBeCaught, exceptionToBeCaught]));

      expect(task1.toFuture().catchError((dynamic e) => e),
          completion(exceptionToBeCaught));

      //try + catch + finally
      var actual = <dynamic>[];

      Iterable<Effect> genFinally() sync* {
        yield Try(() sync* {
          fnThrow();
          actual.add('unreachable');
        }, Catch: (dynamic error, StackTrace s) sync* {
          actual.add(<dynamic>['caught', error]);
        }, Finally: () sync* {
          actual.add('finally');
        });
      }

      var task2 = sagaMiddleware.run(genFinally);

      expect(
          task2.toFuture().then((dynamic value) => actual),
          completion([
            ['caught', exceptionToBeCaught],
            'finally'
          ]));
    });

    test('saga output handling', () {
      var actual = <dynamic>[];

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

      var task = sagaMiddleware.run((dynamic arg) sync* {
        yield Put(_Action(arg));
        yield Put(_Action(2));
      }, args: <dynamic>['arg']);

      //saga must handle generator output
      expect(task.toFuture().then((dynamic value) => actual),
          completion(['arg', 2]));
    });
  });
}

class _Action {
  final dynamic type;

  _Action(this.type);
}
