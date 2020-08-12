import 'package:fake_async/fake_async.dart';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/utils.dart';
import 'helpers/store.dart';

void main() {
  group('cancelled test', () {
    test('cancelled test', () {
      var isRootCancelled = Result<bool>();

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield Return(value1);
      }, Finally: () sync* {
        yield Cancelled(result: isRootCancelled);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                isRootCancelled.value
              ]),
          completion([value1, value1, false, false, false, false]));
    });

    test('cancelled test', () {
      var isRootCancelled = Result<bool>();

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield Cancel();
        yield Return(value1);
      }, Finally: () sync* {
        yield Cancelled(result: isRootCancelled);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                isRootCancelled.value
              ]),
          completion([TaskCancel, TaskCancel, false, true, false, true]));
    });

    test('cancelled test', () {
      var isRootCancelled = Result<bool>();

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        throw exceptionToBeCaught;
      }, Finally: () sync* {
        yield Cancelled(result: isRootCancelled);
      });

      expect(
          task.toFuture().catchError((dynamic error) => <dynamic>[
                error,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                isRootCancelled.value
              ]),
          completion([exceptionToBeCaught, null, false, false, true, false]));
    });

    test('cancelled test', () {
      var isRootCancelled = Result<bool>();
      var isforkedTaskCancelled = Result<bool>();
      var forkedTaskA = Result<Task>();

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield Fork(() sync* {
          yield Cancel();
        }, Finally: () sync* {
          yield Cancelled(result: isforkedTaskCancelled);
        }, result: forkedTaskA);
      }, Finally: () sync* {
        yield Cancelled(result: isRootCancelled);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                isRootCancelled.value
              ]),
          completion([null, null, false, false, false, false]));

      expect(
          forkedTaskA.value.toFuture().then((dynamic value) => <dynamic>[
                value,
                forkedTaskA.value.result,
                forkedTaskA.value.isRunning,
                forkedTaskA.value.isCancelled,
                forkedTaskA.value.isAborted,
                isforkedTaskCancelled.value
              ]),
          completion([TaskCancel, TaskCancel, false, true, false, true]));
    });

    test('cancelled test', () {
      var isRootCancelled = Result<bool>();
      var isforkedTaskCancelled = Result<bool>();
      var forkedTaskA = Result<Task>();

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield Fork(() sync* {
          yield Cancel();
        }, Finally: () sync* {
          yield Cancelled(result: isforkedTaskCancelled);
        }, result: forkedTaskA);

        yield Join(<dynamic, Task>{#forkA: forkedTaskA.value});
      }, Finally: () sync* {
        yield Cancelled(result: isRootCancelled);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                isRootCancelled.value
              ]),
          completion([TaskCancel, TaskCancel, false, true, false, true]));

      expect(
          forkedTaskA.value.toFuture().then((dynamic value) => <dynamic>[
                value,
                forkedTaskA.value.result,
                forkedTaskA.value.isRunning,
                forkedTaskA.value.isCancelled,
                forkedTaskA.value.isAborted,
                isforkedTaskCancelled.value
              ]),
          completion([TaskCancel, TaskCancel, false, true, false, true]));
    });

    test('cancelled test', () {
      fakeAsync((async) {
        var isRootCancelled = Result<bool>();
        var isforkedTaskCancelled = Result<bool>();
        var forkedTaskA = Result<Task>();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          yield Fork(() sync* {
            yield Delay(Duration(seconds: 1));
          }, Finally: () sync* {
            yield Cancelled(result: isforkedTaskCancelled);
          }, result: forkedTaskA);

          yield Cancel([forkedTaskA.value]);
        }, Finally: () sync* {
          yield Cancelled(result: isRootCancelled);
        });

        expect(
            task.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  task.result,
                  task.isRunning,
                  task.isCancelled,
                  task.isAborted,
                  isRootCancelled.value
                ]),
            completion([null, null, false, false, false, false]));

        expect(
            forkedTaskA.value.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  forkedTaskA.value.result,
                  forkedTaskA.value.isRunning,
                  forkedTaskA.value.isCancelled,
                  forkedTaskA.value.isAborted,
                  isforkedTaskCancelled.value
                ]),
            completion([TaskCancel, TaskCancel, false, true, false, true]));

        async.elapse(Duration(milliseconds: 100));
      });
    });
  });
}
