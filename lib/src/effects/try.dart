part of redux_saga;

/// An alias for [Call] effect. It makes try/catch/finally code blocks more readable.
///
/// It is useful to catch errors during effect resolve and instruct finally blocks.
/// It is not possible to catch effect resolve errors by standart try/catch blocks.
/// Try effect must be used to handle those errors and finally code blocks.
///
///  ### Example
///
/// In the following example, there is a simple checkout saga function.
/// It tries to checkout the cart. If fails it dispatches a `CheckoutFailure` action.
///
///```
///  import 'package:redux_saga/redux_saga.dart';
///  import 'Api.dart';
///
///  //...
///
///  checkout() sync* {
///    yield Try(() sync* {
///      var cart = Result<Cart>();
///      yield Select(selector: getCart, result: cart);
///      yield Call(buyProductsAPI, args: [cart.value]);
///      yield Put(CheckoutSuccess(cart.value));
///    }, Catch: (e, s) sync* {
///      yield Put(CheckoutFailure(error));
///    });
///  }
///```
///
class Try extends Call {
  /// Creates an instance of a Try effect.
  Try(Function fn,
      {List<dynamic> args,
      Map<Symbol, dynamic> namedArgs,
      Function Catch,
      Function Finally,
      String name,
      Result result})
      : super(fn,
            args: args,
            namedArgs: namedArgs,
            Catch: Catch,
            Finally: Finally,
            name: name,
            result: result);

  @override
  Map<String, dynamic> getDefinition() {
    var kv = super.getDefinition();
    kv['type'] = 'Try';
    return kv;
  }
}
