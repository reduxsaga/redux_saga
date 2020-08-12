import 'package:fake_async/fake_async.dart';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/store.dart';
import 'helpers/utils.dart';

void main() {
  group('take test', () {
    test('saga take from default channel', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      sagaMiddleware.run(() sync* {
        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Take(result: result); // take all actions
          actual.add(result.value);

          yield Take(pattern: _Action1, result: result); // take only actions of type 'action-1'
          actual.add(result.value);

          yield Take(pattern: [_Action2, _Action2222], result: result); // take either type
          actual.add(result.value);

          yield Take(
              pattern: (dynamic action) => action is _ActionP && action.isAction,
              result: result); // take if match predicate
          actual.add(result.value);

          yield Take(pattern: [
            _Action3,
            (dynamic action) => action is _ActionWP && action.isMixedWithPredicate
          ], result: result); // take if match any from the mixed array
          actual.add(result.value);

          yield Take(pattern: [
            _Action3,
            (dynamic action) => action is _ActionWP && action.isMixedWithPredicate
          ], result: result); // take if match any from the mixed array
          actual.add(result.value);

          yield Take(pattern: 'Symbol', result: result); // take only actions of a Symbol type
          actual.add(result.value);

          yield Take(pattern: _NeverHappeningAction, result: result); //  should get END
          actual.add(result.value);
        }, Finally: () {
          actual.add('auto ended');
        });
      });

      var anyAction = _ActionAny();
      var action1 = _Action1();
      var action2 = _Action2();
      var unnoticeableAction = _UnnoticeableAction();
      var actionP = _ActionP(true);
      var actionWp = _ActionWP(true);
      var action3 = _Action3();
      var symbolAction = Symbol('action-symbol');

      var f = ResolveSequentially([
        callF(() => store.dispatch(anyAction)),
        callF(() => store.dispatch(action1)),
        callF(() => store.dispatch(action2)),
        callF(() => store.dispatch(unnoticeableAction)),
        callF(() => store.dispatch(actionP)),
        callF(() => store.dispatch(actionWp)),
        callF(() => store.dispatch(action3)),
        callF(() => store.dispatch(symbolAction)),
        callF(() => store.dispatch(End)),
      ]);

      // saga must fulfill take Effects from default channel
      expect(
          f.then((dynamic value) => actual),
          completion([
            anyAction,
            action1,
            action2,
            actionP,
            actionWp,
            action3,
            symbolAction,
            'auto ended'
          ]));
    });

    test('saga take from provided channel', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var channel = BasicChannel();

      sagaMiddleware.run(() sync* {
        for (var i = 0; i < 6; i++) {
          var result = Result<dynamic>();
          yield TakeMaybe(channel: channel, result: result);
          actual.add(result.value);
        }
      });

      var f = ResolveSequentially([
        callF(() => channel.put(1)),
        callF(() => channel.put(2)),
        callF(() => channel.put(3)),
        callF(() => channel.put(4)),
        callF(() => channel.close()),
      ]);

      // saga must fulfill take Effects from a provided channel
      expect(f.then((dynamic value) => actual), completion([1, 2, 3, 4, End, End]));
    });

    test('saga take from eventChannel', () {
      var actual = <dynamic>[];

      Emit channelEmitter;

      var channel = EventChannel(subscribe: (emitter) {
        channelEmitter = emitter;

        // The subscriber must return an unsubscribe function
        return () {};
      });

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      sagaMiddleware.run(() sync* {
        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Take(channel: channel, result: result);
          actual.add(result.value);

          yield Take(channel: channel, result: result);
          actual.add(result.value);

          yield Take(channel: channel, result: result);
          actual.add(result.value);
        }, Catch: (dynamic e) sync* {
          actual.add('in-catch-block');
          actual.add(e);
        });
      });

      var f = ResolveSequentially([
        callF(() => channelEmitter('action-1')),
        callF(() => channelEmitter('action-2')),
        callF(() => channelEmitter(exceptionToBeCaught)),
        callF(() => channelEmitter('action-after-error')),
      ]);

      // saga must take payloads from the eventChannel, and errors from eventChannel will make the saga jump to the catch block
      expect(f.then((dynamic value) => actual),
          completion(['action-1', 'action-2', 'in-catch-block', exceptionToBeCaught]));
    });

    test('take test', () {
      fakeAsync((async) {
        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          var result = Result<dynamic>();
          yield Take(result: result);
          yield Return(result.value);
        });

        store.dispatch(IncrementCounterAction());

        expect(
            task.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  task.result,
                  task.isRunning,
                  task.isCancelled,
                  task.isAborted,
                ]),
            completion([
              TypeMatcher<IncrementCounterAction>(),
              TypeMatcher<IncrementCounterAction>(),
              false,
              false,
              false
            ]));
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('take test', () {
      fakeAsync((async) {
        var takeResult = Result<dynamic>();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          yield Fork(() sync* {
            yield Take(result: takeResult);
          });

          yield Delay(Duration(milliseconds: 1));

          yield Cancel();
        });

        expect(
            task.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  task.result,
                  task.isRunning,
                  task.isCancelled,
                  task.isAborted,
                ]),
            completion([TaskCancel, TaskCancel, false, true, false]));
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('take test', () {
      fakeAsync((async) {
        var takeResult = Result<dynamic>();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          yield Fork(() sync* {
            yield Take(result: takeResult);
          });

          yield Delay(Duration(milliseconds: 1));
          throw exceptionToBeCaught;
        });

        expect(
            task.toFuture().catchError((dynamic error) => <dynamic>[
                  error,
                  task.result,
                  task.isRunning,
                  task.isCancelled,
                  task.isAborted,
                ]),
            completion([exceptionToBeCaught, null, false, false, true]));
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('take test', () {
      fakeAsync((async) {
        var takeResult = Result<dynamic>();

        var forkedTaskA = Result<Task>();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          yield Fork(() sync* {
            yield Delay(Duration(milliseconds: 1));
            throw exceptionToBeCaught;
          }, result: forkedTaskA);

          yield Take(result: takeResult);
        });

        expect(
            task.toFuture().catchError((dynamic error) => <dynamic>[
                  error,
                  task.result,
                  task.isRunning,
                  task.isCancelled,
                  task.isAborted,
                ]),
            completion([exceptionToBeCaught, null, false, false, true]));

        expect(
            forkedTaskA.value.toFuture().catchError((dynamic error) => <dynamic>[
                  error,
                  forkedTaskA.value.result,
                  forkedTaskA.value.isRunning,
                  forkedTaskA.value.isCancelled,
                  forkedTaskA.value.isAborted,
                ]),
            completion([exceptionToBeCaught, null, false, false, true]));
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('take test', () {
      fakeAsync((async) {
        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          var result = Result<dynamic>();
          yield Take(result: result);
          yield Return(result.value);
        });

        store.dispatch(End);

        expect(
            task.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  task.result,
                  task.isRunning,
                  task.isCancelled,
                  task.isAborted,
                ]),
            completion([null, null, false, false, false]));
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('take test', () {
      fakeAsync((async) {
        var execution = <int>[];

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);
          var result = Result<dynamic>();
          yield Take(result: result);
          execution.add(1);
          yield Return(result.value);
        }, Finally: () {
          execution.add(2);
        });

        store.dispatch(End);

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
              null,
              null,
              false,
              false,
              false,
              [0, 2]
            ]));
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('take test', () {
      fakeAsync((async) {
        var result = Result<TestActionA>();
        var takes = <int>[];

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          yield Take(result: result);
          takes.add(result.value.payload);

          yield Take(pattern: '*', result: result);
          takes.add(result.value.payload);

          yield Take(pattern: 'TestActionA', result: result);
          takes.add(result.value.payload);

          yield Take(pattern: TestActionA, result: result);
          takes.add(result.value.payload);

          yield Take(
              pattern: (dynamic action) => action is TestActionA && action.payload == 4,
              result: result);
          takes.add(result.value.payload);

          yield Take(pattern: [
            'TestActionA',
            TestActionB,
            (dynamic action) => action is TestActionA && action.payload == 7
          ], result: result);
          takes.add(result.value.payload);

          yield Take(pattern: [
            'TestActionB',
            TestActionA,
            (dynamic action) => action is TestActionA && action.payload == 7
          ], result: result);
          takes.add(result.value.payload);

          yield Take(pattern: [
            'TestActionB',
            TestActionB,
            (dynamic action) => action is TestActionA && action.payload == 7
          ], result: result);
          takes.add(result.value.payload);
        });

        store.dispatch(TestActionA(0));
        store.dispatch(TestActionA(1));
        store.dispatch(TestActionA(2));
        store.dispatch(TestActionA(3));
        store.dispatch(TestActionA(4));
        store.dispatch(TestActionA(5));
        store.dispatch(TestActionA(6));
        store.dispatch(TestActionA(7));

        expect(
            task.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  task.result,
                  task.isRunning,
                  task.isCancelled,
                  task.isAborted,
                  takes
                ]),
            completion([
              null,
              null,
              false,
              false,
              false,
              [0, 1, 2, 3, 4, 5, 6, 7]
            ]));
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('take maybe test', () {
      fakeAsync((async) {
        var execution = <int>[];

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          execution.add(0);
          var result = Result<dynamic>();
          yield TakeMaybe(result: result);
          execution.add(1);
          yield Return(result.value);
        }, Finally: () {
          execution.add(2);
        });

        store.dispatch(End);

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
              End,
              End,
              false,
              false,
              false,
              [0, 1, 2]
            ]));
        async.elapse(Duration(milliseconds: 100));
      });
    });
  });
}

class _ActionAny {}

class _Action1 {}

class _Action2 {}

class _Action2222 {}

class _ActionP {
  bool isAction;

  _ActionP(this.isAction);
}

class _Action3 {}

class _ActionWP {
  bool isMixedWithPredicate;

  _ActionWP(this.isMixedWithPredicate);
}

class _UnnoticeableAction {}

class _NeverHappeningAction {}
