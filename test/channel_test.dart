import 'dart:async';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';

void main() {
  group('Channel tests', () {
    test('Unbuffered channel', () {
      final actual = <dynamic>[];

      final logger = (dynamic ac) => actual.add(ac);

      final chan = BasicChannel(buffer: Buffers.none<dynamic>());

      // channel should reject null messages
      expect(() => chan.put(null), throwsException);

      var callback = TakeCallback<dynamic>(logger);
      chan.take(callback);

      chan.put(1); // channel must notify takers

      expect(actual, equals([1]));

      callback.cancel();
      chan.put(1); // channel must discard cancelled takes

      expect(actual, equals([1]));

      actual.clear();
      chan.take(TakeCallback<dynamic>(logger));
      chan.take(TakeCallback<dynamic>(logger));
      chan.close(); // closing a channel must resolve all takers with END

      expect(actual, equals([End, End]));

      actual.clear();
      chan.take(TakeCallback<dynamic>(
          logger)); // closed channel must resolve new takers with END

      expect(actual, equals([End]));

      chan.put(
          'action-after-end'); // channel must reject messages after being closed

      expect(actual, equals([End]));
    });

    test('Buffered channel', () {
      final spyBuffer = _spyBuffer();

      final chan = BasicChannel(buffer: spyBuffer);

      final log = <dynamic>[];

      final called = <String, bool>{};

      final taker = (String id) {
        final _taker = TakeCallback<dynamic>((dynamic ac) {
          called[id] = true;
          log.add(ac);
        });

        called[id] = false;
        return _taker;
      };

      final t1 = taker('t1');
      // channel must queue pending takers if there are no buffered messages
      chan.take(t1);

      expect([called['t1'], log, spyBuffer.buffer],
          equals([false, <dynamic>[], <dynamic>[]]));

      final t2 = taker('t2');
      chan.take(t2);
      // channel must resolve the oldest pending taker with a new message
      chan.put(1);

      expect(
          [called['t1'], called['t2'], log, spyBuffer.buffer],
          equals([
            true,
            false,
            [1],
            <dynamic>[]
          ]));

      chan.put(2);
      chan.put(3);
      chan.put(4); // channel must buffer new messages if there are no takers

      expect(
          [spyBuffer.buffer, called['t2'], log],
          equals([
            [3, 4],
            true,
            [1, 2]
          ]));

      final t3 = taker('t3');
      chan.take(
          t3); // channel must resolve new takers if there are buffered messages

      expect(
          [called['t3'], spyBuffer.buffer, log],
          equals([
            true,
            [4],
            [1, 2, 3]
          ]));

      chan.close(); // closing an already closed channel should be noop

      chan.close();
      chan.put('hi');
      chan.put(
          'I said hi'); // putting on an already closed channel should be noop

      expect(spyBuffer.buffer, equals([4]));

      chan.take(taker(
          't4')); // closed channel must resolve new takers with any buffered message

      expect(
          [log, spyBuffer.buffer],
          equals([
            [1, 2, 3, 4],
            <dynamic>[]
          ]));
      chan.take(taker(
          't5')); // closed channel must resolve new takers with END if there are no buffered message

      expect(log, equals([1, 2, 3, 4, End]));
    });

    test('Event channel', () {
      dynamic _emitter;

      final chan = EventChannel(
          (emitter) {
            _emitter = (dynamic v) => emitter(v);

            return () => _emitter = (dynamic v) {};
          },
          buffer: Buffers.expanding<dynamic>(10));

      final actual = <dynamic>[];
      chan.take(
          TakeCallback<dynamic>((dynamic message) => actual.add(message)));
      _emitter('action-1'); // eventChannel must notify takers on a new action

      expect(actual, equals(['action-1']));

      _emitter('action-1'); // eventChannel must notify takers only once

      expect(actual, equals(['action-1']));

      // eventChannel must notify takers if messages are buffered
      chan.take(
          TakeCallback<dynamic>((dynamic message) => actual.add(message)));

      expect(actual, equals(['action-1', 'action-1']));

      actual.clear();
      chan.take(
          TakeCallback<dynamic>((dynamic message) => actual.add(message)));
      chan.close(); // eventChannel must notify all pending takers on END

      expect(actual, equals([End]));

      actual.clear();
      // eventChannel must notify all new takers if closed
      chan.take(
          TakeCallback<dynamic>((dynamic message) => actual.add(message)));

      expect(actual, equals([End]));
    });

    test('Unsubscribe event channel synchronously', () {
      var unsubscribed = false;

      final chan = EventChannel((emitter) {
        return () => unsubscribed = true;
      });

      chan.close(); // eventChannel should call unsubscribe when channel is closed

      expect(unsubscribed, equals(true));
    });

    test('Unsubscribe event channel asynchronously', () {
      var unsubscribed = false;
      final chan = EventChannel((emitter) {
        Future.delayed(Duration(seconds: 0), () => emitter(End));
        return () => unsubscribed = true;
      });

      final messageCompleter = Completer<dynamic>();

      chan.take(TakeCallback<dynamic>((dynamic message) {
        messageCompleter.complete(message);
      }));

      // should emit END event
      expect(messageCompleter.future, completion(End));
      expect(messageCompleter.future.then((dynamic value) => unsubscribed),
          completion(true));
    });

    test('Expanding buffer', () {
      final chan = BasicChannel(buffer: Buffers.expanding<dynamic>(2));
      chan.put('action-1');
      chan.put('action-2');
      chan.put('action-3');

      var actual = 0;

      chan.flush(TakeCallback<List>((items) => actual = items!.length));
      // expanding buffer should be able to buffer more items than its initial limit
      expect(actual, 3);
    });
  });
}

class _spyBuffer extends Buffer<dynamic> {
  List buffer = <dynamic>[];

  @override
  List flush() {
    final list = <dynamic>[...buffer];
    buffer.clear();
    return list;
  }

  @override
  bool get isEmpty => buffer.isEmpty;

  @override
  void put(dynamic message) {
    buffer.add(message);
  }

  @override
  dynamic take() {
    return buffer.removeAt(0);
  }
}
