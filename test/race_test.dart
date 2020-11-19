import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/utils.dart';
import 'helpers/store.dart';

void main() {
  group('race test', () {
    test('saga race between effects handling', () {
      var comp = Completer<int>();

      var race = RaceResult();

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield Race(<Symbol, Effect>{
          #event: Take(pattern: TestActionA),
          #timeout: Call(() => comp.future)
        }, result: race);
      });

      var action = TestActionA(2);

      var f = ResolveSequentially(
        [
          callF(() => comp.complete(1)),
          callF(() => store.dispatch(action)),
          () => task.toFuture()
        ],
      );

      //saga must fulfill race between effects
      expect(f.then((dynamic value) => race.value),
          completion(<Symbol, dynamic>{#timeout: 1}));
    });

    test('saga race between effects: handle END', () {
      var comp = Completer<int>();

      var race = RaceResult();

      bool called;

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        called = true;
        yield Race(<Symbol, Effect>{
          #event: Take(pattern: TestActionA),
          #timeout: Call(() => comp.future)
        }, result: race);
      });

      var f = ResolveSequentially([
        callF(() => store.dispatch(End)),
        callF(() => comp.complete(1)),
        () => task.toFuture()
      ]);

      //should run saga
      expect(f.then((dynamic value) => called), completion(true));

      //saga must end Race Effect if one of the effects resolve with END
      expect(f.then((dynamic value) => race.value), completion(null));
    });

    test('saga race between sync effects', () {
      var race = RaceResult();
      var xflush = Result<dynamic>();
      var yflush = Result<dynamic>();

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        var xChan = Result<Channel>();
        yield ActionChannel(_X, result: xChan);

        var yChan = Result<Channel>();
        yield ActionChannel(_Y, result: yChan);

        yield Take(pattern: _Start);

        yield Race(<Symbol, Effect>{
          #x: Take(channel: xChan.value),
          #y: Take(channel: yChan.value)
        }, result: race);

        // waiting for next tick
        yield Call(() => Future<int>.value(0));

        yield FlushChannel(xChan.value, result: xflush);

        yield FlushChannel(yChan.value, result: yflush);
      });

      var x = _X();
      var y = _Y();
      var start = _Start();

      var f = ResolveSequentially([
        callF(() => store.dispatch(x)),
        callF(() => store.dispatch(y)),
        callF(() => store.dispatch(start)),
        () => task.toFuture()
      ]);

      //saga must not run effects when already completed
      expect(
          f.then<dynamic>((dynamic value) => xflush.value), completion(<_X>[]));
      expect(f.then<dynamic>((dynamic value) => yflush.value),
          completion(<_Y>[y]));
      expect(f.then((dynamic value) => race.value),
          completion(<Symbol, dynamic>{#x: x}));
    });

    test('saga race cancelling joined tasks', () {
      var race = RaceResult();

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        var fork1 = Result<Task>();
        yield Fork(() sync* {
          yield Delay(Duration(milliseconds: 10));
        }, result: fork1);

        var fork2 = Result<Task>();
        yield Fork(() sync* {
          yield Delay(Duration(milliseconds: 100));
        }, result: fork2);

        yield Race(<Symbol, Effect>{
          #join:
              Join(<dynamic, Task>{#fork1: fork1.value, #fork2: fork2.value}),
          #timeout: Delay(Duration(milliseconds: 50))
        }, result: race);
      });

      //saga race must cancel join effect
      expect(task.toFuture().then((dynamic value) => race.value),
          completion(<Symbol, dynamic>{#timeout: true}));
    });

    test('race test', () {
      fakeAsync((async) {
        var result1 = RaceResult();
        var result2 = RaceResult();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          yield Race(<dynamic, Effect>{
            #delay: Delay(Duration(milliseconds: 100)),
            #take: Take()
          }, result: result1);
          yield Race(<dynamic, Effect>{
            #delay: Delay(Duration(milliseconds: 1)),
            #take: Take()
          }, result: result2);
        });

        var action1 = TestActionA(0);
        var action2 = TestActionA(0);

        Future<dynamic>.delayed(
            Duration(milliseconds: 1), () => store.dispatch(action1));
        Future<dynamic>.delayed(
            Duration(milliseconds: 100), () => store.dispatch(action2));

        expect(
            task.toFuture().then(
                (dynamic value) => <dynamic>[result1.value, result2.value]),
            completion([
              {#take: action1},
              {#delay: true}
            ]));

        async.elapse(Duration(milliseconds: 500));
      });
    });

    test('race test', () {
      fakeAsync((async) {
        var result1 = RaceResult();

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(() sync* {
          yield Race(<dynamic, Effect>{
            'call1': Call(() sync* {
              for (var i = 0; i < 10; i++) {
                yield Delay(Duration(milliseconds: 1));
              }
              yield Return(value1);
            }),
            'call2': Call(() sync* {
              for (var i = 0; i < 5; i++) {
                yield Delay(Duration(milliseconds: 1));
              }
              yield Return(value2);
            })
          }, result: result1);
        });

        expect(
            task.toFuture().then((dynamic value) => <dynamic>[result1.value]),
            completion([
              {'call2': value2}
            ]));

        async.elapse(Duration(milliseconds: 500));
      });
    });
  });
}

class _X {}

class _Y {}

class _Start {}
