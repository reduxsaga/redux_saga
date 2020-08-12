part of redux_saga;

/// Takes a generator function (sync*) and returns a generator function.
/// All generators instantiated from this function will be cloneable. For testing purpose only.
///
///  ### Example
///
///  This is useful when you want to test a different branch of a saga without having
///  to replay the actions that lead to it.
///
///```
///  Iterable<int> testGen(int base) sync* {
///    yield base;
///    yield base + 1;
///    yield base + 2;
///    yield base + 3;
///    yield base + 4;
///  }
///
///  var gen = CloneableGenerator<int>(testGen, args: <dynamic>[0]);
///
///  gen.moveNext();   //gen.current is 0
///  gen.moveNext();   //gen.current is 1
///
///  CloneableGenerator<int> genCloned = gen.clone();
///
///  gen.moveNext(); //gen.current is 2
///  genCloned.moveNext(); //genCloned.current is 2
///```
///
class CloneableGenerator<T> implements Iterator<T> {
  /// A Generator function to call and clone
  final Function fn;

  /// Arguments of the generator function to call
  final List<dynamic> args;

  /// Named arguments of the generator function to call
  final Map<Symbol, dynamic> namedArgs;

  /// Creates an instance of a CloneableGenerator
  CloneableGenerator(this.fn, {this.args, this.namedArgs});

  @override
  T get current => _iterator?.current;

  bool _started = false;
  Iterator<T> _iterator;
  int _currentStep = 0;

  @override
  bool moveNext() {
    if (!_started) {
      var result = _callFunction(fn, args, namedArgs) as Iterable<T>;
      if (result is Iterable) {
        _iterator = result.iterator;
      } else {
        throw GeneratorFunctionExpectedException();
      }
      _started = true;
    }

    _currentStep++;
    return _iterator.moveNext();
  }

  /// Clones the generator and both generator can resume from the same step.
  CloneableGenerator<T> clone() {
    var clonedGenerator =
        CloneableGenerator<T>(fn, args: args, namedArgs: namedArgs);
    for (var i = 0; i < _currentStep; i++) {
      clonedGenerator.moveNext();
    }
    return clonedGenerator;
  }
}
