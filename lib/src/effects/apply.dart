part of redux_saga;

/// An alias for [Call] effect.
class Apply extends Call {
  /// Creates an instance of a Apply effect.
  Apply(Function fn,
      {List<dynamic>? args,
      Map<Symbol, dynamic>? namedArgs,
      Function? Catch,
      Function? Finally,
      String? name,
      Result? result})
      : super(fn,
            args: args,
            namedArgs: namedArgs,
            Catch: Catch,
            Finally: Finally,
            name: name,
            result: result);

  @override
  Map<String, dynamic> getDefinition() {
    var kv = super.getDefinition();
    kv['type'] = 'Apply';
    return kv;
  }
}
