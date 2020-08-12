part of redux_saga;

///  Creates an Effect description that instructs the middleware to wait for a specified
///  action on the Store or if provided on the [channel].
///  The Generator is suspended until an action that matches [pattern] is dispatched.
///
///  The result of `yield Take(pattern : pattern)` is an action object being dispatched.
///
///  [pattern] is interpreted using the following rules:
///
///  - If `Take` is called without pattern argument or `'*'` all dispatched actions are
///  matched (e.g. `Take()` will match all actions).
///
///  - If it is a function, the action is matched if `pattern(action)` is true.
///
///  - If it is a Type, the action is matched through its type.
///  The logic is `action.runtimeType === pattern` (e.g. `Take(pattern: IncrementAsync)`.
///  Type matcher may be enough to solve most scenarios. It is also type safe and easy to use.
///
///  - If it is a String, the action is matched if its type name as string equals the String.
///  The logic is `action.runtimeType.toString() === pattern` (e.g. `Take(pattern: 'IncrementAsync')`.
///
///  - If it is an array, each item in the array is accepted as pattern and all must match,
///  so the mixed array of types, strings and function predicates is supported.
///  The most common use case is an array of types though, so that action type is matched against
///  all items in the array (e.g. `Take(pattern: [Increment, Decrement])` and that would match either
///  actions of type `Increment` or `Decrement`).
///
///  The middleware provides a special action [End]. If you dispatch the [End] action, then all
///  Sagas blocked on a Take Effect will be terminated regardless of the specified pattern.
///  If the terminated Saga has still some forked tasks which are still running, it will wait
///  for all the child tasks to terminate before terminating the [Task].
///
class Take extends EffectWithResult {
  /// Instructs the middleware to wait for a specified message from the provided Channel.
  /// If the channel is already closed, then the Generator will immediately terminate
  /// following the same process described for `Take`.
  ///
  /// If [maybe] is true, it does not automatically terminate the Saga on an [End] action.
  /// Instead all Sagas blocked on a Take Effect will get the [End] object. Check [TakeMaybe] also.
  final Channel channel;

  /// Actions only matching pattern is taken.
  final dynamic pattern;

  /// If true `Take` does not automatically terminate the Saga on an [End] action.
  /// Instead all Sagas blocked on a take Effect will get the [End] object. Check [TakeMaybe] also.
  final bool maybe;

  /// Creates an instance of a Take effect.
  Take({this.pattern, this.channel, this.maybe = false, Result result}) : super(result: result);

  @override
  void _run(_SagaMiddleware middleware, _TaskCallback cb, _ExecutingContext executingContext) {
    var takeCb = TakeCallback<dynamic>((dynamic input) {
      if (input is Exception) {
        cb.next(arg: input, isErr: true);
        return;
      }
      if (isEnd(input) && (!maybe)) {
        cb.next(arg: Terminate);
        return;
      }
      cb.next(arg: input);
    });

    var _channel = channel ?? middleware.channel;

    try {
      _channel.take(
          takeCb, pattern == null ? _wilcardMatcher<dynamic>() : _matcher<dynamic>(pattern));
    } catch (e) {
      cb.next(arg: e, isErr: true);
      return;
    }
    cb.cancelHandler = () {
      takeCb.cancel();
    };
  }

  @override
  Map<String, dynamic> getDefinition() {
    var kv = <String, dynamic>{};
    kv['type'] = 'Take';
    kv['channel'] = channel;
    kv['pattern'] = pattern;
    kv['maybe'] = maybe;
    kv['result'] = result;
    return kv;
  }
}
