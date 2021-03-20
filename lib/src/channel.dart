part of redux_saga;

/// A channel is an object used to send and receive messages between tasks.
/// Messages from senders are queued until an interested receiver request a
/// message, and registered receiver is queued until a message is available.
///
/// Every channel has an underlying buffer which defines the buffering strategy
/// ([Buffers.fixed], [Buffers.dropping] and [Buffers.sliding])
abstract class Channel<T> {
  /// Used to register a taker. The take is resolved using the following rules
  ///
  /// - If the channel has buffered messages, then [callback] will be invoked
  ///   with the next message from the underlying buffer (using [Buffer.take])
  /// - If the channel is closed and there are no buffered messages, then
  ///   [callback] is invoked with [End]
  /// - Otherwise [callback] will be queued until a message is put into the
  ///   channel
  /// - If an optional pattern is provided then take will be processed
  ///   only if the message matches the [matcher].
  void take(TakeCallback<T> callback, [PatternMatcher<T> matcher]);

  /// Used to put [message] on the buffer. The put will be handled using the
  /// following rules
  ///
  /// - If the channel is closed, then the put will have no effect.
  /// - If there are pending takers, then invoke the oldest taker with the
  ///   [message].
  /// - Otherwise put the [message] on the underlying buffer
  void put(T message);

  /// Used to extract all buffered messages from the channel. The flush is
  /// resolved using the following rules
  ///
  /// - If the channel is closed and there are no buffered messages, then
  ///   [callback] is invoked with [End]
  /// - Otherwise [callback] is invoked with all buffered messages.
  void flush(TakeCallback<List<T>> callback);

  /// Closes the channel which means no more puts will be allowed. All pending
  /// takers will be invoked with [End].
  void close();

  /// Invoked before closing the channel. Then all the awating takers will be invoked with [End]
  Callback? onClose;
}

/// Invoked after a successfull taken [message]
typedef DataCallback<T> = void Function(T? message);

typedef _CancelCallback = void Function();

/// A callback class containing callback functions to handle [Channel.take]
class TakeCallback<T> {
  /// Channel will invoke on a successfull take with action
  /// or on a channel close with [End]
  final DataCallback<T> onData;
  _CancelCallback? _cancel;
  PatternMatcher<T>? _matcher;

  /// Creates an instance of a [TakeCallback] class
  ///
  /// Channel will invoke [onData] on a possible take
  TakeCallback(this.onData);

  void _onData(T? message) {
    onData(message);
  }

  bool _cancelled = false;

  /// Used to cancel this awaiting take callback
  void cancel() {
    if (!_cancelled) {
      _cancelled = true;
      if (_cancel != null) _cancel!();
    }
  }

  bool _matched(T message) {
    return _matcher != null && _matcher!(message);
  }
}

class _Channel<T> implements Channel<T> {
  late Buffer<T> _buffer;

  bool _closed = false;
  final List<TakeCallback<T>> _takers = <TakeCallback<T>>[];

  _Channel({Buffer<T>? buffer}) {
    _buffer = buffer ?? Buffers.expanding();
  }

  bool get _hasTakers => _takers.isNotEmpty;

  void _checkForbiddenStates() {
    if (_closed && _hasTakers) {
      throw ClosedChannelWithTakers();
    }
    if (_hasTakers && (!_buffer.isEmpty)) {
      throw PendingTakersWithNotEmptyBuffer();
    }
  }

  @override
  Callback? onClose;

  @override
  void close() {
    if (_isDebugMode) {
      _checkForbiddenStates();
    }

    if (_closed) {
      return;
    }

    _closed = true;

    if (onClose != null) onClose!();

    var arr = <TakeCallback<T>>[];
    arr.addAll(_takers);
    _takers.clear();

    arr.forEach((taker) => taker._onData(End as T));
  }

