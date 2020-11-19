import 'dart:async';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/utils.dart';
import 'helpers/store.dart';

void main() {
  group('channel recipes tests', () {
    test('action channel', () {
      var actual = <dynamic>[];

      Iterable<Effect> saga() sync* {
        var chan = Result<Channel>();
        yield ActionChannel(TestActionA, result: chan);

        while (true) {
          var action = Result<dynamic>();
          yield Take(channel: chan.value, result: action);
          actual.add(action.value.payload);
          yield Call(() {
            return Future<dynamic>.value(); // block
          });
        }
      }

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(saga);

      store.dispatch(TestActionA(0));
      store.dispatch(TestActionA(1));
      store.dispatch(TestActionA(2));

      store.dispatch(End);

      // Sagas must take consecutive actions dispatched synchronously on an action channel even if it performs blocking calls
      expect(task.toFuture().then((dynamic value) => actual),
          completion([0, 1, 2]));
    });

    test('error check when constructing actionChannels', () {
      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        var chan = Result<Channel>();
        yield ActionChannel([TestActionA, null], result: chan);
      });

      expect(task.toFuture(), throwsA(TypeMatcher<InvalidPattern>()));
    });

    test('channel: watcher + max workers', () {
      var actual = <List<int>>[];

      Iterable<Effect> worker(int idx, Channel chan) sync* {
        var count = 0;

        while (true) {
          var action = Result<dynamic>();
          yield Take(channel: chan, result: action);
          actual.add(<int>[idx, action.value.payload as int]);
          // 1st worker will 'sleep' after taking 2 messages on the 1st round

          if (idx == 1 && ++count == 2) {
            yield Call(() => Future<dynamic>.value());
          }
        }
      }

      Iterable<Effect> saga() sync* {
        var chan = BasicChannel();
        yield Call(() sync* {
          for (var i = 0; i < 3; i++) {
            yield Fork(worker, args: <dynamic>[i + 1, chan]);
          }

          while (true) {
            var action = Result<dynamic>();
            yield Take(pattern: _TestAction, result: action);
            yield Put(action.value, channel: chan);
          }
        }, Finally: () {
          chan.close();
        });
      }

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(saga);

      for (var i = 0; i < 10; i++) {
        store.dispatch(_TestAction(i + 1, 1));
      }

      store.dispatch(End);

      //Saga must dispatch to free workers via channel
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            [1, 1],
            [2, 2],
            [3, 3],
            [1, 4],
            [2, 5],
            [3, 6],
            [2, 7],
            [3, 8],
            [2, 9],
            [3, 10]
          ]));
    });
  });
}

class _TestAction {
  int payload;
  int round;

  _TestAction(this.payload, this.round);
}
