part of redux_saga;

///  Forks a `saga` on each action dispatched to the Store or the [channel] provided that matches [pattern].
///  And automatically cancels any previous `saga` task started previously if it's still running.
///
///  Each time an action is dispatched to the store. And if this action matches [pattern], `TakeLatest`
///  starts a new `saga` task in the background. If a `saga` task was started previously (on the last action dispatched
///  before the actual action), and if this task is still running, the task will be cancelled.
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
///  - If [detached] is false `TakeLatest` will return a forked task, otherwise it will
///  return a spawned task. By default [detached] is false.
///
///  - [name] is an optional name for the task meta.
///
///  #### Example
///
///  In the following example, we create a basic task `fetchUser`. We use `TakeLatest` to
///  start a new `fetchUser` task on each dispatched `UserRequested` action. Since `TakeLatest`
///  cancels any pending task started previously, we ensure that if a user triggers multiple consecutive
///  `UserRequested` actions rapidly, we'll only conclude with the latest action.
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
///    yield TakeLatest(fetchUser, pattern: UserRequested);
///  }
///```
///
///  ### Notes
///
///  `TakeLatest` is a high-level API built using [Take] and [Fork].
///
Fork TakeLatest(Function saga,
    {List<dynamic> args,
    Map<Symbol, dynamic> namedArgs,
    Function Catch,
    Function Finally,
    Channel channel,
    dynamic pattern,
    bool detached = false,
    String name,
    Result result}) {
  return Fork(_TakeLatest,
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

Iterable<Effect> _TakeLatest(Function saga,
    {List<dynamic> args,
    Map<Symbol, dynamic> namedArgs,
    Function Catch,
    Function Finally,
    Channel channel,
    dynamic pattern,
    String name}) sync* {
  var forkedTask = Result<Task>();

  while (true) {
    var action = Result<dynamic>();
    yield Take(pattern: pattern, channel: channel, result: action);

    if (forkedTask.value != null) {
      yield Cancel([forkedTask.value]);
    }

    yield Fork(saga,
        args: args,
        namedArgs: _functionHasActionArgument(saga)
            ? <Symbol, dynamic>{...?namedArgs, #action: action is Result ? action.value : action}
            : namedArgs,
        Catch: Catch,
        Finally: Finally,
        name: name,
        result: forkedTask);
  }
}
