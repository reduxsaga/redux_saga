part of redux_saga;

void _resolveFuture(Future future, _TaskCallback cb) {
  future.then((dynamic value) => cb.next(arg: value)).catchError(
      (dynamic error, StackTrace stackTrace) =>
          cb.next(arg: _createSagaException(error, stackTrace), isErr: true));
}

void _resolveFutureWithCancel(FutureWithCancel future, _TaskCallback cb) {
  cb.cancelHandler = future.cancel;
  _resolveFuture(future.future, cb);
}

/// Cancellable Future.
///
/// Future can be cancelled, if [cancel] callback is provided.
/// Check [Cancel] effect for details and example usage.
class FutureWithCancel {
  /// Result future object.
  Future future;

  /// Cancellation callback.
  Callback cancel;

  /// Creates an instance of a FutureWithCancel.
  FutureWithCancel(this.future, this.cancel);
}
