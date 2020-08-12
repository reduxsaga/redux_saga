part of redux_saga;

/// Same as [Take] but does not automatically terminate the Saga on an [End] action.
/// Instead all Sagas blocked on a take Effect will get the [End] object.
///
/// It is exactly same as [Take] effect with [Take.maybe] is true.
///
///  ### Notes
///
///  `TakeMaybe` is like instead of having a return type of `Action` (with automatic handling)
///  we can have a type of `Maybe(Action)` so we can handle both cases:
///
///  - case when there is a `Just(Action)` (we have an action)
///  - the case of `Nothing` (channel was closed). i.e. we need some way to map over [End].
///
///  * internally all `dispatch`ed actions are going through the `stdChannel` which is getting
///  closed when `dispatch(End)` happens.
///
class TakeMaybe extends Take {
  /// Creates an instance of a TakeMaybe effect.
  TakeMaybe({dynamic pattern, Channel channel, Result result})
      : super(pattern: pattern, channel: channel, maybe: true, result: result);

  @override
  Map<String, dynamic> getDefinition() {
    var kv = super.getDefinition();
    kv['type'] = 'TakeMaybe';
    return kv;
  }
}
