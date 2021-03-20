part of redux_saga;

/// Same as [Put] effect. Only [resolve] is true by default.
class PutResolve extends Put {
  /// Creates an instance of a PutResolve effect.
  PutResolve(dynamic action, {Channel? channel, Result? result})
      : super(action, channel: channel, resolve: true, result: result);

  @override
  Map<String, dynamic> getDefinition() {
    var kv = super.getDefinition();
    kv['type'] = 'PutResolve';
    return kv;
  }
}
