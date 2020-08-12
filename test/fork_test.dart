import 'package:fake_async/fake_async.dart';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/utils.dart';
import 'helpers/store.dart';

void main() {
  group('fork test', () {
    test('should not interpret returned effect. fork(() => effectCreator())', () {
      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      dynamic fn() {
        return null;
      }

      var call = Call(fn);

      var task = sagaMiddleware.run(() sync* {
        var forkedTask = Result<Task>();
        yield Fork(() => call, result: forkedTask);
        yield Return(forkedTask.value.toFuture());
      });

      expect(task.toFuture(), completion(call));
    });

    test('should not interpret returned effect. yield fork(takeEvery, \'pattern\', fn)', () {
      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      dynamic fn() {
        return null;
      }

      var takeEvery = TakeEvery(fn, pattern: 'pattern');

      var task = sagaMiddleware.run(() sync* {
        var forkedTask = Result<Task>();
        yield Fork(() => takeEvery, result: forkedTask);
        yield Return(forkedTask.value.toFuture());
      });

      expect(task.toFuture(), completion(takeEvery));
    });

    test('should interpret returned future. fork(() => future)', () {
      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        var forkedTask = Result<Task>();
        yield Fork(() => Future<String>(() => 'a'), result: forkedTask);
        yield Return(forkedTask.value.toFuture());
      });

      expect(task.toFuture(), completion('a'));
    });

    test('should handle future that resolves undefined properly. fork(() => Future(()=>null))', () {
      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        var forkedTask = Result<Task>();
        yield Fork(() => Future<dynamic>(() => null), result: forkedTask);
        yield Return(forkedTask.value.toFuture());
      });

      expect(task.toFuture(), completion(null));
    });

    test('should interpret returned iterator. fork(() => iterator)', () {
      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        var forkedTask = Result<Task>();
        yield Fork(() sync* {
          yield Call(() => 1);
          yield Return('b');
        }, result: forkedTask);
        yield Return(forkedTask.value.toFuture());
      });

      expect(task.toFuture(), completion('b'));
    });

    test('simple fork test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var forkedTask = Result<Task>();

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Fork(() sync* {}, result: forkedTask);

          execution.add(1);

          yield Return(value1);
          execution.add(2);
        });

        forkedTask.value.toFuture().then((dynamic v) => taskCompletion.add(0));
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

    test('simple fork test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var forkedTask = Result<Task>();

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Fork(() sync* {
            yield Delay(Duration(milliseconds: 1));
          }, result: forkedTask);

          execution.add(1);

          yield Return(value1);
          execution.add(2);
        });

        forkedTask.value.toFuture().then((dynamic v) => taskCompletion.add(0));
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

    test('simple fork test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var forkedTask = Result<Task>();

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Fork(() sync* {}, result: forkedTask);

          execution.add(1);

          yield Delay(Duration(milliseconds: 1));

          yield Return(value1);
          execution.add(2);
        });

        forkedTask.value.toFuture().then((dynamic v) => taskCompletion.add(0));
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

    test('simple fork test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var forkedTaskA = Result<Task>();

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Fork(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
          }, result: forkedTaskA);

          execution.add(1);

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
          }

          yield Return(value1);
          execution.add(2);
        });

        forkedTaskA.value.toFuture().then((dynamic v) => taskCompletion.add(0));
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
            forkedTaskA.value.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  forkedTaskA.value.result,
                  forkedTaskA.value.isRunning,
                  forkedTaskA.value.isCancelled,
                  forkedTaskA.value.isAborted,
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

    test('simple fork test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var forkedTaskA = Result<Task>();
        var forkedTaskB = Result<Task>();

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Fork(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
          }, result: forkedTaskA);

          execution.add(1);

          yield Fork(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
          }, result: forkedTaskB);

          execution.add(2);

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
          }

          yield Return(value1);
          execution.add(3);
        });

        forkedTaskA.value.toFuture().then((dynamic v) => taskCompletion.add(0));
        forkedTaskB.value.toFuture().then((dynamic v) => taskCompletion.add(1));
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
            forkedTaskA.value.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  forkedTaskA.value.result,
                  forkedTaskA.value.isRunning,
                  forkedTaskA.value.isCancelled,
                  forkedTaskA.value.isAborted,
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
            forkedTaskB.value.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  forkedTaskB.value.result,
                  forkedTaskB.value.isRunning,
                  forkedTaskB.value.isCancelled,
                  forkedTaskB.value.isAborted,
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

    test('simple fork test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var forkedTaskA = Result<Task>();
        var forkedTaskB = Result<Task>();

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Fork(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
          }, result: forkedTaskA);

          execution.add(1);

          yield Fork(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
          }, result: forkedTaskB);

          execution.add(2);

          yield Cancel();

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
          }

          yield Return(value1);
          execution.add(3);
        });

        forkedTaskA.value.toFuture().then((dynamic v) => taskCompletion.add(0));
        forkedTaskB.value.toFuture().then((dynamic v) => taskCompletion.add(1));
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
              [0, 1, 2],
              equals('00')
            ]));

        expect(
            forkedTaskA.value.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  forkedTaskA.value.result,
                  forkedTaskA.value.isRunning,
                  forkedTaskA.value.isCancelled,
                  forkedTaskA.value.isAborted,
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
              equals('00')
            ]));

        expect(
            forkedTaskB.value.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  forkedTaskB.value.result,
                  forkedTaskB.value.isRunning,
                  forkedTaskB.value.isCancelled,
                  forkedTaskB.value.isAborted,
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
              equals('00')
            ]));
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('simple fork test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var forkedTaskA = Result<Task>();
        var forkedTaskB = Result<Task>();

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Fork(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
          }, result: forkedTaskA);

          execution.add(1);

          yield Fork(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
          }, result: forkedTaskB);

          execution.add(2);

          yield Cancel([forkedTaskA.value]);

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
          }

          yield Return(value1);
          execution.add(3);
        });

        forkedTaskA.value.toFuture().then((dynamic v) => taskCompletion.add(0));
        forkedTaskB.value.toFuture().then((dynamic v) => taskCompletion.add(1));
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
            forkedTaskA.value.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  forkedTaskA.value.result,
                  forkedTaskA.value.isRunning,
                  forkedTaskA.value.isCancelled,
                  forkedTaskA.value.isAborted,
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
            forkedTaskB.value.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  forkedTaskB.value.result,
                  forkedTaskB.value.isRunning,
                  forkedTaskB.value.isCancelled,
                  forkedTaskB.value.isAborted,
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

    test('simple fork test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var forkedTaskA = Result<Task>();
        var forkedTaskB = Result<Task>();

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Fork(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
          }, result: forkedTaskA);

          execution.add(1);

          yield Fork(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
          }, result: forkedTaskB);

          execution.add(2);

          yield Cancel([forkedTaskA.value, forkedTaskB.value]);

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
          }

          yield Return(value1);
          execution.add(3);
        });

        forkedTaskA.value.toFuture().then((dynamic v) => taskCompletion.add(0));
        forkedTaskB.value.toFuture().then((dynamic v) => taskCompletion.add(1));
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
            forkedTaskA.value.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  forkedTaskA.value.result,
                  forkedTaskA.value.isRunning,
                  forkedTaskA.value.isCancelled,
                  forkedTaskA.value.isAborted,
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
            forkedTaskB.value.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  forkedTaskB.value.result,
                  forkedTaskB.value.isRunning,
                  forkedTaskB.value.isCancelled,
                  forkedTaskB.value.isAborted,
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

    test('simple fork test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var joinResult = JoinResult();

        var forkedTaskA = Result<Task>();
        var forkedTaskB = Result<Task>();

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Fork(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
            yield Return('A');
          }, result: forkedTaskA);

          execution.add(1);

          yield Fork(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
          }, result: forkedTaskB);

          execution.add(2);

          yield Join(<dynamic, Task>{#forkA: forkedTaskA.value}, result: joinResult);

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
          }

          yield Return(value1);
          execution.add(3);
        });

        forkedTaskA.value.toFuture().then((dynamic v) => taskCompletion.add(0));
        forkedTaskB.value.toFuture().then((dynamic v) => taskCompletion.add(1));
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
              <dynamic, dynamic>{#forkA: 'A'}
            ]));

        expect(
            forkedTaskA.value.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  forkedTaskA.value.result,
                  forkedTaskA.value.isRunning,
                  forkedTaskA.value.isCancelled,
                  forkedTaskA.value.isAborted,
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
            forkedTaskB.value.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  forkedTaskB.value.result,
                  forkedTaskB.value.isRunning,
                  forkedTaskB.value.isCancelled,
                  forkedTaskB.value.isAborted,
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

    test('simple fork test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var joinResult = JoinResult();

        var forkedTaskA = Result<Task>();
        var forkedTaskB = Result<Task>();

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Fork(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
            yield Return('A');
          }, result: forkedTaskA);

          execution.add(1);

          yield Fork(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
            yield Return('B');
          }, result: forkedTaskB);

          execution.add(2);

          yield Join(<dynamic, Task>{#forkA: forkedTaskA.value, #forkB: forkedTaskB.value},
              result: joinResult);

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
          }

          yield Return(value1);
          execution.add(3);
        });

        forkedTaskA.value.toFuture().then((dynamic v) => taskCompletion.add(0));
        forkedTaskB.value.toFuture().then((dynamic v) => taskCompletion.add(1));
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
              <dynamic, dynamic>{#forkA: 'A', #forkB: 'B'}
            ]));

        expect(
            forkedTaskA.value.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  forkedTaskA.value.result,
                  forkedTaskA.value.isRunning,
                  forkedTaskA.value.isCancelled,
                  forkedTaskA.value.isAborted,
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
            forkedTaskB.value.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  forkedTaskB.value.result,
                  forkedTaskB.value.isRunning,
                  forkedTaskB.value.isCancelled,
                  forkedTaskB.value.isAborted,
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

    test('simple fork test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();

        var forkedTaskA = Result<Task>();
        var forkedTaskB = Result<Task>();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var joinResult = JoinResult();

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Fork(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
              if (i == 5) yield Cancel();
            }
            yield Return('A');
          }, Finally: () {
            execution.add(1);
          }, result: forkedTaskA);

          execution.add(2);

          yield Fork(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
            yield Return('B');
          }, Finally: () {
            execution.add(3);
          }, result: forkedTaskB);

          execution.add(4);

          yield Join(<dynamic, Task>{#forkA: forkedTaskA.value, #forkB: forkedTaskB.value},
              result: joinResult);

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
          }

          yield Return(value1);
          execution.add(5);
        }, Finally: () {
          execution.add(6);
        });

        forkedTaskA.value.toFuture().then((dynamic v) => taskCompletion.add(0));
        forkedTaskB.value.toFuture().then((dynamic v) => taskCompletion.add(1));
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
              [0, 2, 4, 1, 6, 3],
              [0, 1, 2],
              equals('0011223344556789'),
              null
            ]));

        expect(
            forkedTaskA.value.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  forkedTaskA.value.result,
                  forkedTaskA.value.isRunning,
                  forkedTaskA.value.isCancelled,
                  forkedTaskA.value.isAborted,
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
            forkedTaskB.value.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  forkedTaskB.value.result,
                  forkedTaskB.value.isRunning,
                  forkedTaskB.value.isCancelled,
                  forkedTaskB.value.isAborted,
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
              [0, 1],
              equals('0011223344556789')
            ]));
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('simple fork test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var joinResult = JoinResult();

        var forkedTaskA = Result<Task>();
        var forkedTaskB = Result<Task>();

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield Fork(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
              if (i == 5) yield Cancel();
            }
            yield Return('A');
          }, result: forkedTaskA);

          execution.add(1);

          yield Fork(() sync* {
            for (var i = 0; i < 10; i++) {
              values.write(i);
              yield Delay(Duration(milliseconds: 1));
            }
            yield Return('B');
          }, result: forkedTaskB);

          execution.add(2);

          yield Join(<dynamic, Task>{#forkA: forkedTaskA.value, #forkB: forkedTaskB.value},
              result: joinResult);

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
          }

          yield Return(value1);
          execution.add(3);
        });

        forkedTaskA.value.toFuture().then((dynamic v) => taskCompletion.add(0));
        forkedTaskB.value.toFuture().then((dynamic v) => taskCompletion.add(1));
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
              [0, 1, 2],
              equals('0011223344556789'),
              null
            ]));

        expect(
            forkedTaskA.value.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  forkedTaskA.value.result,
                  forkedTaskA.value.isRunning,
                  forkedTaskA.value.isCancelled,
                  forkedTaskA.value.isAborted,
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
            forkedTaskB.value.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  forkedTaskB.value.result,
                  forkedTaskB.value.isRunning,
                  forkedTaskB.value.isCancelled,
                  forkedTaskB.value.isAborted,
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
              equals('0011223344556789')
            ]));
        async.elapse(Duration(milliseconds: 100));
      });
    });
  });
}
