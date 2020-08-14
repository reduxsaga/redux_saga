part of redux_saga;

///  Creates an Effect description that instructs the middleware to run a Race between
///  multiple Effects.
///
///  [effects] is a dictionary of the form {label: effect, ...}
///
///  ### Example
///
///  The following example runs a race between two effects:
///
///  1. A call to a function `fetchUsers` which returns a Future
///  2. A `CancelFetch` action which may be eventually dispatched on the Store
///
///```
///  import 'package:redux_saga/redux_saga.dart';
///  import 'fetchUsers.dart';
///
///  //...
///
///  fetchUsersSaga() sync* {
///    var result = RaceResult();
///    yield Race({
///      #response: Call(fetchUsers),
///      #cancel: Take(pattern: CancelFetch),
///    }, result: result);
///
///    //result.key is winner effect
///    //result.keyValue is winner effects result
///  }
///```
///
///  Race effects result is a [RaceResult] which has a dictionary value with a single entry basically.
///  Single result value can be accessed through `result.key` and `result.keyValue` easily.
///
///  If `Call(fetchUsers)` resolves (or rejects) first, the result of `Race` will be an object
///  with a single keyed object `{response: result}` where `result` is the resolved result of `fetchUsers`.
///
///  If an action of type `CancelFetch` is dispatched on the Store before `fetchUsers` completes, the result
///  will be a single keyed object `{cancel: action}`, where action is the dispatched action.
///
///  ### Notes
///
///  When resolving a `Race`, the middleware automatically cancels all the losing Effects.
///
class Race extends EffectWithResult {
  /// Effects to Race
  final Map<dynamic, dynamic> effects;

  /// Creates an instance of a Race effect.
  Race(this.effects, {RaceResult result}) : super(result: result);

  @override
  void _run(_SagaMiddleware middleware, _TaskCallback cb,
      _ExecutingContext executingContext) {
    var effectId = middleware.uniqueId.currentEffectId();

    var keys = effects.keys;
    var childCallbacks = <dynamic, _TaskCallback>{};
    var completed = false;

    for (var key in keys) {
      var chCbAtKey = _TaskCallback(
        ({_TaskCallback invoker, dynamic arg, bool isErr}) {
          if (completed) {
            return;
          }
          if (isErr || _shouldComplete(arg)) {
            // Race Auto cancellation
            cb.cancel();
            cb.next(arg: arg, isErr: isErr);
          } else {
            cb.cancel();
            completed = true;
            cb.next(arg: <dynamic, dynamic>{key: arg});
          }
        },
        _noop,
      );
      childCallbacks[key] = chCbAtKey;
    }

    cb.cancelHandler = () {
      // prevents unnecessary cancellation
      if (!completed) {
        completed = true;
        for (var key in keys) {
          childCallbacks[key].cancel();
        }
      }
    };

    for (var key in keys) {
      if (completed) {
        return;
      }
      executingContext.digestEffect(
          effects[key], effectId, childCallbacks[key], key);
    }
  }

  @override
  Map<String, dynamic> getDefinition() {
    var kv = <String, dynamic>{};
    kv['type'] = 'Race';
    kv['effects'] = effects;
    kv['result'] = result;
    return kv;
  }
}

/// Result of a [Race] Effect
///
/// Result is map with a single entry
class RaceResult extends Result<Map<dynamic, dynamic>> {
  /// Key of the single entry in the map
  dynamic get key => value.keys.first;

  /// Key value of the single entry in the map
  dynamic get keyValue => value[key];
}
