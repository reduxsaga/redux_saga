import 'package:fake_async/fake_async.dart';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/utils.dart';
import 'helpers/store.dart';

void main() {
  group('delay tests', () {
    test('delay', () {
      fakeAsync((async) {
        var actual = <dynamic>[];
        var myVal = 'myVal';

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        sagaMiddleware.run(() sync* {
          var result = Result<dynamic>();
          yield Delay(Duration(milliseconds: 1), result: result);
          actual.add(result.value);
          yield Delay(Duration(milliseconds: 1), value: myVal, result: result);
          actual.add(result.value);
        });

        //process all
        async.elapse(Duration(milliseconds: 100));

        //throttle must ignore incoming actions during throttling interval
        expect(actual, equals([true, myVal]));
      });
    });
  });
}
