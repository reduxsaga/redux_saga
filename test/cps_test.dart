import 'package:fake_async/fake_async.dart';
import 'package:redux/redux.dart';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/utils.dart';
import 'helpers/store.dart';

void main() {
  group('cps test', () {
    test('saga cps call handling', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield Try(() sync* {
          yield CPS(({CPSCallback? cb}) {
            actual.add('call 1');
            cb!.callback(err: 'err');
          });
          actual.add('call 2');
        }, Catch: (dynamic e, StackTrace s) sync* {
          actual.add('call $e');
        });
      });

      //saga must fulfill cps call effects
      expect(task.toFuture().then((dynamic value) => actual),
          completion(['call 1', 'call err']));
    });

    test('saga synchronous cps failures handling', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createSagaMiddleware();

      var store = Store<EmptyState>(
        (EmptyState state, dynamic action) {
          actual.add(action.payload);
          return EmptyState();
        },
        initialState: EmptyState(),
        middleware: [
          applyMiddleware(sagaMiddleware),
        ],
      );

      sagaMiddleware.setStore(store);

      Iterable<Effect> genFnChild() sync* {
        yield Try(() sync* {
          yield Put(TestActionC('startChild'));
          yield CPS(() {
            throw Exception('child error');
          });
          yield Put(TestActionC('success child'));
        }, Catch: (dynamic e, StackTrace s) sync* {
          yield Put(TestActionC('failure child'));
        });
      }

      Iterable<Effect> genFnParent() sync* {
        yield Try(() sync* {
          yield Put(TestActionC('start parent'));
          yield Call(genFnChild);
          yield Put(TestActionC('success parent'));
        }, Catch: (dynamic e, StackTrace s) sync* {
          yield Put(TestActionC('failure parent'));
        });
      }

      var task = sagaMiddleware.run(genFnParent);

      //saga should inject call error into generator
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            'start parent',
            'startChild',
            'failure child',
            'success parent'
          ]));
    });

    test('saga cps cancellation handling', () {
      var cancelled = false;

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      void cpsFn({CPSCallback? cb}) {
        cb!.cancel = () {
          cancelled = true;
        };
      }

      var task = sagaMiddleware.run(() sync* {
        var forkedTask = Result<Task>();
        yield Fork(() sync* {
          yield CPS(cpsFn);
        }, result: forkedTask);

        yield Cancel([forkedTask.value!]);
      });

      //saga should call cancellation function on callback
      expect(
          task.toFuture().then((dynamic value) => cancelled), completion(true));
    });

    test('cps test', () {
      fakeAsync((async) {
        var execution = <int>[];

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          var result = Result<dynamic>();
          yield CPS(testCPS1, args: <dynamic>[execution], result: result);

          execution.add(2);

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
              [0, 1, 2]
            ]));

        async.elapse(Duration(milliseconds: 500));
      });
    });

    test('cps test', () {
      fakeAsync((async) {
        var execution = <int>[];

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          var result = Result<dynamic>();
          yield CPS(testCPS2, args: <dynamic>[execution], result: result);

          execution.add(2);

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
              [0, 1, 2]
            ]));
        async.elapse(Duration(milliseconds: 500));
      });
    });

    test('cps cancel test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var forkResult = Result<dynamic>();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Fork(() sync* {
            execution.add(1);
            yield CPS(testCPS3, args: <dynamic>[execution], result: forkResult);
          });

          execution.add(3);

          yield Cancel();
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
              [0, 1, 2, 3, 4]
            ]));
        async.elapse(Duration(milliseconds: 500));
      });
    });
  });
}
