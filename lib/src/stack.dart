part of redux_saga;

class _SagaErrorStack {
  dynamic crashedEffect;

  List<_SagaFrame> sagaStack = [];

  void clear() {
    crashedEffect = null;
    sagaStack.clear();
  }

  // this sets crashed effect for the soon-to-be-reported saga frame
  void setCrashedEffect(dynamic effect) {
    crashedEffect = effect;
  }

  void addSagaFrame(_SagaFrame frame) {
    frame.crashedEffect = crashedEffect;
    sagaStack.add(frame);
  }

  @override
  String toString() {
    var message = _emptyString;
    if (sagaStack.isNotEmpty) {
      var lines = <String>[];
      var cancelledTasks = <String>[];
      for (var i = 0; i < sagaStack.length; i++) {
        var frame = sagaStack[i];
        var effectDesc = frame.crashedEffect == null
            ? ''
            : ' when executing effect ${frame.crashedEffect}';
        if (i == 0) {
          lines.add(
              'The above error occurred in task ${frame.meta} ${effectDesc}');
        } else {
          lines.add(' created by ${frame.meta}');
        }
        if (frame.cancelledTasks.isNotEmpty) {
          for (var ct in frame.cancelledTasks) {
            cancelledTasks.add(ct);
          }
        }
      }
      if (cancelledTasks.isNotEmpty) {
        lines.add('Tasks cancelled due to error:');
        for (var ct in cancelledTasks) {
          lines.add(' $ct');
        }
      }
      for (var i = 0; i < lines.length; i++) {
        message += '#$i      ${lines[i]}\n';
      }
    }
    return message;
  }
}

class _SagaFrame {
  SagaMeta meta;
  List<String> cancelledTasks;
  dynamic crashedEffect;

  _SagaFrame(this.meta, this.cancelledTasks);
}

_SagaInternalException _createSagaException(dynamic error,
    [StackTrace stackTrace]) {
  if (error is _SagaInternalException) return error;
  return _SagaInternalException(error, stackTrace);
}

class _SagaInternalException implements Exception {
  final dynamic message;
  final StackTrace stackTrace;

  _SagaInternalException([this.message, this.stackTrace]);

  @override
  String toString() {
    return message == null ? 'Error' : message.toString();
  }
}

/// Caught error type at Catch block.
/// No need to instantiate. Use global instance [sagaError] instead.
/// Use throw [sagaError]; to rethrow error on Catch block.
class SagaError implements Exception {
  /// Creates an instance of [SagaError]
  SagaError();
}

/// Global instance of [SagaError].
/// It is used to rethrow error on Catch block.
/// Use throw [sagaError]; to rethrow error on Catch.
final sagaError = SagaError();

/// Checks whether error [e] or `e.message` is a [SagaError]
bool isSagaError(dynamic e) =>
    e is SagaError || e is _SagaInternalException && e.message is SagaError;
