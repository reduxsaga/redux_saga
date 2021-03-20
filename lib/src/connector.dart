part of redux_saga;

/// Creates a Redux middleware
///
/// A list of [options] can be passed to the middleware
///
/// Below there is an example creation of a Saga middleware
///
/// ### Example
///
///```
/// // create middleware
/// var sagaMiddleware = createSagaMiddleware();
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
SagaMiddleware createSagaMiddleware([Options? options]) {
  return _SagaMiddleware(options);
}

/// Connects the [middleware] to the Redux Store
///
/// Applying middleware and passing it to Redux Store
/// enables dispatched store actions to flow through to middlewares channel.
///
/// Check the example at [createSagaMiddleware].
///
/// Note that, actions are first processed by the Store reducer and then sent to the middlewares channel.
///
Middleware<State> applyMiddleware<State>(SagaMiddleware middleware) {
  if (middleware is _SagaMiddleware) {
    middleware.connectedToStore = true;

    return (Store store, dynamic action, NextDispatcher next) {
      next(action);
      if (action != null) {
        middleware.put(action);
      }
      return action;
    };
  } else {
    throw InvalidOperation();
  }
}

/// Creates middleware for test purposes
///
/// Middleware is applied a Store<dynamic> and read to use test purposes.
/// Mocking can be handled by attaching handlers to middleware's [SagaMiddleware.dispatch] and
/// [SagaMiddleware.getState] methods.
SagaMiddleware createTestMiddleware([Options? options]) {
  var testMiddleware = createSagaMiddleware(options);

  var store = Store<dynamic>(
    (dynamic state, dynamic action) {
      return state;
    },
    initialState: 0,
    middleware: [
      applyMiddleware<dynamic>(testMiddleware),
    ],
  );

  testMiddleware.setStore(store);

  return testMiddleware;
}
