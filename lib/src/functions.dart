part of redux_saga;

dynamic _callFunctionWithArgument(Function f, List<dynamic>? args,
    Map<Symbol, dynamic>? namedArgs, dynamic firstArg) {
  return Function.apply(f, <dynamic>[firstArg, ...?args], namedArgs);
}

dynamic _callFunction(
    Function f, List<dynamic>? args, Map<Symbol, dynamic>? namedArgs) {
  return Function.apply(f, args, namedArgs);
}

dynamic _callFinallyFunction(Function f) {
  return Function.apply(f, null);
}

dynamic _callErrorFunction(Function f, _SagaInternalException error) {
  return Function.apply(f, <dynamic>[error.message, error.stackTrace], null);
}
