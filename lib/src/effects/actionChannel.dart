part of redux_saga;

///  Creates an effect that instructs the middleware to queue the actions matching
///  [pattern] using an event channel. Optionally, you can provide a [buffer] to
///  control buffering of the queued actions.
///
///  Check [Take] effect for pattern definitions.
///
///  #### Example
///
///  The following code creates a channel to buffer all `UserRequest` actions. Note that even the Saga may be blocked
///  on the [Call] effect. All actions that come while it's blocked are automatically buffered. This causes the Saga
///  to execute the API calls one at a time
///
///  ```
///  import 'package:redux_saga/redux_saga.dart';
///  import 'api.dart';
///
///  //...
///
///  takeOneAtMost() sync* {
///    var chan = Result<Channel>();
///    yield ActionChannel(UserRequest, result: chan);
///    while (true) {
///      var action = Result();
///      yield Take(channel: chan.value, result: action);
///      yield Call(api.getUser, args: [action.value.payload]);
///    }
///  }
///  ```
class ActionChannel extends EffectWithResult {
  /// Queues actions to buffer that matching this pattern.
  final dynamic pattern;

  /// An optional buffer can be provided to channel
  final Buffer buffer;

  /// Creates an instance of an ActionChannel effect
  ActionChannel(this.pattern, {this.buffer, Result result})
      : super(result: result);

  @override
  void _run(_SagaMiddleware middleware, _TaskCallback cb,
      _ExecutingContext executingContext) {
    final chan = BasicChannel(buffer: buffer);
    final match = _matcher<dynamic>(pattern);

    TakeCallback<dynamic> Function() createTaker;

    TakeCallback<dynamic> lastTaker;

    createTaker = () {
      lastTaker = TakeCallback<dynamic>((dynamic action) {
        if (!isEnd(action)) {
          middleware.channel.take(createTaker(), match);
        }
        chan.put(action);
      });

      return lastTaker;
    };

    chan.onClose = () {
      lastTaker.cancel();
    };

    middleware.channel.take(createTaker(), match);
    cb.next(arg: chan);
  }

  @override
  Map<String, dynamic> getDefinition() {
    var kv = <String, dynamic>{};
    kv['type'] = 'ActionChannel';
    kv['pattern'] = pattern;
    kv['buffer'] = buffer;
    kv['result'] = result;
    return kv;
  }
}
