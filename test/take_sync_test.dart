import 'package:redux/redux.dart';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/store.dart';
import 'helpers/utils.dart';

void main() {
  group('take sync tests', () {
    test('synchronous sequential takes', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      Iterable<Effect> fnA() sync* {
        var result = Result<dynamic>();
        yield Take(pattern: _a1, result: result);
        actual.add(result.value);

        yield Take(pattern: _a3, result: result);
        actual.add(result.value);
      }

      Iterable<Effect> fnB() sync* {
        var result = Result<dynamic>();
        yield Take(pattern: _a2, result: result);
        actual.add(result.value);
      }

      Iterable<Effect> root() sync* {
        yield Fork(fnA);
        yield Fork(fnB);
      }

      sagaMiddleware.run(root);

      var a1 = _a1();
      var a2 = _a2();
      var a3 = _a3();

      store.dispatch(a1);
      store.dispatch(a2);
      store.dispatch(a3);

      // Sagas must take consecutive actions dispatched synchronously
      expect(Future(() => actual), completion([a1, a2, a3]));
    });

    test('synchronous concurrent takes', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      //If a1 wins, then a2 cancellation means it will not take the next 'a2' action,
      //dispatched immediately by the store after 'a1'; so the 2n take('a2') should take it
      Iterable<Effect> root() sync* {
        var raceResult = RaceResult();

        yield Race(<dynamic, Effect>{
          #a1: Take(pattern: _a1),
          #a2: Take(pattern: _a2),
        }, result: raceResult);
        actual.add(raceResult.value);

        var result = Result<dynamic>();
        yield Take(pattern: _a2, result: result);
        actual.add(result.value);
      }

      sagaMiddleware.run(root);

      var a1 = _a1();
      var a2 = _a2();

      store.dispatch(a1);
      store.dispatch(a2);

      // In concurrent takes only the winner must take an action
      expect(
          Future(() => actual),
          completion([
            {#a1: a1},
            a2
          ]));
    });

    test('synchronous parallel takes', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      Iterable<Effect> root() sync* {
        var resultAll = AllResult();
        yield All(
            <dynamic, Effect>{#a1: Take(pattern: _a1), #a2: Take(pattern: _a2)},
            result: resultAll);
        actual.add(resultAll.value);
      }

      sagaMiddleware.run(root);

      var a1 = _a1();
      var a2 = _a2();

      store.dispatch(a1);
      store.dispatch(a2);

      // Saga must resolve once all parallel actions dispatched
      expect(
          Future(() => actual),
          completion([
            {#a1: a1, #a2: a2}
          ]));
    });

    test('synchronous parallel + concurrent takes', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      Iterable<Effect> root() sync* {
        var resultAll = AllResult();

        yield All(<dynamic, Effect>{
          #race: Race(<dynamic, Effect>{
            #a1: Take(pattern: _a1),
            #a2: Take(pattern: _a2),
          }),
          #take: Take(pattern: _a2)
        }, result: resultAll);
        actual.add(resultAll.value);
      }

      sagaMiddleware.run(root);

      var a1 = _a1();
      var a2 = _a2();

      store.dispatch(a1);
      store.dispatch(a2);

      // Saga must resolve once all parallel actions dispatched
      expect(
          Future(() => actual),
          completion([
            {
              #race: {#a1: a1},
              #take: a2
            }
          ]));
    });

    test('startup actions', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createSagaMiddleware();

      var store = Store<EmptyState>(
        (EmptyState state, dynamic action) {
          if (action is TestActionA) {
            actual.add(action.payload);
          }
          return state;
        },
        initialState: EmptyState(),
        middleware: [
          applyMiddleware(sagaMiddleware),
        ],
      );

      sagaMiddleware.setStore(store);

      Iterable<Effect> fnA() sync* {
        var result = Result<dynamic>();
        yield Take(pattern: TestActionA, result: result);
        actual.add('fnA-${result.value.payload}');
      }

      Iterable<Effect> fnB() sync* {
        yield Put(TestActionA(1));
        yield Put(TestActionA(2));
        yield Put(TestActionA(3));
      }

      sagaMiddleware.run(fnA);
      sagaMiddleware.run(fnB);

      //Saga starts dispatching actions immediately after being started
      //But since sagas are started immediately by the saga middleware
      //It means saga will dispatch actions while the store creation
      //is still running (applyMiddleware has not yet returned)

      // Saga must be able to dispatch startup actions
      expect(Future(() => actual), completion([1, 'fnA-1', 2, 3]));
    });

    test('synchronous takes + puts', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createSagaMiddleware();

      var store = Store<EmptyState>(
        (EmptyState state, dynamic action) {
          if (action is TestActionD) {
            actual.add(action.payload);
          }
          return state;
        },
        initialState: EmptyState(),
        middleware: [
          applyMiddleware(sagaMiddleware),
        ],
      );

      sagaMiddleware.setStore(store);

      Iterable<Effect> root() sync* {
        yield Take(pattern: TestActionD);
        yield Put(TestActionD('ack-1'));
        yield Take(pattern: TestActionD);
        yield Put(TestActionD('ack-2'));
      }

      sagaMiddleware.run(root);

      store.dispatch(TestActionD(1));
      store.dispatch(TestActionD(2));

      // Sagas must be able to interleave takes and puts without losing actions
      expect(Future(() => actual), completion([1, 'ack-1', 'ack-2', 2]));
    });

    test('synchronous takes (from a channel) + puts (to the store)', () {
      var actual = <dynamic>[];

      var channel = BasicChannel();

      var sagaMiddleware = createSagaMiddleware();

      var store = Store<EmptyState>(
        (EmptyState state, dynamic action) {
          if (action is TestActionD) {
            actual.add(action.payload);
          }
          return state;
        },
        initialState: EmptyState(),
        middleware: [
          applyMiddleware(sagaMiddleware),
        ],
      );

      sagaMiddleware.setStore(store);

      Iterable<Effect> root() sync* {
        var result = Result<dynamic>();

        yield Take(channel: channel, pattern: TestActionD, result: result);
        actual.add(result.value.payload);

        yield Put(TestActionD('ack-1'));

        yield Take(channel: channel, pattern: TestActionD, result: result);
        actual.add(result.value.payload);

        yield Put(TestActionD('ack-2'));

        yield Take(
            channel: channel, pattern: _neverHappeningAction, result: result);
      }

      sagaMiddleware.run(root);

      channel.put(TestActionD(1));
      channel.put(TestActionD(2));

      channel.close();

      // Sagas must be able to interleave takes (from a channel) and puts (to the store) without losing actions
      expect(Future(() => actual), completion([1, 'ack-1', 2, 'ack-2']));
    });

    test('inter-saga put/take handling', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      Iterable<Effect> someAction(dynamic payload) sync* {
        actual.add(payload);
      }

      Iterable<Effect> fnA() sync* {
        while (true) {
          var result = Result<dynamic>();
          yield Take(pattern: TestActionD, result: result);
          yield Fork(someAction, args: <dynamic>[result.value.payload]);
        }
      }

      Iterable<Effect> fnB() sync* {
        yield Put(TestActionD(1));
        yield Put(TestActionD(2));
        yield Put(TestActionD(3));
      }

      Iterable<Effect> root() sync* {
        yield All(<dynamic, Effect>{#fnA: Fork(fnA), #fnB: Fork(fnB)});
      }

      sagaMiddleware.run(root);

      // Sagas must take actions from each other
      expect(Future(() => actual), completion([1, 2, 3]));
    });

    test('inter-saga put/take handling (via buffered channel)', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var channel = BasicChannel();

      Iterable<Effect> someAction(dynamic action) sync* {
        actual.add(action);
        yield Call(() => Future<void>(() {}));
      }

      Iterable<Effect> fnA() sync* {
        while (true) {
          var result = Result<dynamic>();
          yield Take(channel: channel, result: result);
          yield Call(someAction, args: <dynamic>[result.value]);
        }
      }

      Iterable<Effect> fnB() sync* {
        yield Put(1, channel: channel);
        yield Put(2, channel: channel);
        yield Put(3, channel: channel);
        yield Call(channel.close);
      }

      Iterable<Effect> root() sync* {
        yield All(<dynamic, Effect>{#fnA: Fork(fnA), #fnB: Fork(fnB)});
      }

      var task = sagaMiddleware.run(root);

      // Sagas must take actions from each other (via buffered channel)
      expect(task.toFuture().then((dynamic value) => actual),
          completion([1, 2, 3]));
    });

    test('inter-saga send/acknowledge handling', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      Iterable<Effect> fnA() sync* {
        var result = Result<dynamic>();
        yield Take(pattern: _msg1, result: result);
        actual.add(result.value);

        yield Put(_ack1());

        yield Take(pattern: _msg2, result: result);
        actual.add(result.value);

        yield Put(_ack2());
      }

      Iterable<Effect> fnB() sync* {
        yield Put(_msg1());

        var result = Result<dynamic>();
        yield Take(pattern: _ack1, result: result);
        actual.add(result.value);

        yield Put(_msg2());

        yield Take(pattern: _ack2, result: result);
        actual.add(result.value);
      }

      Iterable<Effect> root() sync* {
        yield All(<dynamic, Effect>{#fnA: Fork(fnA), #fnB: Fork(fnB)});
      }

      sagaMiddleware.run(root);

      // Sagas must take actions from each other in the right order
      expect(
          Future(() => actual),
          completion([
            TypeMatcher<_msg1>(),
            TypeMatcher<_ack1>(),
            TypeMatcher<_msg2>(),
            TypeMatcher<_ack2>()
          ]));
    });

    test('inter-saga send/acknowledge handling (via unbuffered channel)', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      // non buffered channel must behave like the store
      var channel = BasicChannel(buffer: Buffers.none<dynamic>());

      Iterable<Effect> fnA() sync* {
        var result = Result<dynamic>();
        yield Take(channel: channel, result: result);
        actual.add(result.value);

        yield Put(_ack1(), channel: channel);

        yield Take(channel: channel, result: result);
        actual.add(result.value);

        yield Put(_ack2(), channel: channel);
      }

      Iterable<Effect> fnB() sync* {
        yield Put(_msg1(), channel: channel);

        var result = Result<dynamic>();
        yield Take(channel: channel, result: result);
        actual.add(result.value);

        yield Put(_msg2(), channel: channel);

        yield Take(channel: channel, result: result);
        actual.add(result.value);
      }

      Iterable<Effect> root() sync* {
        yield Fork(fnA);
        yield Fork(fnB);
      }

      sagaMiddleware.run(root);

      // Sagas must take actions from each other (via unbuffered channel) in the right order
      expect(
          Future(() => actual),
          completion([
            TypeMatcher<_msg1>(),
            TypeMatcher<_ack1>(),
            TypeMatcher<_msg2>(),
            TypeMatcher<_ack2>()
          ]));
    });

    test('inter-saga send/acknowledge handling (via buffered channel)', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      // non buffered channel must behave like the store
      var channel = BasicChannel();

      Iterable<Effect> fnA() sync* {
        var result = Result<dynamic>();
        yield Take(channel: channel, result: result);
        actual.add(result.value);

        yield Put(_ack1(), channel: channel);

        yield Call(() => Future<void>(() {}));

        yield Take(channel: channel, result: result);
        actual.add(result.value);

        yield Put(_ack2(), channel: channel);
      }

      Iterable<Effect> fnB() sync* {
        yield Put(_msg1(), channel: channel);

        yield Call(() => Future<void>(() {}));

        var result = Result<dynamic>();
        yield Take(channel: channel, result: result);
        actual.add(result.value);

        yield Put(_msg2(), channel: channel);

        yield Call(() => Future<void>(() {}));

        yield Take(channel: channel, result: result);
        actual.add(result.value);
      }

      Iterable<Effect> root() sync* {
        yield Fork(fnA);
        yield Fork(fnB);
      }

      var task = sagaMiddleware.run(root);

      // Sagas must take actions from each other (via buffered channel) in the right order
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            TypeMatcher<_msg1>(),
            TypeMatcher<_ack1>(),
            TypeMatcher<_msg2>(),
            TypeMatcher<_ack2>()
          ]));
    });

    test('inter-saga fork/take back from forked child 1', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var testCounter = 0;

      Iterable<Effect> takeTest1({dynamic action}) sync* {
        if (testCounter == 0) {
          actual.add(1);
          testCounter++;
          yield Put(_TEST2());
        } else {
          actual.add(++testCounter);
        }
      }

      Iterable<Effect> forkedPut1() sync* {
        yield Put(_TEST());
      }

      Iterable<Effect> forkedPut2() sync* {
        yield Put(_TEST());
      }

      Iterable<Effect> takeTest2({dynamic action}) sync* {
        yield All(<dynamic, Effect>{
          #fork1: Fork(forkedPut1),
          #fork2: Fork(forkedPut2)
        });
      }

      Iterable<Effect> root() sync* {
        yield All(<dynamic, Effect>{
          #test1: TakeEvery(takeTest1, pattern: _TEST),
          #test2: TakeEvery(takeTest2, pattern: _TEST2)
        });
      }

      var task = sagaMiddleware.run(root);

      store.dispatch(_TEST());
      store.dispatch(End);

      // Sagas must take actions from each forked tasks doing Sync puts
      expect(task.toFuture().then((dynamic value) => actual),
          completion([1, 2, 3]));
    });

    test('deeply nested forks/puts', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      Iterable<Effect> s3() sync* {
        yield Put(_a3());
      }

      Iterable<Effect> s2() sync* {
        yield Fork(s3);

        var result = Result<dynamic>();
        yield Take(pattern: _a3, result: result);
        actual.add(result.value);

        yield Put(_a2());
      }

      Iterable<Effect> s1() sync* {
        yield Fork(s2);

        var result = Result<dynamic>();
        yield Take(pattern: _a2, result: result);
        actual.add(result.value);
      }

      sagaMiddleware.run(s1);

      // must schedule deeply nested forks/puts
      expect(actual, [TypeMatcher<_a3>(), TypeMatcher<_a2>()]);
    });

    test('inter-saga fork/take back from forked child 2', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var first = true;

      Iterable<Effect> ackWorker({dynamic action}) sync* {
        if (first) {
          first = false;
          var newVal = (action.val as int) + 1;

          yield Put(_PING(newVal));

          yield Take(
              pattern: (dynamic message) =>
                  message is _ACK && message.val == newVal);
        }

        yield Put(_ACK(action.val as int));

        actual.add(1);
      }

      Iterable<Effect> root() sync* {
        yield TakeEvery(ackWorker, pattern: _PING);
      }

      var task = sagaMiddleware.run(root);

      store.dispatch(_PING(0));
      store.dispatch(End);

      // Sagas must take actions from each forked tasks doing Sync puts
      expect(
          task.toFuture().then((dynamic value) => actual), completion([1, 1]));
    });

    test('put causing sync dispatch response in store subscriber', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createSagaMiddleware();

      var store = Store<_State>(
        (_State state, dynamic action) {
          return _State(action);
        },
        initialState: _State(null),
        middleware: [
          applyMiddleware(sagaMiddleware),
        ],
      );

      sagaMiddleware.setStore(store);

      sagaMiddleware.run(() sync* {
        while (true) {
          var race = RaceResult();

          yield Race(
              <dynamic, Effect>{#a: Take(pattern: _a), #b: Take(pattern: _b)},
              result: race);

          actual.add(race.keyValue);

          if (race.key == #a) {
            yield Put(_c());
          } else {
            yield Put(_d());
          }
        }
      });

      store.onChange.listen((event) {
        if (event.value is _c) {
          store.dispatch(_b());
        }
      });

      store.dispatch(_a());

      //Sagas can't miss actions dispatched by store subscribers during put handling
      expect(Future(() => actual),
          completion(([TypeMatcher<_a>(), TypeMatcher<_b>()])));
    });

    test(
        'action dispatched in root saga should get scheduled and taken by a "sibling" take',
        () {
      var sagaMiddleware = createSagaMiddleware();

      var store = Store<_State2>(
        (_State2 state, dynamic action) {
          return _State2(<dynamic>[...state.value, action]);
        },
        initialState: _State2(<dynamic>[]),
        middleware: [
          applyMiddleware(sagaMiddleware),
        ],
      );

      sagaMiddleware.setStore(store);

      sagaMiddleware.run(() sync* {
        yield All(<dynamic, Effect>{
          #put: Put(_FIRST()),
          #takeEvery: TakeEvery(({dynamic action}) sync* {
            yield Put(_SECOND());
          }, pattern: _FIRST)
        });
      });

      //Sagas can't miss actions dispatched by store subscribers during put handling
      expect(Future(() => store.state.value),
          completion(([TypeMatcher<_FIRST>(), TypeMatcher<_SECOND>()])));
    });

    test(
        'action dispatched synchronously in forked task should be taken a following sync take',
        () {
      var actual = <dynamic>[];

      var sagaMiddleware = createSagaMiddleware();

      var store = Store<_State>(
        (_State state, dynamic action) {
          return _State(action);
        },
        initialState: _State(null),
        middleware: [
          applyMiddleware(sagaMiddleware),
        ],
      );

      sagaMiddleware.setStore(store);

      var action = TestActionC('foo');

      var task = sagaMiddleware.run(() sync* {
        // force async, otherwise sync root startup prevents this from being tested appropriately
        // as the scheduler is in suspended state because of it
        yield Delay(Duration(milliseconds: 10));
        yield Fork(() sync* {
          yield Put(action);
        });

        var result = Result<dynamic>();
        yield Take(pattern: TestActionC, result: result);
        actual.add(result.value);
      });

      expect(task.toFuture().then((dynamic value) => actual),
          completion([action]));
    });
  });
}

class _a1 {}

class _a2 {}

class _a3 {}

class _neverHappeningAction {}

class _msg1 {}

class _msg2 {}

class _ack1 {}

class _ack2 {}

class _TEST {}

class _TEST2 {}

class _PING {
  int val;

  _PING(this.val);
}

class _ACK {
  int val;

  _ACK(this.val);
}

class _State {
  dynamic value;

  _State(this.value);
}

class _a {}

class _b {}

class _c {}

class _d {}

class _State2 {
  List<dynamic> value;

  _State2(this.value);
}

class _FIRST {}

class _SECOND {}
