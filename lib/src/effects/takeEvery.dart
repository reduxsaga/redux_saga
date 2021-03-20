part of redux_saga;

///  Spawns a `saga` on each action dispatched to the Store or the [channel] provided that matches [pattern].
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
///  - If [detached] is false `TakeEvery` will return a forked task, otherwise it will
///  return a spawned task. By default [detached] is false.
///
///  - [name] is an optional name for the task meta.
///
///  ### Example
///
///  In the following example, we create a basic task `fetchUser`.
///  We use `TakeEvery` to start a new `fetchUser` task on each
///  dispatched `UserRequested` action:
///
///```
///  import 'package:redux_saga/redux_saga.dart';
///  import 'Api.dart';
///
///  //...
///
///  fetchUser({dynamic action}) sync* {
///    // ...
///  }
///
///  watchFetchUser() sync* {
///    yield TakeEvery(fetchUser, pattern: UserRequested);
///  }
///```
///
///  ### Notes
///
///  `TakeEvery` is a high-level API built using [Take] and [Fork].
///
///  `TakeEvery` allows concurrent actions to be handled. In the example above, when a `UserRequested`
///  action is dispatched, a new `fetchUser` task is started even if a previous `fetchUser` is still pending
///  (for example, the user clicks on a `Load User` button 2 consecutive times at a rapid rate, the 2nd
///  click will dispatch a `UserRequested` action while the `fetchUser` fired on the first one hasn't yet terminated)
///
///  `TakeEvery` doesn't handle out of order responses from tasks. There is no guarantee that the tasks will
///  terminate in the same order they were started. To handle out of order responses, you may consider [TakeLatest].
Fork TakeEvery(Function saga,
    {List<dynamic>? args,
    Map<Symbol, dynamic>? namedArgs,
    Function? Catch,
    Function? Finally,
    Channel? channel,
    dynamic pattern,
    bool detached = false,
    String? name,
    Result? result}) {
  return Fork(_TakeEvery,
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

Iterable<Effect> _TakeEvery(Function saga,
    {List<dynamic>? args,
    Map<Symbol, dynamic>? namedArgs,
    Function? Catch,
    Function? Finally,
    Channel? channel,
    dynamic pattern,
    String? name}) sync* {
  while (true) {
    var action = Result<dynamic>();
    yield Take(pattern: pattern, channel: channel, result: action);

    yield Fork(saga,
        args: args,
        namedArgs: <Symbol, dynamic>{
          ...?namedArgs,
          #action: action is Result ? action.value : action
        },
        Catch: Catch,
        Finally: Finally,
        name: name);
  }
}
