import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/store.dart';
import 'helpers/utils.dart';

void main() {
  group('context test', () {
    test('saga must handle context in dynamic scoping manner', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware(
          options: Options(context: <dynamic, dynamic>{#a: 1}));
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        var result = Result<dynamic>();
        yield GetContext(#a, result: result);
        actual.add(result.value);

        yield SetContext(<dynamic, dynamic>{#b: 2});

        yield Fork(() sync* {
          var result2 = Result<dynamic>();
          yield GetContext(#a, result: result2);
          actual.add(result2.value);
          yield GetContext(#b, result: result2);
          actual.add(result2.value);
          yield SetContext(<dynamic, dynamic>{#c: 3});
          yield GetContext(#c, result: result2);
          actual.add(result2.value);
        });

        yield GetContext(#c, result: result);
        actual.add(result.value);
      });

      //saga must handle context in dynamic scoping manner
      expect(task.toFuture().then((dynamic value) => actual),
          completion([1, 1, 2, 3, null]));
    });
  });
}
