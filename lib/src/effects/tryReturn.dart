part of redux_saga;
/// An alias for [Try/Call] effect. It makes try/catch/finally code blocks more readable and returns value like [Return].
/// If you want to return from a returned value from a Try/Catch/Finally block then use `TryReturn`.
///
///
///  ### Example
///
/// In the following example the saga returns value returned
///```
///  saga() sync* {
///    yield TryReturn(() sync* { //returns saga
///      //...
///      yield Return(somevalue1); //returns Try
///    }, Catch: (error) sync* {
///      //...
///      yield Return(somevalue2); //returns Try
///    });
///  }
///```
///
/// Equivalent code with `Try`
///
///```
///  saga() sync* {
///    var result = Result();
///    yield Try(() sync* {
///      //...
///      yield Return(somevalue1); //returns Try. Does not return saga
///    }, Catch: (error) sync* {
///      //...
///      yield Return(somevalue2); //returns Try. Does not return saga
///    }, result: result);
///    yield Return(result.value); //returns saga
///  }
///```
///
/// In the following example, there is a simple checkout saga function.
/// It tries to checkout the cart. If it successes returns a `CheckoutSuccess` action
/// otherwise returns a `CheckoutFailure` action.
///
///```
///  import 'package:redux_saga/redux_saga.dart';
///  import 'Api.dart';
///
///  //...
///
///  checkout() sync* {
///    yield TryReturn(() sync* {
///      var cart = Result<Cart>();
///      yield Select(selector: getCart, result: cart);
///      yield Call(buyProductsAPI, args: [cart.value]);
///      yield Return(CheckoutSuccess(cart.value));
///    }, Catch: (error) sync* {
///      yield Return(CheckoutFailure(error));
///    });
///  }
///```
///
class TryReturn extends Call {
  /// Creates an instance of a Try effect.
  TryReturn(Function fn,
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
  void _setResult(_Task task, dynamic value, bool isErr) {
    task.taskResult = value;
  }

  @override
  Map<String, dynamic> getDefinition() {
    var kv = super.getDefinition();
    kv['type'] = 'TryReturn';
    return kv;
  }
}
