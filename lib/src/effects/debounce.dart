part of redux_saga;

///  Spawns a `saga` on an action dispatched to the Store or the [channel] provided that matches [pattern].
///  Saga will be called after it stops taking [pattern] actions for [duration].
///  Purpose of this is to prevent calling saga until the actions are settled off.
///
///  - [duration] defines how much delay should elapse since the last time
///  [pattern] action was fired to call the `saga`
///
///  - [pattern] is used to filter actions. Only matching actions will be processed. See docs for [Take].
///
///  - [saga] is a Generator function.
///
///  - [args] and [namedArgs] are arguments to be passed to the started task. `Debounce` will add the
///  incoming action to the argument list (i.e. the action will be a named `{dynamic action}` argument
///  provided to `saga`)
///
///  - If a [channel] is provided then actions will be put from provided channel.
///
///  - [Catch] will be invoked for uncaught errors.
///
///  - [Finally] will be invoked in any case before task execution is end.
///
///  - If [detached] is false `Debounce` will return a forked task, otherwise it will
///  return a spawned task. By default [detached] is false.
///
///  - [name] is an optional name for the task meta.
///
///  ### Example
///
///  In the following example, we create a basic task `fetchAutocomplete`. We use `debounce` to
///  delay calling `fetchAutocomplete` saga until we stop receive any `FetchedAutocomplete` events
///  for at least `1000` ms.
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
///  debounceAutocomplete() sync* {
///    yield Debounce(
///      fetchAutocomplete,
///      duration: Duration(milliseconds: 1000),
///      pattern: FetchedAutocomplete,
///    );
///  }
///```
/// Note that, `debounce` is a high-level API built using [Take], [Delay], [Race] and [Fork].
///
Fork Debounce(Function saga,
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
  return Fork(_Debounce,
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

Iterable<Effect> _Debounce(Function saga,
    {List<dynamic> args,
    Map<Symbol, dynamic> namedArgs,
    Function Catch,
    Function Finally,
    Channel channel,
    dynamic pattern,
    Duration duration,
    String name}) sync* {
  Channel debounceChannel;

  if (channel == null) {
    var channelResult = Result<Channel>();
    yield ActionChannel(pattern,
        buffer: Buffers.sliding<dynamic>(1), result: channelResult);
    debounceChannel = channelResult.value;
  } else {
    debounceChannel = channel;
  }

  while (true) {
    var actionResult = Result<dynamic>();
    yield Take(
        pattern: pattern, channel: debounceChannel, result: actionResult);
    dynamic action = actionResult is Result ? actionResult.value : actionResult;

    while (true) {
      var raceResult = RaceResult();

      yield Race(<dynamic, Effect>{
        #debounced: duration == null
            ? Delay(Duration(milliseconds: 0))
            : Delay(duration),
        #latestAction: Take(pattern: pattern, channel: debounceChannel)
      }, result: raceResult);

      if (raceResult.key == #debounced) {
        yield Fork(saga,
            args: args,
            namedArgs: <Symbol, dynamic>{...?namedArgs, #action: action},
            Catch: Catch,
            Finally: Finally,
            name: name);
        break;
      }

      action = raceResult.keyValue;
    }
  }
}
