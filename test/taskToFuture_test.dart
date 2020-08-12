import 'package:fake_async/fake_async.dart';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/utils.dart';
import 'helpers/store.dart';

void main() {
  group('taskToFuture tests', () {
    test('calling toFuture() of an already completed task', () {
      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield Return(value1);
      });

      expect(task.isRunning, equals(false));
      expect(task.toFuture(), completion(equals(value1)));
      expect(task.result, equals(value1));
    });

    test('calling toFuture() before a task completes', () {
      fakeAsync((async) {
        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          yield Delay(Duration(milliseconds: 10));
          yield Return(value1);
        });

        expect(task.isRunning, equals(true));
        expect(task.toFuture(), completion(equals(value1)));

        async.elapse(Duration(milliseconds: 100));

        expect(task.isRunning, equals(false));
        expect(task.result, equals(value1));
      });
    });

    test('calling toFuture() of an already aborted task', () {
      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        throw exceptionToBeCaught;
      });

      expect(task.isRunning, equals(false));
      expect(task.toFuture(), throwsA(equals(exceptionToBeCaught)));
      expect(task.result, equals(null));
    });

    test('calling toFuture() before a task aborts', () {
      fakeAsync((async) {
        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          yield Delay(Duration(milliseconds: 10));
          throw exceptionToBeCaught;
        });

        expect(task.isRunning, equals(true));
        expect(task.toFuture(), throwsA(equals(exceptionToBeCaught)));

        async.elapse(Duration(milliseconds: 100));

        expect(task.isRunning, equals(false));
        expect(task.result, equals(null));
        expect(task.error, equals(exceptionToBeCaught));
      });
    });

    test('calling toFuture() of before a task gets cancelled', () {
      fakeAsync((async) {
        var forkedTask = Result<Task>();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          yield Fork(() sync* {
            yield Delay(Duration(seconds: 10));
          }, result: forkedTask);
          yield Delay(Duration(milliseconds: 10));
          yield Cancel([forkedTask.value]);
        });

        expect(task.isRunning, equals(true));
        expect(forkedTask.value.isRunning, equals(true));
        expect(task.toFuture(), completion(equals(null)));
        expect(forkedTask.value.toFuture(), completion(equals(TaskCancel)));

        async.elapse(Duration(milliseconds: 100));

        expect(task.isRunning, equals(false));
        expect(forkedTask.value.isRunning, equals(false));
        expect(task.result, equals(null));
        expect(forkedTask.value.result, equals(TaskCancel));
      });
    });
  });
}
