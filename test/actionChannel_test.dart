import 'package:fake_async/fake_async.dart';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';

import 'helpers/utils.dart';
import 'helpers/store.dart';

void main() {
  group('actionChannel test', () {
    test('saga create channel for store actions', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        var channel = Result<Channel>();
        yield ActionChannel(TestActionA, result: channel);

        for (var i = 0; i < 10; i++) {
          yield Call(() => Future(() => 1));
          var takeResult = Result<dynamic>();
          yield Take(channel: channel.value, result: takeResult);
          actual.add(takeResult.value.payload);
        }
      });

      for (var i = 0; i < 10; i++) {
        store.dispatch(TestActionA(i + 1));
      }

      // saga must queue dispatched actions
      expect(task.toFuture().then((dynamic value) => actual),
          completion([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]));
    });

    test('saga create channel for store actions (with buffer)', () {
      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var buffer = Buffers.expanding<TestActionA>();

      var task = sagaMiddleware.run(() sync* {
        var channel = Result<Channel>();
        yield ActionChannel(TestActionA, buffer: buffer, result: channel);
        yield Return(channel.value);
      });

      for (var i = 0; i < 10; i++) {
        store.dispatch(TestActionA(i + 1));
      }

      expect(task.toFuture(), completion(TypeMatcher<Channel>()));

      //saga must queue dispatched actions
      expect(task.toFuture().then((dynamic value) => buffer.flush().map((e) => e.payload)),
          completion([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]));
    });

    test('actionChannel test', () {
      fakeAsync((async) {
        var values = <int>[];

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          var channel = Result<Channel>();
          yield ActionChannel(TestActionA, result: channel);

          while (true) {
            var result = Result<dynamic>();
            yield Take(channel: channel.value, result: result);
            values.add(result.value.payload as int);
            yield Delay(Duration(milliseconds: 1));
          }
        });

        for (var i = 0; i < 10; i++) {
          store.dispatch(TestActionA(i));
        }

        store.dispatch(End);

        expect(
            task.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  task.result,
                  task.isRunning,
                  task.isCancelled,
                  task.isAborted,
                  values
                ]),
            completion([null, null, false, false, false, Iterable<int>.generate(10).toList()]));

        async.elapse(Duration(milliseconds: 500));
      });
    });

    test('flushChannel test', () {
      fakeAsync((async) {
        var values = <int>[];

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          var channel = Result<Channel>();
          yield ActionChannel(TestActionA, result: channel);

          yield Delay(Duration(milliseconds: 1));

          var result = Result<List<dynamic>>();

          yield FlushChannel(channel.value, result: result);

          result.value.forEach((dynamic v) {
            values.add(v.payload as int);
          });
        });

        for (var i = 0; i < 10; i++) {
          store.dispatch(TestActionA(i));
        }

        expect(
            task.toFuture().then((dynamic value) => <dynamic>[
                  value,
                  task.result,
                  task.isRunning,
                  task.isCancelled,
                  task.isAborted,
                  values
                ]),
            completion([null, null, false, false, false, Iterable<int>.generate(10).toList()]));

        async.elapse(Duration(milliseconds: 500));
      });
    });
  });
}
