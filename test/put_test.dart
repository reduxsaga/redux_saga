import 'dart:async';

import 'package:redux/redux.dart';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/store.dart';
import 'helpers/utils.dart';

void main() {
  group('put test', () {
    test('saga put handling', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createSagaMiddleware();

      var store = Store<EmptyState>(
        (EmptyState state, dynamic action) {
          return EmptyState();
        },
        initialState: EmptyState(),
        middleware: [
          _storeDispatcher<EmptyState>(actual),
          applyMiddleware(sagaMiddleware),
        ],
      );

      sagaMiddleware.setStore(store);

      dynamic action1;
      dynamic action2;

      Iterable<Effect> genFn(dynamic arg) sync* {
        action1 = TestActionD(arg);
        yield Put(action1);

        action2 = TestActionA(2);
        yield Put(action2);
      }

      var task = sagaMiddleware.run(genFn, args: <dynamic>['arg']);

      // saga must handle generator puts
      expect(task.toFuture().then((dynamic value) => actual),
          completion(<dynamic>[action1, action2]));
    });

    test('saga put in a channel', () {
      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      dynamic action1;
      dynamic action2;

      var buffer = Buffers.expanding<dynamic>();
      var channel = BasicChannel(buffer: buffer);

      Iterable<Effect> genFn(dynamic arg) sync* {
        action1 = TestActionD(arg);
        yield Put(action1, channel: channel);

        action2 = TestActionA(2);
        yield Put(action2, channel: channel);
      }

      var task = sagaMiddleware.run(genFn, args: <dynamic>['arg']);

      // saga must handle puts on a given channel
      expect(task.toFuture().then((dynamic value) => buffer.flush()),
          completion(<dynamic>[action1, action2]));
    });

    test('saga async put\'s response handling', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      dynamic action1;
      dynamic action2;

      Iterable<Effect> genFn(dynamic arg) sync* {
        action1 = TestActionD(arg);
        action2 = TestActionA(2);

        var result = Result<dynamic>();
        yield PutResolve(Future<dynamic>(() => action1), result: result);
        actual.add(result.value);

        yield PutResolve(Future<dynamic>(() => action2), result: result);
        actual.add(result.value);
      }

      var task = sagaMiddleware.run(genFn, args: <dynamic>['arg']);

      // saga must handle async responses of generator put effects
      expect(task.toFuture().then((dynamic value) => actual),
          completion(<dynamic>[action1, action2]));
    });

    test('saga error put\'s response handling', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createSagaMiddleware();

      var store = Store<EmptyState>(
        (EmptyState state, dynamic action) {
          if (action is _Action && action.error) {
            throw exceptionToBeCaught;
          }
          return EmptyState();
        },
        initialState: EmptyState(),
        middleware: [
          applyMiddleware(sagaMiddleware),
        ],
      );

      sagaMiddleware.setStore(store);

      Iterable<Effect> genFn(dynamic arg) sync* {
        yield Try(() sync* {
          yield Put(_Action(arg, true));
        }, Catch: (dynamic e, StackTrace s) sync* {
          actual.add(e);
        });
      }

      var task = sagaMiddleware.run(genFn, args: <dynamic>['arg']);

      // saga should bubble thrown errors of generator put effects
      expect(task.toFuture().then((dynamic value) => actual),
          completion(<dynamic>[exceptionToBeCaught]));
    });

    test('saga error putResolve\'s response handling', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      Object? error;

      Iterable<Effect> genFn(dynamic arg) sync* {
        yield Try(() sync* {
          error = Exception('error $arg');
          yield PutResolve(Future(() => throw error!));
        }, Catch: (dynamic e, StackTrace s) sync* {
          actual.add(e);
        });
      }

      var task = sagaMiddleware.run(genFn, args: <dynamic>['arg']);

      // saga must bubble thrown errors of generator putResolve effects
      expect(task.toFuture().then((dynamic value) => actual),
          completion(<Object?>[error]));
    });

    test('saga nested puts handling', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      Iterable<Effect> genA() sync* {
        yield Put(TestActionA(1));
        actual.add('put a');
      }

      Iterable<Effect> genB() sync* {
        yield Take(pattern: TestActionA);
        yield Put(TestActionB(2));
        actual.add('put b');
      }

      Iterable<Effect> root() sync* {
        yield Fork(
            genB); // forks genB first to be ready to take before genA starts putting
        yield Fork(genA);
      }

      var task = sagaMiddleware.run(root);

      // saga must order nested puts by executing them after the outer puts complete
      expect(task.toFuture().then((dynamic value) => actual),
          completion(['put a', 'put b']));
    });

    test('puts emitted while dispatching saga need not to cause stack overflow',
        () {
      var channel = _TestChannel();

      var sagaMiddleware = createMiddleware(options: Options(channel: channel));
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      Iterable<Effect> root() sync* {
        yield Put(TestActionC('put a lot of actions'));
        yield Delay(Duration(milliseconds: 0));
      }

      var task = sagaMiddleware.run(root);

      // this saga needs to run without stack overflow
      expect(task.toFuture(), completion(null));
    });

    test('saga error putResolve\'s response handling', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      Object? error;

      Iterable<Effect> genFn(dynamic arg) sync* {
        yield Try(() sync* {
          error = Exception('error $arg');
          yield PutResolve(Future(() => throw error!));
        }, Catch: (dynamic e, StackTrace s) sync* {
          actual.add(e);
        });
      }

      var task = sagaMiddleware.run(genFn, args: <dynamic>['arg']);

      // saga must bubble thrown errors of generator putResolve effects
      expect(task.toFuture().then((dynamic value) => actual),
          completion(<Object?>[error]));
    });

    test(
        'puts emitted directly after creating a task (caused by another put) should not be missed by that task',
        () {
      var actual = <dynamic>[];

      var sagaMiddleware = createSagaMiddleware();

      var store = Store<_State>(
        (_State state, dynamic action) {
          return _State(action is _ActionB && action.callSubscriber);
        },
        initialState: _State(false),
        middleware: [
          applyMiddleware(sagaMiddleware),
        ],
      );

      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield Take(pattern: _ActionA);
        yield Put(_ActionB(true));
        yield Take(pattern: _ActionC);
        yield Fork(() sync* {
          yield Take(pattern: _ActionDontMiss);
          actual.add('didn\'t get missed');
        });
      });

      store.onChange.listen((event) {
        if (event.callSubscriber) {
          store.dispatch(_ActionC());
          store.dispatch(_ActionDontMiss());
        }
      });

      store.dispatch(_ActionA());

      expect(task.toFuture().then((dynamic value) => actual),
          completion(['didn\'t get missed']));
    });

    test('END should reach tasks created after it gets dispatched', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      Iterable<Effect> subTask() sync* {
        yield Try(() sync* {
          while (true) {
            actual.add('subTask taking END');
            yield Take(pattern: _Next);
            actual.add('should not get here');
          }
        }, Finally: () sync* {
          actual.add('auto ended');
        });
      }

      var comp = Completer<dynamic>();

      var task = sagaMiddleware.run(() sync* {
        while (true) {
          yield Take(pattern: _Start);
          actual.add('start taken');
          yield Call(() => comp.future);
          actual.add('non-take effect resolved');
          yield Fork(subTask);
          actual.add('subTask forked');
        }
      });

      ResolveSequentially([
        callF(() {
          store.dispatch(_Start());
          store.dispatch(End);
        }),
        callF(() {
          comp.complete(1);
          store.dispatch(_Next());
          store.dispatch(_Start());
        }),
      ]);

      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            'start taken',
            'non-take effect resolved',
            'subTask taking END',
            'auto ended',
            'subTask forked'
          ]));
    });

    test('put test', () {
      var sagaMiddleware = createSagaMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield Put(IncrementCounterAction());
        yield Put(IncrementCounterAction());
        yield Put(IncrementCounterAction());
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                store.state.x
              ]),
          completion([null, null, false, false, false, 3]));
    });

    test('put test', () {
      var values = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        var result = Result<dynamic>();
        yield All(<Symbol, Effect>{
          #fork1: Fork(() sync* {
            while (true) {
              yield Take(result: result);
              values.add((result.value as TestActionA).payload);
            }
          }),
          #fork2: Fork(() sync* {
            for (var i = 0; i < 10; i++) {
              yield Put(TestActionA(i));
            }
            yield Put(End);
          })
        });
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                values
              ]),
          completion([
            null,
            null,
            false,
            false,
            false,
            [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
          ]));
    });

    test('put test', () {
      var values = <int>[];

      final channel = BasicChannel(buffer: Buffers.expanding<dynamic>());

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        var result = Result<dynamic>();
        yield All(<Symbol, Effect>{
          #fork1: Fork(() sync* {
            while (true) {
              yield Take(channel: channel, result: result);
              values.add((result.value as TestActionA).payload);
            }
          }),
          #fork2: Fork(() sync* {
            for (var i = 0; i < 10; i++) {
              yield Put(TestActionA(i), channel: channel);
            }
            yield Put(End, channel: channel);
          })
        });
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                values
              ]),
          completion([
            null,
            null,
            false,
            false,
            false,
            [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
          ]));
    });

    test('put test', () {
      var values = <int>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        var result = Result<dynamic>();
        yield All(<Symbol, Effect>{
          #fork1: Fork(() sync* {
            while (true) {
              yield Take(result: result);
              values.add((result.value as TestActionA).payload);
            }
          }),
          #fork2: Fork(() sync* {
            for (var i = 0; i < 10; i++) {
              yield PutResolve(TestActionA(i));
            }
            yield PutResolve(End);
          })
        });
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                values
              ]),
          completion([
            null,
            null,
            false,
            false,
            false,
            [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
          ]));
    });

    test('put test', () {
      var values = <int>[];

      final channel = BasicChannel(buffer: Buffers.expanding<dynamic>());

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        var result = Result<dynamic>();
        yield All(<Symbol, Effect>{
          #fork1: Fork(() sync* {
            while (true) {
              yield Take(channel: channel, result: result);
              values.add((result.value as TestActionA).payload);
            }
          }),
          #fork2: Fork(() sync* {
            for (var i = 0; i < 10; i++) {
              yield PutResolve(TestActionA(i), channel: channel);
            }
            yield PutResolve(End, channel: channel);
          })
        });
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                values
              ]),
          completion([
            null,
            null,
            false,
            false,
            false,
            [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
          ]));
    });
  });
}

class _State {
  bool callSubscriber;

  _State(this.callSubscriber);
}

class _Next {}

class _Start {}

class _Action {
  dynamic type;
  bool error;

  _Action(this.type, this.error);
}

class _ActionA {}

class _ActionB {
  bool callSubscriber;

  _ActionB(this.callSubscriber);
}

class _ActionC {}

class _ActionDontMiss {}

class _storeDispatcher<T> implements MiddlewareClass<T> {
  final List<dynamic> logger;

  _storeDispatcher(this.logger);

  @override
  dynamic call(Store<T> store, dynamic action, NextDispatcher next) {
    logger.add(action);
    return next(action);
  }
}

class _TestChannel extends StdChannel {
  @override
  void put(dynamic message) {
    var action = TestActionC('test');
    for (var i = 0; i < 32768; i++) {
      super.put(action);
    }
  }
}
