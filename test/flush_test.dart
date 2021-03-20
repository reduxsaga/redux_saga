import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/utils.dart';
import 'helpers/store.dart';

void main() {
  group('flush tests', () {
    test('saga flush handling', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(() sync* {
        var channel = Result<Channel>();
        yield Call(() => BasicChannel(), result: channel);

        var result = Result<dynamic>();
        yield FlushChannel(channel.value!, result: result);
        actual.add(result.value);

        yield Put(1, channel: channel.value);
        yield Put(2, channel: channel.value);
        yield Put(3, channel: channel.value);

        yield FlushChannel(channel.value!, result: result);
        actual.add(result.value);

        yield Put(4, channel: channel.value);
        yield Put(5, channel: channel.value);

        channel.value!.close();

        yield FlushChannel(channel.value!, result: result);
        actual.add(result.value);

        yield FlushChannel(channel.value!, result: result);
        actual.add(result.value);
      });

      //saga must handle generator flushes
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion(<dynamic>[
            <dynamic>[],
            [1, 2, 3],
            [4, 5],
            [End]
          ]));
    });
  });
}
