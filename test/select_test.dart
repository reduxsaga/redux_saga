import 'dart:async';
import 'package:redux/redux.dart';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/store.dart';
import 'helpers/utils.dart';

void main() {
  group('select test', () {
    test('saga select/getState handling', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createSagaMiddleware();

      var store = Store<_State>(
        (_State state, dynamic action) {
          if (action is _Inc) {
            return _State(state.counter + 1, state.arr);
          }
          return state;
        },
        initialState: _State(0, <int>[1, 2]),
        middleware: [
          applyMiddleware(sagaMiddleware),
        ],
      );

      sagaMiddleware.setStore(store);

      var comp = Completer<dynamic>();

      int counterSelector(_State state) {
        return state.counter;
      }

      int arrSelector(_State state, int idx) {
        return state.arr[idx];
      }

      var task = sagaMiddleware.run(() sync* {
        var result = Result<dynamic>();

        yield Select(result: result);
        actual.add(result.value.counter);

        yield Select(selector: counterSelector, result: result);
        actual.add(result.value);

        yield Select(selector: arrSelector, args: <dynamic>[1], result: result);
        actual.add(result.value);

        yield Call(() => comp.future);

        yield Select(result: result);
        actual.add(result.value.counter);

        yield Select(selector: counterSelector, result: result);
        actual.add(result.value);
      });

      ResolveSequentially([
        callF(() {
          comp.complete(1);
          store.dispatch(_Inc());
        })
      ]);

      // should resolve getState and select effects
      expect(task.toFuture().then((dynamic value) => actual), completion([0, 0, 2, 1, 1]));
    });

    test('select test', () {
      var result1 = Result<dynamic>();
      var result2 = Result<int>();

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        yield Put(IncrementCounterAction());
        yield Select(result: result1);
        yield Select(selector: selectCounter, result: result2);
      });

      expect(
          task.toFuture().then((dynamic value) => <dynamic>[
                value,
                task.result,
                task.isRunning,
                task.isCancelled,
                task.isAborted,
                result1.value.x,
                result2.value
              ]),
          completion([null, null, false, false, false, 1, 1]));
    });
  });
}

class _State {
  int counter;
  List<int> arr;

  _State(this.counter, this.arr);
}

class _Inc {}
