import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/utils.dart';
import 'helpers/store.dart';

void main() {
  group('throttle tests', () {
    test('throttle', () {
      fakeAsync((async) {
        var actual = <List<dynamic>>[];

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        sagaMiddleware.run(() sync* {
          var forkedTask = Result<Task>();

          yield Throttle((dynamic arg1, dynamic arg2, {dynamic action}) sync* {
            actual.add(<dynamic>[arg1, arg2, action.payload]);
          },
              args: <dynamic>['a1', 'a2'],
              duration: Duration(milliseconds: 100),
              pattern: TestActionA,
              result: forkedTask);
          yield Take(pattern: TestActionCancel);
          yield Cancel([forkedTask.value]);
        });

        for (var i = 0; i < 35; i++) {
          Future<void>.delayed(Duration(milliseconds: i * 10), () {
            store.dispatch(TestActionA(i));
          });
        }

        Future<void>.delayed(Duration(milliseconds: 450), () {
          store.dispatch(TestActionCancel());
        });

        // shouldn't be processed cause of getting canceled
        Future<void>.delayed(Duration(milliseconds: 450), () {
          store.dispatch(TestActionA(40));
        });

        //process all
        async.elapse(Duration(milliseconds: 500));

        //throttle must ignore incoming actions during throttling interval
        expect(
            actual,
            equals([
              ['a1', 'a2', 0],
              ['a1', 'a2', 10],
              ['a1', 'a2', 20],
              ['a1', 'a2', 30],
              ['a1', 'a2', 34]
            ]));
      });
    });

    test('throttle: pattern END', () {
      fakeAsync((async) {
        var delayMs = 20;

        var task = Result<Task>();

        var called = false;

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var mainTask = sagaMiddleware.run(() sync* {
          yield Throttle(() {
            called = true;
          }, duration: Duration(milliseconds: delayMs), pattern: TestActionA, result: task);
        });

        store.dispatch(End);

        var f = ResolveSequentially([
          () => mainTask.toFuture(),
          callF(() => store.dispatch(TestActionA(0))),
          delayF(2 * delayMs)
        ]);

        expect(
            f.then((dynamic value) => [
                  task.value.isRunning, // should finish throttle task on END
                  called // should not call function if finished with END
                ]),
            completion([false, false]));

        //process all
        async.elapse(Duration(milliseconds: 2 * delayMs));
      });
    });
  });
}
