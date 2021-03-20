part of redux_saga;

/// Creates an effect that instructs the middleware to return whether this generator has
/// been cancelled. Typically you use this Effect in a finally block to run Cancellation
/// specific code.
///
/// #### Example
///
///```
///  import 'package:redux_saga/redux_saga.dart';
///
///  //...
///
///  saga() sync* {
///    yield Try(() sync* {
///      // ...
///    }, Finally: () sync* {
///      var cancelled = Result<bool>();
///      yield Cancelled(result: cancelled);
///
///      if (cancelled.value) {
///        // logic that should execute only on Cancellation
///      }
///      // logic that should execute in all situations (e.g. closing a channel)
///    });
///  }
///```
///
class Cancelled extends EffectWithResult {
  /// Creates an instance of a Cancelled effect.
  Cancelled({Result? result}) : super(result: result);

  @override
  void _run(_SagaMiddleware middleware, _TaskCallback cb,
      _ExecutingContext executingContext) {
    cb.next(arg: executingContext.task.isCancelled);
  }

  @override
  Map<String, dynamic> getDefinition() {
    var kv = <String, dynamic>{};
    kv['type'] = 'Cancelled';
    kv['result'] = result;
    return kv;
  }
}
