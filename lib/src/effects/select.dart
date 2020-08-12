part of redux_saga;

///  Creates an effect that instructs the middleware to invoke the provided selector on the
///  current Store's state (i.e. returns the result of `selector(getState(), args: [...])`).
///
///  - [selector] is a function `(state, args: [...], namedArgs: {...}) => ...`. It takes the
///  current state and optionally some arguments and returns a slice of the current Store's state.
///
///  - [args]/[namedArgs] is optional arguments to be passed to the selector in addition of `getState`.
///
///  If `select` is called without argument (i.e. `yield Select()`) then the effect is resolved
///  with the entire state (the same result of a `getState()` call).
///
///  It's important to note that when an action is dispatched to the store, the middleware first
///  forwards the action to the reducers and then notifies the Sagas. This means that when you query the
///  Store's State, you get the State **after** the action has been applied.
///
///  However, this behavior is only guaranteed if all subsequent middlewares call `next(action)` synchronously.
///  If any subsequent middleware calls `next(action)` asynchronously (which is unusual but possible),
///  then the sagas will get the state from **before** the action is applied.  Therefore it is recommended
///  to review the source of each subsequent middleware to ensure it calls `next(action)` synchronously,
///  or else ensure that redux-saga is the last middleware in the call chain.
///
///  ### Notes
///
///  Preferably, a Saga should be autonomous and should not depend on the Store's state. This makes
///  it easy to modify the state implementation without affecting the Saga code. A saga should preferably
///  depend only on its own internal control state when possible. But sometimes, one could
///  find it more convenient for a Saga to query the state instead of maintaining the needed data by itself
///  (for example, when a Saga duplicates the logic of invoking some reducer to compute a state that was
///  already computed by the Store).
///
///  For example, suppose we have this state shape in our application:
///
///```
///  class AppState {
///    final Products products;
///    final Cart cart;
///    final CartStatus cartStatus;
///  }
///```
///
///  We can create a *selector*, i.e. a function which knows how to extract the `cart` data from the State:
///
///```
///  Cart getCart(AppState state) => state.cart;
///```
///
///  Then we can use that selector from inside a Saga using the `select` Effect:
///
///```
///  import 'package:redux_saga/redux_saga.dart';
///  import 'Api.dart';
///
///  //...
///
///  checkout() sync* {
///    // query the state using the exported selector
///    var cart = Result<Cart>();
///    yield Select(selector: getCart, result: cart);
///
///    // ... call some API endpoint then dispatch a success/error action
///  }
///
///  rootSaga() sync* {
///    while (true) {
///      yield Take(pattern: CheckoutRequest);
///      yield Fork(checkout);
///    }
///  }
///```
///
///  `checkout` can get the needed information directly by using `select(getCart)`.
///  The Saga is coupled only with the `getCart` selector. If we have many Sagas (or Components)
///  that needs to access the `cart` slice, they will all be coupled to the same function `getCart`.
///  And if we now change the state shape, we need only to update `getCart`.
class Select extends EffectWithResult {
  /// A function returning a slice of the current Store's state.
  final Function selector;

  /// Arguments of the function to call
  final List<dynamic> args;

  /// Named arguments of the function to call
  final Map<Symbol, dynamic> namedArgs;

  /// Creates an instance of a Select effect.
  Select({this.selector, this.args, this.namedArgs, Result result}) : super(result: result);

  @override
  void _run(_SagaMiddleware middleware, _TaskCallback cb, _ExecutingContext executingContext) {
    try {
      if (selector == null) {
        cb.next(arg: middleware.getState());
      } else {
        dynamic state = _callFunctionWithArgument(selector, args, namedArgs, middleware.getState());
        cb.next(arg: state);
      }
    } catch (e, s) {
      cb.next(arg: _createSagaException(e, s), isErr: true);
    }
  }

  @override
  Map<String, dynamic> getDefinition() {
    var kv = <String, dynamic>{};
    kv['type'] = 'Select';
    kv['selector'] = selector;
    kv['args'] = args;
    kv['namedArgs'] = namedArgs;
    kv['result'] = result;
    return kv;
  }
}
