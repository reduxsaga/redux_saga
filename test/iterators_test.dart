import 'dart:async';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/utils.dart';
import 'helpers/store.dart';

void main() {
  group('iterators tests', () {
    test('saga nested iterator handling', () {
      var actual = <dynamic>[];

      var comps = createArrayOfCompleters<dynamic>(3);

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      Iterable<Effect> child() sync* {
        var result = Result<dynamic>();

        yield Call(() => comps[0].future, result: result);
        actual.add(result.value);

        yield Take(pattern: TestActionA, result: result);
        actual.add(result.value);

        yield Call(() => comps[1].future, result: result);
        actual.add(result.value);

        yield Take(pattern: TestActionB, result: result);
        actual.add(result.value);

        yield Call(() => comps[2].future, result: result);
        actual.add(result.value);

        yield Take(pattern: TestActionC, result: result);
        actual.add(result.value);

        yield Call(() => Future<dynamic>.error('child error'));
        actual.add(result.value);
      }

      Iterable<Effect> main() sync* {
        yield Try(() sync* {
          yield* child();
        }, Catch: (dynamic e, StackTrace s) {
          actual.add('caught $e');
        });
      }

      var task = sagaMiddleware.run(main);

      ResolveSequentially([
        callF(() => comps[0].complete(1)),
        callF(() => store.dispatch(TestActionA(1))),
        callF(() => comps[1].complete(2)),
        callF(() => store.dispatch(TestActionB(2))),
        callF(() => comps[2].complete(3)),
        callF(() => store.dispatch(TestActionC('3'))),
      ]);

      // saga must fulfill nested iterator effects
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            1,
            TypeMatcher<TestActionA>(),
            2,
            TypeMatcher<TestActionB>(),
            3,
            TypeMatcher<TestActionC>(),
            'caught child error'
          ]));
    });
  });
}