  @override
  void take(TakeCallback<T> callback, [PatternMatcher<T>? matcher]) {
    if (_isDebugMode) {
      _checkForbiddenStates();
    }

    if (_closed && _buffer.isEmpty) {
      callback._onData(End as T);
    } else if (!_buffer.isEmpty) {
      callback._onData(_buffer.take());
    } else {
      _takers.add(callback);
      callback._cancel = () => _takers.remove(callback);
    }
  }

  @override
  void put(message) {
    if (_isDebugMode) {
      _checkForbiddenStates();
      if (message == null) {
        throw NullInputError();
      }
    }

    if (_closed) {
      return;
    }

    if (_takers.isEmpty) {
      return _buffer.put(message);
    }

    var takeCallback = _takers.removeAt(0);
    takeCallback._onData(message);
  }

  @override
  void flush(TakeCallback<List<T?>> callback) {
    if (_isDebugMode) {
      _checkForbiddenStates();
    }

    if (_closed && _buffer.isEmpty) {
      callback._onData([End as T]);
      return;
    }
    callback._onData(_buffer.flush());
  }
}

/// A basic channel implementation.
///
/// By default, if no buffer is provided, the channel will queue incoming
/// messages up to 10 until interested takers are registered. The default
/// buffering will deliver message using a FIFO strategy: a new taker will be
/// delivered the oldest message in the buffer.
class BasicChannel extends _Channel<dynamic> {
  /// Creates an instance of a BasicChannel. You can optionally pass
  /// it a [buffer] to control how the channel buffers the messages.
  BasicChannel({Buffer? buffer}) : super(buffer: buffer);
}

/// Handler for emitting value to [EventChannel]
typedef Emit<T> = void Function(T message);

/// Handler for subscribe to [EventChannel]. It must return an [Unsubscribe]
/// handler to unsubscribe channel.
typedef Subscribe<T> = Unsubscribe Function(Emit<T> emitter);

/// Handler for unsubscribe from [EventChannel]
typedef Unsubscribe = void Function();

class _EventChannel<T> implements Channel<T> {
  late Unsubscribe _unsubscriber;
  bool _closed = false;

  late _Channel<T> _channel;

  _EventChannel(Subscribe<T> subscribe, {Buffer<T>? buffer}) {
    _channel = _Channel(buffer: buffer ?? Buffers.none<T>());
    _unsubscriber = subscribe((T message) {
      if (isEnd(message)) {
        close();
        return;
      }
      _channel.put(message);
    });

    if (_closed) {
      _unsubscribe();
    }
  }

  @override
  Callback? onClose;

  @override
  void close() {
    if (_closed) {
      return;
    }

    _closed = true;

    if (onClose != null) onClose!();

    _unsubscribe();
    _channel.close();
  }

  bool _unsubscribed = false;

  void _unsubscribe() {
    if (!_unsubscribed) {
      _unsubscribed = true;
      _unsubscriber();
    }
  }

  @override
  void flush(TakeCallback<List<T>> callback) {
    _channel.flush(callback);
  }

  @override
  void put(T message) {
    throw InvalidOperation();
  }

  @override
  void take(TakeCallback<T> callback, [PatternMatcher<T>? matcher]) {
    _channel.take(callback);
  }
}

