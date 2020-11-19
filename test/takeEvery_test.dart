import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/utils.dart';
import 'helpers/store.dart';

void main() {
  group('takeEvery tests', () {
    test('takeEvery', () {
      var actual = <List<dynamic>>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        var forkedTask = Result<Task>();

        yield TakeEvery((dynamic arg1, dynamic arg2, {dynamic action}) sync* {
          actual.add(<dynamic>[arg1, arg2, action.payload]);
        },
            args: <dynamic>['a1', 'a2'],
            pattern: TestActionA,
            result: forkedTask);
        yield Take(pattern: TestActionCancel);
        yield Cancel([forkedTask.value]);
      });

      var f = ResolveSequentially([
        callF(() {
          for (var i = 1; i <= 5; i++) {
            store.dispatch(TestActionA(i));
          }
        }),
        // the watcher should be cancelled after this
        // no further task should be forked after this
        callF(() => store.dispatch(TestActionCancel())),
        callF(() {
          for (var i = 6; i <= 10; i++) {
            store.dispatch(TestActionA(i));
          }
        }),
        () => task.toFuture()
      ]);

      // should debounce sync actions and pass the latest action to a worker
      expect(
          f.then((dynamic value) => actual),
          completion([
            ['a1', 'a2', 1],
            ['a1', 'a2', 2],
            ['a1', 'a2', 3],
            ['a1', 'a2', 4],
            ['a1', 'a2', 5]
          ]));
    });

    test('takeEvery: pattern END', () {
      var called = false;

      var forkedTask = Result<Task>();

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield TakeEvery(() {
          called = true;
        }, pattern: TestActionA, result: forkedTask);
        yield Take(pattern: TestActionCancel);
        yield Cancel([forkedTask.value]);
      });

      store.dispatch(End);

      store.dispatch(TestActionA(0));

      expect(
          task.toFuture().then((dynamic value) => [
                forkedTask
                    .value.isRunning, // should finish takeEvery task on END
                called // should not call function if finished with END
              ]),
          completion([false, false]));
    });
  });
}
