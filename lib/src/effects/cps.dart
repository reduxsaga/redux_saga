part of redux_saga;

/// [CPSCallback] handler member used for [CPS] effect.
typedef CPSCallbackHandler = void Function({dynamic err, dynamic res});

/// [CPS] effect callback object. Provides [callback] and self-cancellation [cancel] callback.
class CPSCallback {
  /// Callback for [CPS] effect
  final CPSCallbackHandler callback;

  /// Callback to cancel [CPS] effect.
  Callback cancel;

  /// Creates an instance of a [CPS] effect callback.
  CPSCallback(this.callback);
}

///  Creates an Effect description that instructs the middleware to invoke [fn] as a Node style function.
///
///  - [fn] is a Node style function. i.e. a function which accepts in addition to its arguments,
///      an additional callback to be invoked by [fn] when it terminates. The callback accepts two parameters,
///  where the first parameter is used to report errors while the second is used to report successful results.
///
///  - [args] and [namedArgs] are values to be passed as arguments to [fn]
///
///  #### Notes
///
///  The middleware will perform a call `fn(args:[args],namedArgs:[namedArgs], cb)`. The `cb` is a
///  callback passed by the middleware to [fn]. If [fn] terminates normally,
///  it must call `cb(res: result)` to notify the middleware
///  of a successful result. If [fn] encounters some error, then it must call `cb(err: error)`
///  in order to notify the middleware that an error has occurred.
///
///  The middleware remains suspended until [fn] terminates.
///
class CPS extends EffectWithResult {
  /// Meta name of function
  final String name;

  /// A Generator function or a normal function to call.
  final Function fn;

  /// Arguments of the function to call
  final List<dynamic> args;

  /// Named arguments of the function to call
  final Map<Symbol, dynamic> namedArgs;

  /// Creates an instance of a CPS effect.
  CPS(this.fn, {this.args, this.namedArgs, this.name, Result result}) : super(result: result);

  @override
  void _run(_SagaMiddleware middleware, _TaskCallback cb, _ExecutingContext executingContext) {
    // CPS (ie node style functions) can define their own cancellation logic
    // by setting cancel field on the cb

    // catch synchronous failures
    try {
      var cpsCb = CPSCallback(({dynamic err, dynamic res}) {
        if (err == null) {
          cb.next(arg: res);
        } else {
          cb.next(arg: _createSagaException(err), isErr: true);
        }
      });

      var namedArgs = <Symbol, dynamic>{};
      if (namedArgs != null) {
        namedArgs.addAll(namedArgs);
      }
      namedArgs[#cb] = cpsCb;

      _callFunction(fn, args, namedArgs);

      if (cpsCb.cancel != null) {
        cb.cancelHandler = cpsCb.cancel;
      }
    } catch (e, s) {
      cb.next(arg: _createSagaException(e, s), isErr: true);
    }
  }

  @override
  Map<String, dynamic> getDefinition() {
    var kv = <String, dynamic>{};
    kv['type'] = 'CPS';
    kv['fn'] = fn;
    kv['args'] = args;
    kv['namedArgs'] = namedArgs;
    kv['name'] = name;
    kv['result'] = result;
    return kv;
  }
}
