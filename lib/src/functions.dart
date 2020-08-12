part of redux_saga;

///Returns true for the following closures
///() => void
///() => Null
bool _isFunctionVoid(Function f) {
  if (f == null) throw CannotDetermineNullFunctionReturnType();
  var closure = f.toString();
  return closure.contains(') => void') ||
      closure.contains(') => Null') ||
      closure.contains(') => Future<void>') ||
      closure.contains(') => Future<Null>');
}

bool _functionHasNamedArgument(Function f, String type, String name) {
  if (f == null) throw CannotDetermineNullFunctionArguments();
  var closure = f.toString();
  return closure.contains('{$type $name}');
}

bool _functionHasActionArgument(Function f) {
  return _functionHasNamedArgument(f, 'dynamic', 'action');
}

dynamic _callFunctionWithArgument(Function f, List<dynamic> args,
    Map<Symbol, dynamic> namedArgs, dynamic firstArg) {
  return Function.apply(f, <dynamic>[firstArg, ...?args], namedArgs);
}

dynamic _callFunction(
    Function f, List<dynamic> args, Map<Symbol, dynamic> namedArgs) {
  return Function.apply(f, args, namedArgs);
}

dynamic _callFinallyFunction(Function f) {
  return Function.apply(f, null);
}

///possible closures :
///(Exception) => void
///(Exception, StackTrace) => void
dynamic _callErrorFunction(Function f, _SagaInternalException error) {
//  _checkFunction(f);
  var closure = f.toString();
  final args = <dynamic>[];
  if (closure.contains('(dynamic)')) {
    args.add(error.message);
  } else if (closure.contains('(dynamic, StackTrace)')) {
    args.add(error.message);
    args.add(error.stackTrace);
  }
  return Function.apply(f, args, null);
}
