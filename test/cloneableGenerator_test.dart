import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';

void main() {
  group('clonable generator tests', () {
    test('test', () {
      Iterable<int> testGen(int base) sync* {
        yield base;
        yield base + 1;
        yield base + 2;
        yield base + 3;
        yield base + 4;
      }

      var gen = CloneableGenerator(testGen, args: <dynamic>[0]);

      var values = <dynamic>[];

      CloneableGenerator gen1, gen2;

      while (gen.moveNext()) {
        values.add(gen.current);

        if (gen.current == 2) {
          gen1 = gen.clone();
        } else if (gen.current == 3) {
          gen2 = gen.clone();
        }
      }

      while (gen1.moveNext()) {
        values.add(gen1.current);
      }

      while (gen2.moveNext()) {
        values.add(gen2.current);
      }

      expect(values, <int>[0, 1, 2, 3, 4, 3, 4, 4]);
    });
  });
}
