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
///  var gen = CloneableGenerator(testGen, args: <dynamic>[0]);
///
///  gen.moveNext();   //gen.current is 0
///  gen.moveNext();   //gen.current is 1
///
///  CloneableGenerator genCloned = gen.clone();
///
///  gen.moveNext(); //gen.current is 2
///  genCloned.moveNext(); //genCloned.current is 2
///```
///
class CloneableGenerator implements Iterator<dynamic> {
  /// A Generator function to call and clone
  final Function fn;

  /// Arguments of the generator function to call
  final List<dynamic> args;

  /// Named arguments of the generator function to call
  final Map<Symbol, dynamic> namedArgs;

  /// Creates an instance of a CloneableGenerator
  CloneableGenerator(this.fn, {this.args, this.namedArgs});

  @override
  dynamic get current => _iterator?.current;

  bool _started = false;
  Iterator _iterator;
  int _currentStep = -1;

  final _effectResults = <int, dynamic>{};

  @override
  bool moveNext() {
    if (!_started) {
      var result = _callFunction(fn, args, namedArgs) as Iterable;
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
  CloneableGenerator clone() {
    var clonedGenerator =
        CloneableGenerator(fn, args: args, namedArgs: namedArgs);
    for (var i = 0; i <= _currentStep; i++) {
      clonedGenerator.moveNext();
      if (_effectResults.containsKey(i)) {
        clonedGenerator.setResult(_effectResults[i]);
      }
    }
    return clonedGenerator;
  }

  /// Sets current effect result
  ///
  /// Effect must have a result argument. [current] effect result value will be set as [value].
  void setResult(dynamic value) {
    if (current == null) {
      throw Exception('Effect can not be null');
    } else if (!(current is EffectWithResult)) {
      throw Exception('Effect can not return a value');
    } else if (current.result == null) {
      throw Exception('Effect has no result argument assigned');
    }

    _effectResults[_currentStep] = value;
    current.result.value = value;
  }
}
