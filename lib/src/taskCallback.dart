part of redux_saga;

void _noopNext({_TaskCallback invoker, dynamic arg, bool isErr = false}) {}

final _TaskCallback _noopTaskCallback = _TaskCallback(_noopNext, _noop);

typedef _NextHandler = void Function({_TaskCallback invoker, dynamic arg, bool isErr});

class _TaskCallback {
  _NextHandler nextHandler;
  Callback cancelHandler;
  dynamic effect;

  _TaskCallback(this.nextHandler, [this.cancelHandler]);

  void next({dynamic arg, bool isErr = false}) {
    nextHandler(invoker: this, arg: arg, isErr: isErr);
  }

  void cancel() {
    cancelHandler();
  }
}
