import 'package:fake_async/fake_async.dart';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/utils.dart';
import 'helpers/store.dart';

void main() {
  group('debounce tests', () {
    test('debounce: sync actions', () {
      fakeAsync((async) {
        final delayMs = 33;
        final largeDelayMs = delayMs + 100;
        var called = 0;

        var actual = <List<dynamic>>[];

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        sagaMiddleware.run(() sync* {
          var forkedTask = Result<Task>();

          yield Debounce(({dynamic action}) sync* {
            called++;
            actual.add(<dynamic>[called, action.payload]);
          }, duration: Duration(milliseconds: delayMs), pattern: TestActionC, result: forkedTask);
          yield Take(pattern: TestActionCancel);
          yield Cancel([forkedTask.value]);
        });

        var f = ResolveSequentially([
          callF(() {
            store.dispatch(TestActionC('a'));
            store.dispatch(TestActionC('b'));
            store.dispatch(TestActionC('c'));
          }),
          delayF(largeDelayMs),
          callF(() => store.dispatch(TestActionCancel())),
        ]);

        // should debounce sync actions and pass the latest action to a worker
        expect(
            f.then((dynamic value) => actual),
            completion([
              [1, 'c']
            ]));

        //process all
        async.elapse(Duration(milliseconds: 500));
      });
    });

    test('debounce: async actions', () {
      fakeAsync((async) {
        final delayMs = 30;
        final smallDelayMs = delayMs - 10;
        final largeDelayMs = delayMs + 10;
        var called = 0;

        var actual = <List<dynamic>>[];

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        sagaMiddleware.run(() sync* {
          var forkedTask = Result<Task>();

          yield Debounce(({dynamic action}) sync* {
            called++;
            actual.add(<dynamic>[called, action.payload]);
          }, duration: Duration(milliseconds: delayMs), pattern: TestActionC, result: forkedTask);
          yield Take(pattern: TestActionCancel);
          yield Cancel([forkedTask.value]);
        });

        var f = ResolveSequentially([
          callF(() => store.dispatch(TestActionC('a'))),
          delayF(smallDelayMs),
          callF(() => store.dispatch(TestActionC('b'))),
          delayF(smallDelayMs),
          callF(() => store.dispatch(TestActionC('c'))),
          delayF(largeDelayMs),
          callF(() => store.dispatch(TestActionC('d'))),
          delayF(largeDelayMs),
          callF(() => store.dispatch(TestActionC('e'))),
          delayF(smallDelayMs),
          callF(() => store.dispatch(TestActionCancel())),
        ]);

        // should debounce sync actions and pass the latest action to a worker
        expect(
            f.then((dynamic value) => actual),
            completion([
              [1, 'c'],
              [2, 'd']
            ]));

        //process all
        async.elapse(Duration(milliseconds: 500));
      });
    });

    test('debounce: cancelled', () {
      fakeAsync((async) {
        final delayMs = 30;
        final smallDelayMs = delayMs - 10;
        var called = 0;

        var actual = <List<dynamic>>[];

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        sagaMiddleware.run(() sync* {
          var forkedTask = Result<Task>();

          yield Debounce(({dynamic action}) sync* {
            called++;
            actual.add(<dynamic>[called, action.payload]);
          }, duration: Duration(milliseconds: delayMs), pattern: TestActionC, result: forkedTask);
          yield Take(pattern: TestActionCancel);
          yield Cancel([forkedTask.value]);
        });

        var f = ResolveSequentially([
          callF(() => store.dispatch(TestActionC('a'))),
          delayF(smallDelayMs),
          callF(() => store.dispatch(TestActionCancel())),
        ]);

        //should not call a worker if cancelled before debounce limit is reached
        expect(f.then((dynamic value) => actual), completion(<dynamic>[]));

        //process all
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('debounce: channel', () {
      fakeAsync((async) {
        final delayMs = 30;
        final largeDelayMs = delayMs + 10;
        var called = 0;
        final customChannel = BasicChannel();

        var actual = <List<dynamic>>[];

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        sagaMiddleware.run(() sync* {
          var forkedTask = Result<Task>();

          yield Debounce(({dynamic action}) sync* {
            called++;
            actual.add(<dynamic>[called, action]);
          }, duration: Duration(milliseconds: delayMs), channel: customChannel, result: forkedTask);
          yield Take(pattern: TestActionCancel);
          yield Cancel([forkedTask.value]);
        });

        var f = ResolveSequentially([
          callF(() {
            customChannel.put('a');
            customChannel.put('b');
            customChannel.put('c');
          }),
          delayF(largeDelayMs),
          callF(() => customChannel.put('d')),
          callF(() => store.dispatch(TestActionCancel())),
        ]);

        //should not call a worker if cancelled before debounce limit is reached
        expect(
            f.then((dynamic value) => actual),
            completion([
              [1, 'c']
            ]));

        //process all
        async.elapse(Duration(milliseconds: 500));
      });
    });

    test('debounce: channel END', () {
      fakeAsync((async) {
        final delayMs = 30;
        final smallDelayMs = delayMs - 10;
        var called = 0;
        final customChannel = BasicChannel();

        var forkedTask = Result<Task>();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        sagaMiddleware.run(() sync* {
          yield Debounce(({dynamic action}) sync* {
            called++;
          }, duration: Duration(milliseconds: delayMs), channel: customChannel, result: forkedTask);
        });

        var f = ResolveSequentially([
          callF(() => customChannel.put(End)),
          delayF(smallDelayMs),
        ]);

        expect(
            f.then((dynamic value) => <dynamic>[
                  forkedTask.value.isRunning, // should finish debounce task on END
                  called // should not call function if finished with END
                ]),
            completion([false, 0]));

        //process all
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('debounce: pattern END', () {
      fakeAsync((async) {
        final delayMs = 30;
        final smallDelayMs = delayMs - 10;
        var called = 0;

        var forkedTask = Result<Task>();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        sagaMiddleware.run(() sync* {
          yield Debounce(({dynamic action}) sync* {
            called++;
          }, duration: Duration(milliseconds: delayMs), pattern: TestActionC, result: forkedTask);
        });

        var f = ResolveSequentially([
          delayF(smallDelayMs),
          callF(() => store.dispatch(End)),
        ]);

        expect(
            f.then((dynamic value) => <dynamic>[
                  forkedTask.value.isRunning, // should finish debounce task on END
                  called // should not call function if finished with END
                ]),
            completion([false, 0]));

        //process all
        async.elapse(Duration(milliseconds: 100));
      });
    });

    test('debounce: pattern END during race', () {
      fakeAsync((async) {
        final delayMs = 30;
        final largeDelayMs = delayMs + 10;
        var called = 0;

        var forkedTask = Result<Task>();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        sagaMiddleware.run(() sync* {
          yield Debounce(({dynamic action}) sync* {
            called++;
          }, duration: Duration(milliseconds: delayMs), pattern: TestActionC, result: forkedTask);
        });

        var f = ResolveSequentially([
          callF(() => store.dispatch(TestActionC(null))),
          callF(() => store.dispatch(End)),
          delayF(largeDelayMs),
          callF(() => store.dispatch(TestActionC(null))),
        ]);

        expect(
            f.then((dynamic value) => <dynamic>[
                  forkedTask.value.isRunning, // should finish debounce task on END
                  called // should interrupt race on END
                ]),
            completion([false, 0]));

        //process all
        async.elapse(Duration(milliseconds: 100));
      });
    });
  });
}
