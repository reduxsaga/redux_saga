part of redux_saga;

/// Handler for a passing effect to next middleware.
typedef NextMiddlewareHandler = void Function(dynamic effect);

/// Handler for creating custom effects for middleware.
/// It can be passed as an option while creating middleware.
/// Effects middleware intercepts messages before they reach to
/// middleware.
///
///```
///  // Custom effect middleware
///  var effectMiddleware = (dynamic effect, NextMiddlewareHandler next) {
///    if (effect == effectToProcess) {
///      next(injectedValue);
///      return;
///    }
///    return next(effect);
///  };
///
///  // create middleware and pass options
///  var sagaMiddleware = createSagaMiddleware(
///    //initiate context with options
///    Options(effectMiddlewares: [effectMiddleware]),
///  );
///  ```
///
typedef EffectMiddlewareHandler = void Function(dynamic effect, NextMiddlewareHandler next);

/// Handler for catching uncaught errors. It can be passed as an option while creating middleware.
typedef OnErrorHandler = void Function(dynamic e, String stack);

/// Optional parameters can be passed to middleware creation.
///
/// Below there is an example creation of middleware with options.
/// In the example, onError option is passed in order to handle uncaught middleware errors.
///
/// ### Example
///
///```
/// //create options
/// var options = Options(
///   //add an option to handle uncaught errors
///   onError: (dynamic e, String s) {
///     //print uncaught errors to the console
///     print(e);
///   },
/// );
///
/// // create middleware and pass options
/// var sagaMiddleware = createSagaMiddleware(options);
///
/// // create store and apply middleware
/// final store = Store<int>(
///   counterReducer,
///   initialState: 0,
///   middleware: [applyMiddleware(sagaMiddleware)],
/// );
///
/// // set store
/// sagaMiddleware.setStore(store);
///
/// // run root saga
/// sagaMiddleware.run(rootSaga);
///```
///
class Options {
  /// Initial value of the saga's context.
  Map<dynamic, dynamic> context;

  /// A channel is an object used to send and receive messages between tasks.
  /// Preferably you should use [StdChannel] here.
  Channel channel;

  /// If a Saga Monitor is provided, the middleware will deliver monitoring
  /// events to the monitor.
  SagaMonitor sagaMonitor;

  /// If provided, the middleware will call it with uncaught errors from Sagas.
  /// useful for sending uncaught exceptions to error tracking services.
  OnErrorHandler onError;

  /// Allows you to intercept any effect, resolve it on your own and pass to the
  /// next middleware.
  List<EffectMiddlewareHandler> effectMiddlewares;

  /// Creates an instance of a middleware [Options]
  Options({this.context, this.channel, this.sagaMonitor, this.onError, this.effectMiddlewares});
}
