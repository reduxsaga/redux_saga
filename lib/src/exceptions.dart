part of redux_saga;

void _logError(dynamic e, String stack) {
  print('$e');
  print('$stack');
}

void _logErrorEmpty(dynamic e, String stack) {}

/// Thrown when a null function is passed to the
/// middlewares [SagaMiddleware.run] method
class SagaFunctionMustBeNonNullException implements Exception {
  @override
  String toString() {
    return 'Root saga can not be null';
  }
}

/// Thrown when a non-generator function is passed to the
/// middlewares [SagaMiddleware.run] method.
/// Saga must have a return type of Iterable.
class SagaFunctionMustBeGeneratorException implements Exception {
  @override
  String toString() {
    return 'Root saga must be a generator function';
  }
}

/// Thrown when the middleware tries to run a saga before
/// connected to a store via [applyMiddleware]
class SagaMustBeConnectedToTheStore implements Exception {
  @override
  String toString() {
    return 'Saga must be connected to a store';
  }
}

/// Thrown when the middleware tries to run a saga before
/// store property set via [SagaMiddleware.setStore]
class SagaStoreMustBeSet implements Exception {
  @override
  String toString() {
    return 'Saga store property must be set';
  }
}

/// Thrown when [SagaMiddleware.setStore] `store` argument
/// is passed null
class SagaStoreCanNotBeNull implements Exception {
  @override
  String toString() {
    return 'Store can not be null';
  }
}

/// Thrown when [SagaMiddleware.dispatch] property is null
/// By default it is set properly after [SagaMiddleware.setStore]
class SagaMiddlewareDispatchMustBeSet implements Exception {
  @override
  String toString() {
    return 'Saga middleware dispatch method must be set';
  }
}

/// Thrown when [SagaMiddleware.getState] property is null
/// By default it is set properly after [SagaMiddleware.setStore]
class SagaMiddlewareGetStateMustBeSet implements Exception {
  @override
  String toString() {
    return 'Saga middleware getState method must be set';
  }
}

/// Thrown when [Take] effects matcher pattern is invalid
class InvalidPattern implements Exception {
  late String _message;

  /// Creates an instance of InvalidPattern
  ///
  /// [pattern] can be used to determine invalid pattern.
  InvalidPattern(dynamic pattern) {
    _message = 'Invalid pattern "$pattern"';
  }

  @override
  String toString() {
    return _message;
  }
}

/// Thrown when there is pending takers on a closed channel
class ClosedChannelWithTakers implements Exception {
  @override
  String toString() {
    return 'Cannot have a closed channel with pending takers';
  }
}

/// Thrown when there is pending takers on a non-empty buffer
class PendingTakersWithNotEmptyBuffer implements Exception {
  @override
  String toString() {
    return 'Cannot have pending takers with non empty buffer';
  }
}

/// Thrown when a saga or channel provided with a null action
class NullInputError implements Exception {
  @override
  String toString() {
    return 'Saga or channel was provided with a null action';
  }
}

/// Thrown when buffer overflows
class BufferOverflow implements Exception {
  @override
  String toString() {
    return 'Channel\'s Buffer overflow!';
  }
}

/// Thrown when an unexpected access to an empty buffer.
/// Check before accessing to buffer if there is any items buffered
class BufferisEmpty implements Exception {
  @override
  String toString() {
    return 'Buffer is empty';
  }
}

/// Thrown when a null callback provided
class CallbackCannotBeNull implements Exception {
  @override
  String toString() {
    return 'Callback can not be null';
  }
}

/// Thrown when a subscribe does not provide unsubscribe on return for an [EventChannel]
class EventChannelMustReturnUnsubscribeFunction implements Exception {
  @override
  String toString() {
    return 'EventChannel subscribe must return a function to unsubscribe';
  }
}

/// Thrown on an invalid operation
class InvalidOperation implements Exception {
  @override
  String toString() {
    return 'Invalid operation';
  }
}

/// Thrown when provided function is null
class CannotDetermineNullFunctionReturnType implements Exception {
  @override
  String toString() {
    return 'Can not determine null function return type';
  }
}

/// Thrown when provided function is null
class CannotDetermineNullFunctionArguments implements Exception {
  @override
  String toString() {
    return 'Can not determine null function arguments';
  }
}

/// Thrown when provided function is not a generator function
class GeneratorFunctionExpectedException implements Exception {
  @override
  String toString() {
    return 'Generator function expected';
  }
}
