part of redux_saga;

///  Returns an effect descriptor to block execution for [duration] and return [value].
class Delay extends EffectWithResult {
  /// Duration to delay
  final Duration duration;

  /// Value to return after delay
  final dynamic value;

  /// Creates an instance of a Delay effect.
  Delay(this.duration, {this.value, Result result}) : super(result: result);

  @override
  void _run(_SagaMiddleware middleware, _TaskCallback cb,
      _ExecutingContext executingContext) {
    var completer = Completer<dynamic>();
    var timer = Timer(duration, () {
      completer.complete(value ?? true);
    });
    _resolveFutureWithCancel(
        FutureWithCancel(completer.future, () {
          timer.cancel();
        }),
        cb);
  }

  @override
  Map<String, dynamic> getDefinition() {
    var kv = <String, dynamic>{};
    kv['type'] = 'Delay';
    kv['duration'] = duration;
    kv['value'] = value;
    kv['result'] = result;
    return kv;
  }
}
