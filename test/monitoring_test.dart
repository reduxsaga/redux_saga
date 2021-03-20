import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/utils.dart';
import 'helpers/store.dart';

void main() {
  group('monitoring tests', () {
    test('saga middleware monitoring', () {
      var ids = <int>[];
      var effects = <int, Map<String, dynamic>>{};
      var actions = <dynamic>[];

      var sagaMiddleware = createMiddleware(
          options: Options(sagaMonitor: _TestMonitor(ids, effects, actions)));
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      store.dispatch(TestActionA(0));

      var apiComps = createArrayOfCompleters<String>(2);

      Future.value(1).then((value) {
        apiComps[0].complete('api1');
      }).then((value) {
        apiComps[1].complete('api2');
      });

      Future<String> api(int idx) {
        return apiComps[idx].future;
      }

      Iterable<Effect> child() sync* {
        yield Call(api, args: <dynamic>[1]);
        yield Put(TestActionB(0));
        throw exceptionToBeCaught;
      }

      Iterable<Effect> main() sync* {
        yield Call(api, args: <dynamic>[0]);
        yield Race(<String, Effect>{
          'action': Take(pattern: 'action'),
          'call': Call(child)
        });
      }

      var task = sagaMiddleware.run(main, Catch: (dynamic e, StackTrace s) {});

      expect(task.toFuture().then((dynamic value) => ids),
          completion([1, 2, 3, 4, 5, 6, 7]));

      //sagaMiddleware must notify the saga monitor of Effect creation and resolution
      expect(
          task.toFuture().then((dynamic value) => effects),
          completion({
            1: {'saga': main, 'args': null, 'namedArgs': null, 'result': task},
            2: {
              'parentEffectId': 1,
              'label': '',
              'effect': TypeMatcher<Call>(),
              'result': 'api1'
            },
            3: {
              'parentEffectId': 1,
              'label': '',
              'effect': TypeMatcher<Race>(),
              'error': exceptionToBeCaught
            },
            4: {
              'parentEffectId': 3,
              'label': 'action',
              'effect': TypeMatcher<Take>(),
              'cancelled': true
            },
            5: {
              'parentEffectId': 3,
              'label': 'call',
              'effect': TypeMatcher<Call>(),
              'error': exceptionToBeCaught
            },
            6: {
              'parentEffectId': 5,
              'label': '',
              'effect': TypeMatcher<Call>(),
              'result': 'api2'
            },
            7: {
              'parentEffectId': 5,
              'label': '',
              'effect': TypeMatcher<Put>(),
              'result': TypeMatcher<TestActionB>()
            }
          }));

      //sagaMiddleware must notify the saga monitor of dispatched actions
      expect(task.toFuture().then((dynamic value) => actions),
          completion([TypeMatcher<TestActionA>(), TypeMatcher<TestActionB>()]));
    });
  });
}

class _TestMonitor implements SagaMonitor {
  List<int> ids;
  Map<int, Map<String, dynamic>> effects;
  List<dynamic> actions;

  _TestMonitor(this.ids, this.effects, this.actions);

  @override
  void actionDispatched(dynamic action) {
    actions.add(action);
  }

  @override
  void effectCancelled(int effectId) {
    set(effectId, 'cancelled', true);
  }

  @override
  void effectRejected(int effectId, dynamic error) {
    set(effectId, 'error', error);
  }

  @override
  void effectResolved(int effectId, dynamic result) {
    set(effectId, 'result', result);
  }

  @override
  void effectTriggered(
      int effectId, int parentEffectId, dynamic label, dynamic effect) {
    ids.add(effectId);
    set(effectId, 'parentEffectId', parentEffectId);
    set(effectId, 'label', label);
    set(effectId, 'effect', effect);
  }

  @override
  void rootSagaStarted(int effectId, Function saga, List? args,
      Map<Symbol, dynamic>? namedArgs, String? name) {
    ids.add(effectId);
    set(effectId, 'saga', saga);
    set(effectId, 'args', args);
    set(effectId, 'namedArgs', namedArgs);
  }

  void set(int effectId, String key, dynamic value) {
    if (effects[effectId] == null) {
      effects[effectId] = <String, dynamic>{};
    }
    effects[effectId]![key] = value;
  }
}
