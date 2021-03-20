part of redux_saga;

///  Creates an effect that instructs the middleware to flush all buffered items from the [channel].
///  Flushed items are returned back to the saga, so they can be utilized if needed.
///
///  #### Example
///
///```
///  import 'package:redux_saga/redux_saga.dart';
///
///  //...
///
///  saga() sync* {
///    var chan = Result<Channel>();
///    yield ActionChannel(Action, result: chan);
///
///    yield Try(() sync* {
///      while (true) {
///        var action = Result();
///        yield Take(channel: chan.value, result: action);
///        // ...
///      }
///    }, Finally: () sync* {
///      var actions = Result();
///      yield FlushChannel(chan.value, result: actions);
///      // ...
///    });
///  }
///```
///
class FlushChannel extends EffectWithResult {
  /// Channel to flush.
  final Channel channel;

  /// Creates an instance of FlushChannel effect.
  FlushChannel(this.channel, {Result? result}) : super(result: result);

  @override
  void _run(_SagaMiddleware middleware, _TaskCallback cb,
      _ExecutingContext executingContext) {
    channel.flush(TakeCallback<List<dynamic>>((dynamic input) {
      cb.next(arg: input);
    }));
  }

  @override
  Map<String, dynamic> getDefinition() {
    var kv = <String, dynamic>{};
    kv['type'] = 'FlushChannel';
    kv['channel'] = channel;
    kv['result'] = result;
    return kv;
  }
}
