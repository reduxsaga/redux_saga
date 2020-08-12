import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/utils.dart';
import 'helpers/store.dart';

void main() {
  group('takeLeading tests', () {
    test('takeLeading', () {
      var actual = <List<dynamic>>[];
      var completers = createArrayOfCompleters<String>(4);

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      sagaMiddleware.run(() sync* {
        var forkedTask = Result<Task>();
        yield TakeLeading((dynamic arg1, dynamic arg2, {dynamic action}) sync* {
          var idx = (action.payload as int) - 1;
          var result = Result<dynamic>();
          yield Call(() => completers[idx].future, result: result);
          actual.add(<dynamic>[arg1, arg2, result.value]);
        }, args: <dynamic>['a1', 'a2'], pattern: TestActionA, result: forkedTask);
        yield Take(pattern: TestActionCancel);
        yield Cancel([forkedTask.value]);
      });

      var f = ResolveSequentially([
        callF(() => store.dispatch(TestActionA(1))),
        callF(() => store.dispatch(TestActionA(2))),
        callF(() => completers[1].complete('w-2')),
        callF(() => completers[0].complete('w-1')),
        callF(() => store.dispatch(TestActionA(3))),
        callF(() => completers[2].complete('w-3')),
        //We immediately cancel the watcher after firing the action
        //The watcher should be cancelled after this no further task should be forked
        //the last forked task should also be cancelled
        callF(() {
          store.dispatch(TestActionA(4));
          store.dispatch(TestActionCancel());
        }),
        callF(() => completers[3].complete('w-4')),
        // this one should be ignored by the watcher
        callF(() => store.dispatch(TestActionA(5))),
      ]);

      // takeLeading must ignore new action and keep running task until the completion
      expect(
          f.then((dynamic value) => actual),
          completion([
            ['a1', 'a2', 'w-1'],
            ['a1', 'a2', 'w-3']
          ]));
    });

    test('takeLeading: pattern END', () {
      var called = false;

      var forkedTask = Result<Task>();

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield TakeLeading(() sync* {
          called = true;
        }, pattern: TestActionA, result: forkedTask);
      });

      store.dispatch(End);
      store.dispatch(TestActionA(0));

      expect(
          task.toFuture().then((dynamic value) => [
                forkedTask.value.isRunning, // should finish takeLatest task on END
                called // should not call function if finished with END
              ]),
          completion([false, false]));
    });
  });
}
