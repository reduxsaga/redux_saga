part of redux_saga;

///  Creates an Effect description that instructs the middleware to call
///  the function [fn] with [args] and [namedArgs] as arguments.
///  In case of failure will try to make another call after
///  a [duration], if a number of attempts < [maxTries].
///
///  - [maxTries] is maximum calls count.
///
///  - [duration] is length of a time window between [fn] calls.
///
///  - [fn] is a Generator function, or normal function which either returns a Promise as a result, or any other value.
///
///  - [args] and [namedArgs] are values to be passed as arguments to [fn]
///
///  ### Example
///
///  In the following example, we create a basic task `RetrySaga`. We use `retry` to try to
///  fetch our API 3 times with 10 second interval. If `request` fails first time than `retry`
///  will call `request` one more time while calls count less than 3.,
///
///```
///  import 'package:redux_saga/redux_saga.dart';
///  import 'Api.dart';
///
///  //...
///
///  retrySaga(data) sync* {
///    yield Try(() sync* {
///      var response = Result();
///      yield Retry(
///        request,
///        args: [data],
///        maxTries: 3,
///        duration: Duration(seconds: 10),
///        result: response,
///      );
///      yield Put(RequestSuccess(payload: response.value));
///    }, Catch: (error) sync* {
///      yield Put(RequestFail(payload: error));
///    });
///  }
///```
///
///  Note that, `retry` is a high-level API built using [Delay] and [Call].
///
Call Retry(Function fn,
    {List<dynamic> args,
    Map<Symbol, dynamic> namedArgs,
    Function Catch,
    Function Finally,
    int maxTries,
    Duration duration,
    String name,
    Result result}) {
  return Call(_Retry,
      args: <dynamic>[fn],
      namedArgs: <Symbol, dynamic>{
        #args: args,
        #namedArgs: namedArgs,
        #maxTries: maxTries,
        #duration: duration,
        #name: name,
        #result: result
      },
      Catch: Catch,
      Finally: Finally);
}

Iterable<Effect> _Retry(Function fn,
    {List<dynamic> args,
    Map<Symbol, dynamic> namedArgs,
    int maxTries,
    Duration duration,
    String name,
    Result result}) sync* {
  var triesLeft = maxTries;
  while (true) {
    var failed = false;
    yield Call(fn, args: args, namedArgs: namedArgs, Catch: () {
      triesLeft--;
      if (triesLeft <= 0) {
        throw sagaError;
      }
      failed = true;
    }, name: name, result: result);

    if (!failed) {
      break;
    }
    if (duration != null) {
      yield Delay(duration);
    }
  }
}
