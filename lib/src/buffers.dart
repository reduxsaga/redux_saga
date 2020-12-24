part of redux_saga;

/// Used to implement the buffering strategy for a channel.
abstract class Buffer<T> {
  /// Returns true if there are no messages on the buffer. A channel calls this
  /// method whenever a new taker is registered.
  bool get isEmpty;

  /// Used to put new message in the buffer. Note the Buffer can choose to not
  /// store the message (e.g. a dropping buffer can drop any new message
  /// exceeding a given limit).
  void put(T message);

  /// Used to retrieve any buffered message. Note the behavior of this method has
  /// to be consistent with [isEmpty].
  T take();

  /// Flushes all the messages in the buffer to a `List`.
  List<T> flush();
}

class _ZeroBuffer<T> implements Buffer<T> {
  @override
  List<T> flush() {
    return <T>[];
  }

  @override
  bool get isEmpty => true;

  @override
  void put(T message) {
    //Do nothing here. It is zero buffer
  }

  @override
  T take() {
    throw BufferisEmpty();
  }
}

enum _overflowActions { Throw, Drop, Slide, Expand }

class _RingBuffer<T> implements Buffer<T> {
  int _limit;
  _overflowActions _overflowAction;

  List<T> _arr;
  int _length = 0;
  int _pushIndex = 0;
  int _popIndex = 0;

  _RingBuffer(int limit, _overflowActions overflowAction) {
    _limit = limit;
    _overflowAction = overflowAction;
    _arr = List<T>.filled(_limit, null, growable: true);
  }

  void _push(T it) {
    _arr[_pushIndex] = it;
    _pushIndex = (_pushIndex + 1) % _limit;
    _length++;
  }

  @override
  T take() {
    if (_length == 0) {
      throw BufferisEmpty();
    } else {
      var it = _arr[_popIndex];
      _arr[_popIndex] = null;
      _length--;
      _popIndex = (_popIndex + 1) % _limit;
      return it;
    }
  }

  @override
  List<T> flush() {
    var items = <T>[];
    while (_length > 0) {
      items.add(take());
    }
    return items;
  }

  @override
  bool get isEmpty => _length == 0;

  @override
  void put(T message) {
    if (_length < _limit) {
      _push(message);
    } else {
      switch (_overflowAction) {
        case _overflowActions.Throw:
          throw BufferOverflow();
        case _overflowActions.Slide:
          _arr[_pushIndex] = message;
          _pushIndex = (_pushIndex + 1) % _limit;
          _popIndex = _pushIndex;
          break;
        case _overflowActions.Expand:
          var doubledLimit = 2 * _limit;

          _arr = flush();

          _length = _arr.length;
          _pushIndex = _arr.length;
          _popIndex = 0;

          _arr.length = doubledLimit;
          _limit = doubledLimit;

          _push(message);
          break;
        default:
        // DROP
      }
    }
  }

  @override
  String toString() {
    var s = '$_length [';
    _arr.forEach((element) {
      s += '$element,';
    });
    s += ']';
    return s;
  }
}

class _FixedBuffer<T> extends _RingBuffer<T> {
  _FixedBuffer(int limit) : super(limit, _overflowActions.Throw);
}

class _DroppingBuffer<T> extends _RingBuffer<T> {
  _DroppingBuffer(int limit) : super(limit, _overflowActions.Drop);
}

class _SlidingBuffer<T> extends _RingBuffer<T> {
  _SlidingBuffer(int limit) : super(limit, _overflowActions.Slide);
}

class _ExpandingBuffer<T> extends _RingBuffer<T> {
  _ExpandingBuffer(int initialSize)
      : super(initialSize, _overflowActions.Expand);
}

/// Provides some common buffers.
abstract class Buffers {
  Buffers._();

  /// No buffering, new messages will be lost if there are no pending takers.
  static Buffer<T> none<T>() {
    return _ZeroBuffer<T>();
  }

  /// New messages will be buffered up to [limit]. Overflow will raise an Error.
  /// Omitting a [limit] value will result in a limit of 10.
  static Buffer<T> fixed<T>([int limit = 10]) {
    return _FixedBuffer<T>(limit);
  }

  /// Like [fixed] but Overflow will cause the buffer to expand dynamically.
  ///
  /// Buffer will be created with [initialSize] and will expand on demand.
  /// No messages are lost.
  static Buffer<T> expanding<T>([int initialSize = 10]) {
    return _ExpandingBuffer<T>(initialSize);
  }

  /// Same as [fixed] but Overflow will silently drop the messages.
  ///
  /// Omitting a [limit] value will result in a limit of 10.
  /// If buffered messages reaches [limit] then following new messages
  /// will be dropped.
  static Buffer<T> dropping<T>([int limit = 10]) {
    return _DroppingBuffer<T>(limit);
  }

  /// Same as [fixed] but Overflow will insert the new message at the end and
  /// drop the oldest message in the buffer.
  ///
  /// Omitting a [limit] value will result in a limit of 10.
  static Buffer<T> sliding<T>([int limit = 10]) {
    return _SlidingBuffer<T>(limit);
  }
}
