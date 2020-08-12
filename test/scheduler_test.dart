import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';

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

    test('scheduler when suspended queues up and executes all tasks on flush', () {
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
        return;
      });
      expect(actual, equals(['1', '2', '3']));
    });
  });
}
