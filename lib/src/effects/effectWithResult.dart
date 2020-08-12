part of redux_saga;

/// Base class for effects returning a value.
abstract class EffectWithResult extends Effect {
  /// Result after effect is resolved.
  Result result;

  /// Defines constructor for an effect with a [result] object.
  EffectWithResult({this.result});

  @override
  void _setResult(_Task task, dynamic value, bool isErr) {
    if (result != null) {
      result.value = value;
    }
  }
}
