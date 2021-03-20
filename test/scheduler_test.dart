import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';

class _TestTask extends Task<dynamic> {
  @override
  void cancel() {
  }

  @override
  dynamic get error => throw UnimplementedError();

  @override
  bool get isAborted => throw UnimplementedError();

  @override
  bool get isCancelled => throw UnimplementedError();

  @override
  bool get isRunning => throw UnimplementedError();

  @override
  dynamic get result => throw UnimplementedError();

  @override
  void setContext(Map<String, dynamic> context) {
  }

  @override
  Future toFuture() {
    throw UnimplementedError();
  }
}


void main() {
  group('Scheduler tests', () {
    test('scheduler executes all recursively triggered tasks in order', () {
      final actual = <String>[];
      asap(() {
        actual.add('1');
        asap(() {
          actual.add('2');
        });
        asap(() {
          actual.add('3');
        });
      });
      expect(actual, equals(['1', '2', '3']));
    });


    test('scheduler when suspended queues up and executes all tasks on flush',
        () {
      final actual = <String>[];
      immediately(() {
        asap(() {
          actual.add('1');
          asap(() {
            actual.add('2');
          });
          asap(() {
            actual.add('3');
          });
        });
        return _TestTask();
      });
      expect(actual, equals(['1', '2', '3']));
    });
  });
}
