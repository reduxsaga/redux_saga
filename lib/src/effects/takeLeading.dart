part of redux_saga;

///  Spawns a `saga` on each action dispatched to the Store or the [channel] provided that matches [pattern].
///  After spawning a task once, it blocks until spawned saga completes and then starts to listen for a [pattern] again.
///
///  In short, `TakeLeading` is listening for the actions when it doesn't run a saga.
///
///  - [pattern] is used to filter actions. Only matching actions will be processed. See docs for [Take].
///
///  - [saga] is a Generator function.
///
///  - [args] and [namedArgs] are arguments to be passed to the started task. `TakeEvery` will add the
///  incoming action to the argument list (i.e. the action will be a named `{dynamic action}` argument
///  provided to `saga`)
///
///  - If a [channel] is provided then actions will be put from provided channel.
///
///  - [Catch] will be invoked for uncaught errors.
///
///  - [Finally] will be invoked in any case before task execution is end.
///
///  - If [detached] is false `TakeLeading` will return a forked task, otherwise it will
///  return a spawned task. By default [detached] is false.
///
///  - [name] is an optional name for the task meta.
///
///  ### Example
///
///  In the following example, we create a basic task `fetchUser`. We use `TakeLeading` to
///  start a new `fetchUser` task on each dispatched `UserRequested` action. Since `TakeLeading`
///  ignores any new coming task after it's started, we ensure that if a user triggers multiple consecutive
///  `UserRequested` actions rapidly, we'll only keep on running with the leading action
///
///```
///  import 'package:redux_saga/redux_saga.dart';
///  import 'Api.dart';
///
///  //...
///
///  fetchUser(action) sync* {
///    // ...
///  }
///
///  watchLastFetchUser() sync* {
///    yield TakeLeading(fetchUser, pattern: UserRequested);
///  }
///```
///
///  ### Notes
///
///  `TakeLeading` is a high-level API built using [Take] and [Fork].
///
Fork TakeLeading(Function saga,
    {List<dynamic> args,
    Map<Symbol, dynamic> namedArgs,
    Function Catch,
    Function Finally,
    Channel channel,
    dynamic pattern,
    bool detached = false,
    String name,
    Result result}) {
  return Fork(_TakeLeading,
      args: <dynamic>[saga],
      namedArgs: <Symbol, dynamic>{
        #args: args,
        #namedArgs: namedArgs,
        #Catch: Catch,
        #Finally: Finally,
        #channel: channel,
        #pattern: pattern,
        #name: name
      },
      detached: detached,
      result: result);
}

Iterable<Effect> _TakeLeading(Function saga,
    {List<dynamic> args,
    Map<Symbol, dynamic> namedArgs,
    Function Catch,
    Function Finally,
    Channel channel,
    dynamic pattern,
    String name}) sync* {
  while (true) {
    var action = Result<dynamic>();
    yield Take(pattern: pattern, channel: channel, result: action);

    yield Call(saga,
        args: args,
        namedArgs: _functionHasActionArgument(saga)
            ? <Symbol, dynamic>{...?namedArgs, #action: action is Result ? action.value : action}
            : namedArgs,
        Catch: Catch,
        Finally: Finally);
  }
}
