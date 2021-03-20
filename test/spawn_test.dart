import 'package:fake_async/fake_async.dart';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/utils.dart';
import 'helpers/store.dart';

void main() {
  group('spawn test', () {
    test('spawn test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var spawnedTask = Result<Task>();

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Spawn(() sync* {}, result: spawnedTask);

          execution.add(1);

          yield Return(value1);
          execution.add(2);
        });

        spawnedTask.value!.toFuture().then((dynamic v) => taskCompletion.add(0));
        task.toFuture().then((dynamic v) => taskCompletion.add(1));

        expect(
            task.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  task.result,
                  task.isRunning,
                  task.isCancelled,
                  task.isAborted,
                  execution,
                  taskCompletion
                ]),
            completion([
              value1,
              value1,
              false,
              false,
              false,
              [0, 1],
              [0, 1]
            ]));
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('spawn test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];

        var spawnedTask = Result<Task>();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Spawn(() sync* {
            yield Delay(Duration(milliseconds: 1));
          }, result: spawnedTask);

          execution.add(1);

          yield Return(value1);
          execution.add(2);
        });

        spawnedTask.value!.toFuture().then((dynamic v) => taskCompletion.add(0));
        task.toFuture().then((dynamic v) => taskCompletion.add(1));

        expect(
            task.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  task.result,
                  task.isRunning,
                  task.isCancelled,
                  task.isAborted,
                  execution,
                  taskCompletion
                ]),
            completion([
              value1,
              value1,
              false,
              false,
              false,
              [0, 1],
              [1]
            ]));

        //spawned task finished after main task
        expect(
            spawnedTask.value!
                .toFuture()
                .then((dynamic value) => taskCompletion),
            completion([1, 0]));

        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('spawn test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var spawnedTask = Result<Task>();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Spawn(() sync* {}, result: spawnedTask);

          execution.add(1);

          yield Delay(Duration(milliseconds: 1));

          yield Return(value1);
          execution.add(2);
        });

        spawnedTask.value!.toFuture().then((dynamic v) => taskCompletion.add(0));
        task.toFuture().then((dynamic v) => taskCompletion.add(1));

        expect(
            task.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  task.result,
                  task.isRunning,
                  task.isCancelled,
                  task.isAborted,
                  execution,
                  taskCompletion
                ]),
            completion([
              value1,
              value1,
              false,
              false,
              false,
              [0, 1],
              [0, 1]
            ]));

        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('spawn test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();
        var spawnedTaskA = Result<Task>();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Spawn(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
          }, result: spawnedTaskA);

          execution.add(1);

          yield Cancel();

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
          }

          yield Return(value1);
          execution.add(2);
        });

        spawnedTaskA.value!
            .toFuture()
            .then((dynamic v) => taskCompletion.add(0));
        task.toFuture().then((dynamic v) => taskCompletion.add(1));

        expect(
            task.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  task.result,
                  task.isRunning,
                  task.isCancelled,
                  task.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              TaskCancel,
              TaskCancel,
              false,
              true,
              false,
              [0, 1],
              [1],
              equals('0')
            ]));

        expect(
            spawnedTaskA.value!.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  spawnedTaskA.value!.result,
                  spawnedTaskA.value!.isRunning,
                  spawnedTaskA.value!.isCancelled,
                  spawnedTaskA.value!.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              null,
              null,
              false,
              false,
              false,
              [0, 1],
              [1, 0],
              equals('0123456789')
            ]));
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('spawn test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();
        var spawnedTaskA = Result<Task>();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Spawn(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
              if (i == 5) throw exceptionToBeCaught;
            }
          }, result: spawnedTaskA);

          execution.add(1);

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
          }

          yield Return(value1);
          execution.add(2);
        });

        task.toFuture().then((dynamic v) => taskCompletion.add(1));
        spawnedTaskA.value!
            .toFuture()
            .then((dynamic v) => taskCompletion.add(0))
            .catchError((dynamic e, StackTrace s) {
          taskCompletion.add(0);
        });

        expect(
            task.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  task.result,
                  task.isRunning,
                  task.isCancelled,
                  task.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              value1,
              value1,
              false,
              false,
              false,
              [0, 1],
              [0, 1],
              equals('0011223344556789')
            ]));

        expect(
            spawnedTaskA.value!
                .toFuture()
                .catchError((dynamic error) => <dynamic>[
                      error,
                      spawnedTaskA.value!.result,
                      spawnedTaskA.value!.isRunning,
                      spawnedTaskA.value!.isCancelled,
                      spawnedTaskA.value!.isAborted,
                      execution,
                      taskCompletion,
                      values.toString()
                    ]),
            completion([
              exceptionToBeCaught,
              null,
              false,
              false,
              true,
              [0, 1],
              [0],
              equals('001122334455')
            ]));
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('spawn test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();
        var spawnedTaskA = Result<Task>();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Spawn(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
          }, result: spawnedTaskA);

          execution.add(1);

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
            if (i == 5) throw exceptionToBeCaught;
          }
        });

        spawnedTaskA.value!
            .toFuture()
            .then((dynamic v) => taskCompletion.add(0));
        task
            .toFuture()
            .then((dynamic v) => taskCompletion.add(1))
            .catchError((dynamic e, StackTrace s) {
          taskCompletion.add(1);
        });

        expect(
            task.toFuture().catchError((dynamic error) => <dynamic>[
                  error,
                  task.result,
                  task.isRunning,
                  task.isCancelled,
                  task.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              exceptionToBeCaught,
              null,
              false,
              false,
              true,
              [0, 1],
              [1],
              equals('0011223344556')
            ]));

        expect(
            spawnedTaskA.value!.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  spawnedTaskA.value!.result,
                  spawnedTaskA.value!.isRunning,
                  spawnedTaskA.value!.isCancelled,
                  spawnedTaskA.value!.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              null,
              null,
              false,
              false,
              false,
              [0, 1],
              [1, 0],
              equals('0011223344556789')
            ]));
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('spawn test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();
        var spawnedTaskA = Result<Task>();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Spawn(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
          }, result: spawnedTaskA);

          execution.add(1);

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
          }

          yield Return(value1);
          execution.add(2);
        });

        spawnedTaskA.value!
            .toFuture()
            .then((dynamic v) => taskCompletion.add(0));
        task.toFuture().then((dynamic v) => taskCompletion.add(1));

        expect(
            task.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  task.result,
                  task.isRunning,
                  task.isCancelled,
                  task.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              value1,
              value1,
              false,
              false,
              false,
              [0, 1],
              [0, 1],
              equals('00112233445566778899')
            ]));

        expect(
            spawnedTaskA.value!.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  spawnedTaskA.value!.result,
                  spawnedTaskA.value!.isRunning,
                  spawnedTaskA.value!.isCancelled,
                  spawnedTaskA.value!.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              null,
              null,
              false,
              false,
              false,
              [0, 1],
              [0],
              equals('00112233445566778899')
            ]));
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('spawn test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();
        var spawnedTaskA = Result<Task>();
        var spawnedTaskB = Result<Task>();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Spawn(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
          }, result: spawnedTaskA);

          execution.add(1);

          yield Spawn(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
          }, result: spawnedTaskB);

          execution.add(2);

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
          }

          yield Return(value1);
          execution.add(3);
        });

        spawnedTaskA.value!
            .toFuture()
            .then((dynamic v) => taskCompletion.add(0));
        spawnedTaskB.value!
            .toFuture()
            .then((dynamic v) => taskCompletion.add(1));
        task.toFuture().then((dynamic v) => taskCompletion.add(2));

        expect(
            task.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  task.result,
                  task.isRunning,
                  task.isCancelled,
                  task.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              value1,
              value1,
              false,
              false,
              false,
              [0, 1, 2],
              [0, 1, 2],
              equals('000111222333444555666777888999')
            ]));

        expect(
            spawnedTaskA.value!.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  spawnedTaskA.value!.result,
                  spawnedTaskA.value!.isRunning,
                  spawnedTaskA.value!.isCancelled,
                  spawnedTaskA.value!.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              null,
              null,
              false,
              false,
              false,
              [0, 1, 2],
              [0],
              equals('000111222333444555666777888999')
            ]));

        expect(
            spawnedTaskB.value!.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  spawnedTaskB.value!.result,
                  spawnedTaskB.value!.isRunning,
                  spawnedTaskB.value!.isCancelled,
                  spawnedTaskB.value!.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              null,
              null,
              false,
              false,
              false,
              [0, 1, 2],
              [0, 1],
              equals('000111222333444555666777888999')
            ]));
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('spawn test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();
        var spawnedTaskA = Result<Task>();
        var spawnedTaskB = Result<Task>();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Spawn(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
          }, result: spawnedTaskA);

          execution.add(1);

          yield Spawn(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
          }, result: spawnedTaskB);

          execution.add(2);

          yield Cancel();

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
          }

          yield Return(value1);
          execution.add(3);
        });

        spawnedTaskA.value!
            .toFuture()
            .then((dynamic v) => taskCompletion.add(0));
        spawnedTaskB.value!
            .toFuture()
            .then((dynamic v) => taskCompletion.add(1));
        task.toFuture().then((dynamic v) => taskCompletion.add(2));

        expect(
            task.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  task.result,
                  task.isRunning,
                  task.isCancelled,
                  task.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              TaskCancel,
              TaskCancel,
              false,
              true,
              false,
              [0, 1, 2],
              [2],
              equals('00')
            ]));

        expect(
            spawnedTaskA.value!.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  spawnedTaskA.value!.result,
                  spawnedTaskA.value!.isRunning,
                  spawnedTaskA.value!.isCancelled,
                  spawnedTaskA.value!.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              null,
              null,
              false,
              false,
              false,
              [0, 1, 2],
              [2, 0],
              equals('00112233445566778899')
            ]));

        expect(
            spawnedTaskB.value!.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  spawnedTaskB.value!.result,
                  spawnedTaskB.value!.isRunning,
                  spawnedTaskB.value!.isCancelled,
                  spawnedTaskB.value!.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              null,
              null,
              false,
              false,
              false,
              [0, 1, 2],
              [2, 0, 1],
              equals('00112233445566778899')
            ]));
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('spawn test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();
        var spawnedTaskA = Result<Task>();
        var spawnedTaskB = Result<Task>();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Spawn(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
          }, result: spawnedTaskA);

          execution.add(1);

          yield Spawn(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
          }, result: spawnedTaskB);

          execution.add(2);

          yield Cancel([spawnedTaskA.value!]);

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
          }

          yield Return(value1);
          execution.add(3);
        });

        spawnedTaskA.value!
            .toFuture()
            .then((dynamic v) => taskCompletion.add(0));
        spawnedTaskB.value!
            .toFuture()
            .then((dynamic v) => taskCompletion.add(1));
        task.toFuture().then((dynamic v) => taskCompletion.add(2));

        expect(
            task.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  task.result,
                  task.isRunning,
                  task.isCancelled,
                  task.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              value1,
              value1,
              false,
              false,
              false,
              [0, 1, 2],
              [0, 1, 2],
              equals('000112233445566778899')
            ]));

        expect(
            spawnedTaskA.value!.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  spawnedTaskA.value!.result,
                  spawnedTaskA.value!.isRunning,
                  spawnedTaskA.value!.isCancelled,
                  spawnedTaskA.value!.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              TaskCancel,
              TaskCancel,
              false,
              true,
              false,
              [0, 1, 2],
              [0],
              equals('000')
            ]));

        expect(
            spawnedTaskB.value!.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  spawnedTaskB.value!.result,
                  spawnedTaskB.value!.isRunning,
                  spawnedTaskB.value!.isCancelled,
                  spawnedTaskB.value!.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              null,
              null,
              false,
              false,
              false,
              [0, 1, 2],
              [0, 1],
              equals('000112233445566778899')
            ]));
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('spawn test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();
        var spawnedTaskA = Result<Task>();
        var spawnedTaskB = Result<Task>();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Spawn(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
          }, result: spawnedTaskA);

          execution.add(1);

          yield Spawn(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
          }, result: spawnedTaskB);

          execution.add(2);

          yield Cancel([spawnedTaskA.value!, spawnedTaskB.value!]);

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
          }

          yield Return(value1);
          execution.add(3);
        });

        spawnedTaskA.value!
            .toFuture()
            .then((dynamic v) => taskCompletion.add(0));
        spawnedTaskB.value!
            .toFuture()
            .then((dynamic v) => taskCompletion.add(1));
        task.toFuture().then((dynamic v) => taskCompletion.add(2));

        expect(
            task.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  task.result,
                  task.isRunning,
                  task.isCancelled,
                  task.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              value1,
              value1,
              false,
              false,
              false,
              [0, 1, 2],
              [0, 1, 2],
              equals('000123456789')
            ]));

        expect(
            spawnedTaskA.value!.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  spawnedTaskA.value!.result,
                  spawnedTaskA.value!.isRunning,
                  spawnedTaskA.value!.isCancelled,
                  spawnedTaskA.value!.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              TaskCancel,
              TaskCancel,
              false,
              true,
              false,
              [0, 1, 2],
              [0],
              equals('000')
            ]));

        expect(
            spawnedTaskB.value!.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  spawnedTaskB.value!.result,
                  spawnedTaskB.value!.isRunning,
                  spawnedTaskB.value!.isCancelled,
                  spawnedTaskB.value!.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              TaskCancel,
              TaskCancel,
              false,
              true,
              false,
              [0, 1, 2],
              [0, 1],
              equals('000')
            ]));
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('spawn test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();
        var spawnedTaskA = Result<Task>();
        var spawnedTaskB = Result<Task>();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var joinResult = JoinResult();

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Spawn(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
            yield Return('A');
          }, result: spawnedTaskA);

          execution.add(1);

          yield Spawn(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
          }, result: spawnedTaskB);

          execution.add(2);

          yield Join(<dynamic, Task>{#spawnA: spawnedTaskA.value!},
              result: joinResult);

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
          }

          yield Return(value1);
          execution.add(3);
        });

        spawnedTaskA.value!
            .toFuture()
            .then((dynamic v) => taskCompletion.add(0));
        spawnedTaskB.value!
            .toFuture()
            .then((dynamic v) => taskCompletion.add(1));
        task.toFuture().then((dynamic v) => taskCompletion.add(2));

        expect(
            task.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  task.result,
                  task.isRunning,
                  task.isCancelled,
                  task.isAborted,
                  execution,
                  taskCompletion,
                  values.toString(),
                  joinResult.value
                ]),
            completion([
              value1,
              value1,
              false,
              false,
              false,
              [0, 1, 2],
              [0, 1, 2],
              equals('001122334455667788990123456789'),
              <dynamic, dynamic>{#spawnA: 'A'}
            ]));

        expect(
            spawnedTaskA.value!.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  spawnedTaskA.value!.result,
                  spawnedTaskA.value!.isRunning,
                  spawnedTaskA.value!.isCancelled,
                  spawnedTaskA.value!.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              'A',
              'A',
              false,
              false,
              false,
              [0, 1, 2],
              [0],
              equals('001122334455667788990')
            ]));

        expect(
            spawnedTaskB.value!.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  spawnedTaskB.value!.result,
                  spawnedTaskB.value!.isRunning,
                  spawnedTaskB.value!.isCancelled,
                  spawnedTaskB.value!.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              null,
              null,
              false,
              false,
              false,
              [0, 1, 2],
              [0, 1],
              equals('001122334455667788990')
            ]));
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('spawn test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();
        var spawnedTaskA = Result<Task>();
        var spawnedTaskB = Result<Task>();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var joinResult = JoinResult();

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Spawn(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
            yield Return('A');
          }, result: spawnedTaskA);

          execution.add(1);

          yield Spawn(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
            yield Return('B');
          }, result: spawnedTaskB);

          execution.add(2);

          yield Join(<dynamic, Task>{
            #spawnA: spawnedTaskA.value!,
            #spawnB: spawnedTaskB.value!
          }, result: joinResult);

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
          }

          yield Return(value1);
          execution.add(3);
        });

        spawnedTaskA.value!
            .toFuture()
            .then((dynamic v) => taskCompletion.add(0));
        spawnedTaskB.value!
            .toFuture()
            .then((dynamic v) => taskCompletion.add(1));
        task.toFuture().then((dynamic v) => taskCompletion.add(2));

        expect(
            task.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  task.result,
                  task.isRunning,
                  task.isCancelled,
                  task.isAborted,
                  execution,
                  taskCompletion,
                  values.toString(),
                  joinResult.value
                ]),
            completion([
              value1,
              value1,
              false,
              false,
              false,
              [0, 1, 2],
              [0, 1, 2],
              equals('001122334455667788990123456789'),
              <dynamic, dynamic>{#spawnA: 'A', #spawnB: 'B'}
            ]));

        expect(
            spawnedTaskA.value!.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  spawnedTaskA.value!.result,
                  spawnedTaskA.value!.isRunning,
                  spawnedTaskA.value!.isCancelled,
                  spawnedTaskA.value!.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              'A',
              'A',
              false,
              false,
              false,
              [0, 1, 2],
              [0],
              equals('00112233445566778899')
            ]));

        expect(
            spawnedTaskB.value!.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  spawnedTaskB.value!.result,
                  spawnedTaskB.value!.isRunning,
                  spawnedTaskB.value!.isCancelled,
                  spawnedTaskB.value!.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              'B',
              'B',
              false,
              false,
              false,
              [0, 1, 2],
              [0, 1],
              equals('001122334455667788990')
            ]));
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('spawn test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();

        var spawnedTaskA = Result<Task>();
        var spawnedTaskB = Result<Task>();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var joinResult = JoinResult();

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Spawn(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
              if (i == 5) yield Cancel();
            }
            yield Return('A');
          }, Finally: () {
            execution.add(1);
          }, result: spawnedTaskA);

          execution.add(2);

          yield Spawn(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
            yield Return('B');
          }, Finally: () {
            execution.add(3);
          }, result: spawnedTaskB);

          execution.add(4);

          yield Join(<dynamic, Task>{
            #spawnA: spawnedTaskA.value!,
            #spawnB: spawnedTaskB.value!
          }, result: joinResult);

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
          }

          yield Return(value1);
          execution.add(5);
        }, Finally: () {
          execution.add(6);
        });

        spawnedTaskA.value!
            .toFuture()
            .then((dynamic v) => taskCompletion.add(0));
        spawnedTaskB.value!
            .toFuture()
            .then((dynamic v) => taskCompletion.add(1));
        task.toFuture().then((dynamic v) => taskCompletion.add(2));

        //joined task cancel will cancel root also
        expect(
            task.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  task.result,
                  task.isRunning,
                  task.isCancelled,
                  task.isAborted,
                  execution,
                  taskCompletion,
                  values.toString(),
                  joinResult.value
                ]),
            completion([
              TaskCancel,
              TaskCancel,
              false,
              true,
              false,
              [0, 2, 4, 1, 6],
              [0, 2],
              equals('001122334455'),
              null
            ]));

        expect(
            spawnedTaskA.value!.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  spawnedTaskA.value!.result,
                  spawnedTaskA.value!.isRunning,
                  spawnedTaskA.value!.isCancelled,
                  spawnedTaskA.value!.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              TaskCancel,
              TaskCancel,
              false,
              true,
              false,
              [0, 2, 4, 1, 6],
              [0],
              equals('001122334455')
            ]));

        expect(
            spawnedTaskB.value!.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  spawnedTaskB.value!.result,
                  spawnedTaskB.value!.isRunning,
                  spawnedTaskB.value!.isCancelled,
                  spawnedTaskB.value!.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              'B',
              'B',
              false,
              false,
              false,
              [0, 2, 4, 1, 6, 3],
              [0, 2, 1],
              equals('0011223344556789')
            ]));
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('spawn test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();
        var spawnedTaskA = Result<Task>();
        var spawnedTaskB = Result<Task>();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var joinResult = JoinResult();

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Spawn(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
              if (i == 5) yield Cancel();
            }
            yield Return('A');
          }, result: spawnedTaskA);

          execution.add(1);

          yield Spawn(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
            yield Return('B');
          }, result: spawnedTaskB);

          execution.add(2);

          yield Join(<dynamic, Task>{
            #spawnA: spawnedTaskA.value!,
            #spawnB: spawnedTaskB.value!
          }, result: joinResult);

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
          }

          yield Return(value1);
          execution.add(3);
        });

        spawnedTaskA.value!
            .toFuture()
            .then((dynamic v) => taskCompletion.add(0));
        spawnedTaskB.value!
            .toFuture()
            .then((dynamic v) => taskCompletion.add(1));
        task.toFuture().then((dynamic v) => taskCompletion.add(2));

        //joined task cancel will cancel root also
        expect(
            task.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  task.result,
                  task.isRunning,
                  task.isCancelled,
                  task.isAborted,
                  execution,
                  taskCompletion,
                  values.toString(),
                  joinResult.value
                ]),
            completion([
              TaskCancel,
              TaskCancel,
              false,
              true,
              false,
              [0, 1, 2],
              [0, 2],
              equals('001122334455'),
              null
            ]));

        expect(
            spawnedTaskA.value!.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  spawnedTaskA.value!.result,
                  spawnedTaskA.value!.isRunning,
                  spawnedTaskA.value!.isCancelled,
                  spawnedTaskA.value!.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              TaskCancel,
              TaskCancel,
              false,
              true,
              false,
              [0, 1, 2],
              [0],
              equals('001122334455')
            ]));

        expect(
            spawnedTaskB.value!.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  spawnedTaskB.value!.result,
                  spawnedTaskB.value!.isRunning,
                  spawnedTaskB.value!.isCancelled,
                  spawnedTaskB.value!.isAborted,
                  execution,
                  taskCompletion,
                  values.toString()
                ]),
            completion([
              'B',
              'B',
              false,
              false,
              false,
              [0, 1, 2],
              [0, 2, 1],
              equals('0011223344556789')
            ]));
        async.elapse(Duration(milliseconds: 100));
      });
    });
  });
}
