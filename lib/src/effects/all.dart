part of redux_saga;

///  Creates an Effect description that instructs the middleware to run multiple Effects
///  in parallel and wait for all of them to complete.
///
///  #### Example
///
///  The following example runs two blocking calls in parallel:
///
///```
///  import 'package:redux_saga/redux_saga.dart';
///  import 'fetchApi.dart';
///
///  //...
///
///  mySaga() sync* {
///    var result = AllResult();
///    yield All(
///      {
///        #customers: Call(fetchCustomers),
///        #products: Call(fetchProducts),
///      },
///      result: result,
///    );
///  }
///```
///
///  ### Notes
///
///  When running Effects in parallel, the middleware suspends the Generator until one of the following occurs:
///
///  - All the Effects completed with success: resumes the Generator with an array containing the results of all Effects.
///
///  - One of the Effects was rejected before all the effects complete: throws the rejection error inside the Generator.
///
class All extends EffectWithResult {
  /// Dictionary of all effect to run in parallel.
  final Map<dynamic, dynamic> effects;

  /// Creates an instance of a All effect.
  All(this.effects, {AllResult? result}) : super(result: result);

  @override
  void _run(_SagaMiddleware middleware, _TaskCallback cb,
      _ExecutingContext executingContext) {
    if (effects.isEmpty) {
      cb.next(arg: <dynamic, dynamic>{});
      return;
    }

    var effectId = middleware.uniqueId.currentEffectId();

    var childCallbacks = _createAllStyleChildCallbacks(effects, cb);
    for (var key in effects.keys) {
      executingContext.digestEffect(
          effects[key], effectId, childCallbacks[key]!, key);
    }
  }

  @override
  Map<String, dynamic> getDefinition() {
    var kv = <String, dynamic>{};
    kv['type'] = 'All';
    kv['effects'] = effects;
    return kv;
  }
}

/// Result of an [All] effect
///
/// Its value is a dictionary containing entries for every effects result.
class AllResult extends Result<Map<dynamic, dynamic>> {}