/// Creates channel that will subscribe to an event source using the `subscribe`
/// method. Incoming events from the event source will be queued in the channel
/// until interested takers are registered.
///
/// To notify the channel that the event source has terminated, you can notify
/// the provided subscriber with an [End]
///
/// ### Example
///
///
/// In the following example we create an event channel that will
/// subscribe to a `Timer.periodic`
///
///```
///  EventChannel countdown(int secs) {
///    return EventChannel(subscribe: (emitter) {
///      var v = secs;
///      var timer = Timer.periodic(Duration(seconds: 1), (timer) {
///        v--;
///        if (v > 0) {
///          emitter(v);
///        } else {
///          emitter(End);
///        } // this causes the channel to close
///      });
///
///      // The subscriber must return an unsubscribe function
///      return () => timer.cancel();
///    });
///  }
///
///  saga() sync* {
///    var value = 10;
///    var channel = Result<EventChannel>();
///
///    yield Call(countdown, args: [value], result: channel);
///
///    yield Try(() sync* {
///      while (true) {
///        // Take(pattern:End) will cause the saga to terminate
///        // by jumping to the finally block
///        var seconds = Result();
///        yield Take(channel: channel.value, result: seconds);
///        print('countdown: ${seconds.value}');
///      }
///    }, Finally: () sync* {
///      print('countdown terminated');
///    });
///  }
///```
///
///  ### Output
///
///
///```
///  countdown: 9
///  countdown: 8
///  countdown: 7
///  countdown: 6
///  countdown: 5
///  countdown: 4
///  countdown: 3
///  countdown: 2
///  countdown: 1
///  countdown terminated
///```
///
class EventChannel extends _EventChannel<dynamic> {
  /// Creates an instance of an `EventChannel`
  ///
  /// [subscribe] is used to subscribe to the underlying event source. The
  ///   function must return an unsubscribe function to terminate the subscription.
  /// [buffer] is an optional Buffer object to buffer messages on this channel. If
  ///   not provided, messages will not be buffered on this channel.
  EventChannel(Subscribe subscribe, {Buffer? buffer})
      : super(subscribe, buffer: buffer);
}

class _MultiCastChannel<T> implements Channel<T> {
  bool _closed = false;
  List<TakeCallback<T>> _currentTakers = <TakeCallback<T>>[];

  late List<TakeCallback<T>> _nextTakers;

  _MultiCastChannel() {
    _nextTakers = _currentTakers;
  }

  void _checkForbiddenStates() {
    if (_closed && _nextTakers.isNotEmpty) {
      throw ClosedChannelWithTakers();
    }
  }

  void _ensureCanMutateNextTakers() {
    if (_nextTakers != _currentTakers) {
      return;
    }
    _nextTakers = [];
    _nextTakers.addAll(_currentTakers);
  }

  @override
  Callback? onClose;

  @override
  void close() {
    if (_isDebugMode) {
      _checkForbiddenStates();
    }

    if (_closed) {
      return;
    }

    _closed = true;

    if (onClose != null) onClose!();

    var takers = (_currentTakers = _nextTakers);

    _nextTakers = [];

    takers.forEach((taker) {
      taker._onData(End as T);
    });
  }

  @override
  void flush(TakeCallback<List<T>> callback) {
    throw InvalidOperation();
  }

  @override
  void put(T message) {
    if (_isDebugMode) {
      _checkForbiddenStates();
      if (message == null) {
        throw NullInputError();
      }
    }

    if (_closed) {
      return;
    }

    if (isEnd(message)) {
      close();
      return;
    }

    var takers = (_currentTakers = _nextTakers);

    for (var i = 0, len = takers.length; i < len; i++) {
      var taker = takers[i];

      if (taker._matched(message)) {
        taker.cancel();
        taker._onData(message);
      }
    }
  }

  @override
  void take(TakeCallback<T> callback, [PatternMatcher<T>? matcher]) {
    if (_isDebugMode) {
      _checkForbiddenStates();
    }

    if (_closed) {
      callback._onData(End as T);
      return;
    }

    callback._matcher = matcher;
    _ensureCanMutateNextTakers();
    _nextTakers.add(callback);

    callback._cancel = () {
      _ensureCanMutateNextTakers();
      _nextTakers.remove(callback);
    };
  }
}

/// A channel type for handling actions/events in most cases.
/// There may be more than one takers awaiting the channel.
/// It does not buffer messages if there is no takers awaiting.
/// Any message without any takers will be lost.
class MultiCastChannel extends _MultiCastChannel<dynamic> {}

class _StdChannel<T> extends _MultiCastChannel<T> {
  @override
  void put(T message) {
    if (isSagaDispatchedAction(message)) {
      super.put(message);
      return;
    }
    asap(() {
      super.put(message);
    });
  }
}

/// Default channel type that middleware using to handle messages.
/// It has the same behaviour like [MultiCastChannel].
/// In most cases this class can be used to handle messages.
class StdChannel extends _StdChannel<dynamic> {}
