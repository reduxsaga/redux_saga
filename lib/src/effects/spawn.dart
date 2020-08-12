part of redux_saga;

///  Same as [Fork] but creates a *detached* task. A detached task remains independent from its
///  parent and acts like a top-level task. The parent will not wait for detached tasks to
///  terminate before returning and all events which may affect the parent or the detached task are
///  completely independents (error, cancellation).
class Spawn extends Fork {
  /// Creates an instance of a Spawn effect.
  Spawn(Function fn,
      {List<dynamic> args,
      Map<Symbol, dynamic> namedArgs,
      Function Catch,
      Function Finally,
      String name,
      Result result})
      : super(fn,
            args: args,
            namedArgs: namedArgs,
            Catch: Catch,
            Finally: Finally,
            name: name,
            detached: true,
            result: result);

  @override
  Map<String, dynamic> getDefinition() {
    var kv = super.getDefinition();
    kv['type'] = 'Spawn';
    return kv;
  }
}
