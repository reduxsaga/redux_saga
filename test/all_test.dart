import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/utils.dart';
import 'helpers/store.dart';

void main() {
  group('all test', () {
    test('saga parallel effects handling', () {
      var comp = Completer<int>();

      Map<Symbol, dynamic>? cpsCB;

      void cps(int val, {CPSCallback? cb}) {
        cpsCB = <Symbol, dynamic>{#val: val, #cb: cb};
        cb!.cancel = () {};
      }

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var all = AllResult();

      var task = sagaMiddleware.run(() sync* {
        yield All(<Symbol, Effect>{
          #future: Call(() => comp.future),
          #cps: CPS(cps, args: <dynamic>[2]),
          #take: Take(pattern: TestActionA)
        }, result: all);
      });

      var action = TestActionA(3);

      ResolveSequentially([
        callF(() => comp.complete(1)),
        callF(() => cpsCB![#cb].callback(res: cpsCB![#val])),
        callF(() => store.dispatch(action))
      ]);

      // saga must fulfill parallel effects
      expect(task.toFuture().then((dynamic value) => all.value),
          completion(<Symbol, dynamic>{#future: 1, #cps: 2, #take: action}));
    });

    test('saga empty array', () {
      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var all = AllResult();

      var task = sagaMiddleware.run(() sync* {
        yield All(<Symbol, Effect>{}, result: all);
      });

      // saga must fulfill parallel effects
      expect(task.toFuture().then((dynamic value) => all.value),
          completion(<Symbol, dynamic>{}));
    });

    test('saga parallel effect: handling errors', () {
      var comps = createArrayOfCompleters<int>(2);

      ResolveSequentially([
        callF(() => comps[0].completeError(exceptionToBeCaught)),
        callF(() => comps[1].complete(1)),
      ]);

      var all = AllResult();

      dynamic caught;

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield All(<Symbol, Effect>{
          #call1: Call(() => comps[0].future),
          #call2: Call(() => comps[1].future),
        }, result: all);
      }, Catch: (dynamic e, StackTrace s) {
        caught = e;
      });

      //saga must catch the first error in parallel effects
      expect(task.toFuture().then<dynamic>((dynamic value) => caught),
          completion(exceptionToBeCaught));
      expect(
          task.toFuture().then((dynamic value) => all.value), completion(null));
    });

    test('saga parallel effect: handling END', () {
      var comp = Completer<int>();

      var all = AllResult();

      var onfinally = false;

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield All(<Symbol, Effect>{
          #call1: Call(() => comp.future),
          #call2: Take(pattern: TestActionA),
        }, result: all);
      }, Finally: () {
        onfinally = true;
      });

      ResolveSequentially(
          [callF(() => comp.complete(1)), callF(() => store.dispatch(End))]);

      //saga must end Parallel Effect if one of the effects resolve with END
      expect(
          task.toFuture().then((dynamic value) => onfinally), completion(true));
      expect(
          task.toFuture().then((dynamic value) => all.value), completion(null));
    });

    test('all test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();

        var forkedTaskA = Result<Task>();
        var forkedTaskB = Result<Task>();
        var all = AllResult();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield All(<Symbol, Effect>{
            #fork1: Fork(() sync* {
              for (var i = 0; i < 10; i++) {
                values.write(i);
                yield Delay(Duration(milliseconds: 1));
              }
              yield Return(value2);
            }, result: forkedTaskA),
            #fork2: Fork(() sync* {
              for (var i = 0; i < 10; i++) {
                values.write(i);
                yield Delay(Duration(milliseconds: 1));
              }
              yield Return(value3);
            }, result: forkedTaskB)
          }, result: all);

          execution.add(1);

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
          }

          yield Return(value1);
          execution.add(2);
        });

        forkedTaskA.value!.toFuture().then((dynamic v) => taskCompletion.add(0));
        forkedTaskB.value!.toFuture().then((dynamic v) => taskCompletion.add(1));
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
                  all.value,
                  forkedTaskA.value!.result,
                  forkedTaskB.value!.result
                ]),
            completion([
              value1,
              value1,
              false,
              false,
              false,
              [0, 1],
              [0, 1, 2],
              '000111222333444555666777888999',
              {#fork1: forkedTaskA.value, #fork2: forkedTaskB.value},
              value2,
              value3
            ]));
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('all test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();

        var forkedTaskA = Result<Task>();
        var forkedTaskB = Result<Task>();
        var all = AllResult();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield All(<Symbol, Effect>{
            #fork1: Fork(() sync* {
              for (var i = 0; i < 10; i++) {
                values.write(i);
                yield Delay(Duration(milliseconds: 1));
                if (i == 5) yield Cancel();
              }
              yield Return(value2);
            }, result: forkedTaskA),
            #fork2: Fork(() sync* {
              for (var i = 0; i < 10; i++) {
                values.write(i);
                yield Delay(Duration(milliseconds: 1));
              }
              yield Return(value3);
            }, result: forkedTaskB)
          }, result: all);

          execution.add(1);

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
          }

          yield Return(value1);
          execution.add(2);
        });

        forkedTaskA.value!.toFuture().then((dynamic v) => taskCompletion.add(0));
        forkedTaskB.value!.toFuture().then((dynamic v) => taskCompletion.add(1));
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
                  all.value,
                  forkedTaskA.value!.result,
                  forkedTaskB.value!.result
                ]),
            completion([
              value1,
              value1,
              false,
              false,
              false,
              [0, 1],
              [0, 1, 2],
              '00011122233344455566778899',
              {#fork1: forkedTaskA.value, #fork2: forkedTaskB.value},
              TaskCancel,
              value3
            ]));
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('all test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();

        var callA = Result<dynamic>();
        var callB = Result<dynamic>();
        var all = AllResult();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield All(<Symbol, Effect>{
            #call1: Call(() sync* {
              for (var i = 0; i < 10; i++) {
                values.write(i);
                yield Delay(Duration(milliseconds: 1));
              }
              yield Return(value2);
            }, result: callA),
            #call2: Call(() sync* {
              for (var i = 0; i < 10; i++) {
                values.write(i);
                yield Delay(Duration(milliseconds: 1));
              }
              yield Return(value3);
            }, result: callB)
          }, result: all);

          execution.add(1);

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
          }

          yield Return(value1);
          execution.add(2);
        });

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
                  values.toString(),
                  all.value
                ]),
            completion([
              value1,
              value1,
              false,
              false,
              false,
              [0, 1],
              [1],
              '001122334455667788990123456789',
              {#call1: value2, #call2: value3},
            ]));
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('all test', () {
      fakeAsync((async) {
        var execution = <int>[];
        var taskCompletion = <int>[];
        var values = StringBuffer();

        var callA = Result<dynamic>();
        var callB = Result<dynamic>();
        var all = AllResult();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);

          yield All(<Symbol, Effect>{
            #call1: Call(() sync* {
              for (var i = 0; i < 10; i++) {
                values.write(i);
                yield Delay(Duration(milliseconds: 1));
                if (i == 5) yield Cancel();
              }
              yield Return(value2);
            }, result: callA),
            #call2: Call(() sync* {
              for (var i = 0; i < 10; i++) {
                values.write(i);
                yield Delay(Duration(milliseconds: 1));
              }
              yield Return(value3);
            }, result: callB)
          }, result: all);

          execution.add(1);

          for (var i = 0; i < 10; i++) {
            values.write(i);
            yield Delay(Duration(milliseconds: 1));
          }

          yield Return(value1);
          execution.add(2);
        });

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
                  values.toString(),
                  all.value
                ]),
            completion([
              TaskCancel,
              TaskCancel,
              false,
              true,
              false,
              [0],
              [1],
              '001122334455',
              null,
            ]));
        async.elapse(Duration(milliseconds: 100));
      });
    });
  });
}
