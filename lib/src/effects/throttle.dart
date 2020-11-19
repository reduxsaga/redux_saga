part of redux_saga;

///  Spawns a `saga` on an action dispatched to the Store or the [channel] provided that matches [pattern].
///  After spawning a task it's still accepting incoming actions into the
///  underlying `buffer`, keeping at most 1 (the most recent one), but in the
///  same time holding up with spawning new task for [duration] (hence its name - `Throttle`).
///  Purpose of this is to ignore incoming actions for a given period of time while
///  processing a task.
///
///  - [duration] is length of a time window during which actions will be ignored after the
///  action starts processing.
///
///  - [pattern] is used to filter actions. Only matching actions will be processed. See docs for [Take].
///
///  - [saga] is a Generator function.
///
///  - [args] and [namedArgs] are arguments to be passed to the started task. `Throttle` will add the
///  incoming action to the argument list (i.e. the action will be a named `{dynamic action}` argument
///  provided to `saga`)
///
///  - If a [channel] is provided then actions will be put from provided channel.
///
///  - [Catch] will be invoked for uncaught errors.
///
///  - [Finally] will be invoked in any case before task execution is end.
///
///  - If [detached] is false `Throttle` will return a forked task, otherwise it will
///  return a spawned task. By default [detached] is false.
///
///  - [name] is an optional name for the task meta.
///
///  ### Example
///
///  In the following example, we create a basic task `fetchAutocomplete`.
///  We use `Throttle` to start a new `fetchAutocomplete` task on dispatched `FetchedAutocomplete`
///  action. However since `Throttle` ignores consecutive `FetchedAutocomplete` for some time,
///  we ensure that user won't flood our server with requests.
///
///```
///  import 'package:redux_saga/redux_saga.dart';
///  import 'Api.dart';
///
///  //...
///
///  fetchAutocomplete({dynamic action}) sync* {
///    var autocompleteProposals = Result();
///    yield Call(Api.fetchAutocomplete, args: [action.text]);
///    yield Put(FetchedAutocompleteProposals(proposals: autocompleteProposals));
///  }
///
///  throttleAutocomplete() sync* {
///    yield Throttle(
///      fetchAutocomplete,
///      duration: Duration(milliseconds: 1000),
///      pattern: FetchedAutocomplete,
///    );
///  }
///```
///
/// Note that, `Throttle` is a high-level API built using [Take], [Fork] and [ActionChannel].
///
Fork Throttle(Function saga,
    {List<dynamic> args,
    Map<Symbol, dynamic> namedArgs,
    Function Catch,
    Function Finally,
    Channel channel,
    dynamic pattern,
    Duration duration,
    bool detached = false,
    String name,
    Result result}) {
  return Fork(_Throttle,
      args: <dynamic>[saga],
      namedArgs: <Symbol, dynamic>{
        #args: args,
        #namedArgs: namedArgs,
        #Catch: Catch,
        #Finally: Finally,
        #channel: channel,
        #pattern: pattern,
        #duration: duration,
        #name: name
      },
      detached: detached,
      result: result);
}

Iterable<Effect> _Throttle(Function saga,
    {List<dynamic> args,
    Map<Symbol, dynamic> namedArgs,
    Function Catch,
    Function Finally,
    Channel channel,
    dynamic pattern,
    Duration duration,
    String name}) sync* {
  Channel throttleChannel;

  if (channel == null) {
    var channelResult = Result<Channel>();
    yield ActionChannel(pattern,
        buffer: Buffers.sliding<dynamic>(1), result: channelResult);
    throttleChannel = channelResult.value;
  } else {
    throttleChannel = channel;
  }

  while (true) {
    var action = Result<dynamic>();
    yield Take(pattern: pattern, channel: throttleChannel, result: action);

    yield Fork(saga,
        args: args,
        namedArgs: <Symbol, dynamic>{
          ...?namedArgs,
          #action: action is Result ? action.value : action
        },
        Catch: Catch,
        Finally: Finally,
        name: name);
    if (duration != null) {
      yield Delay(duration);
    }
  }
}
