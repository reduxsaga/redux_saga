/// `redux_saga` is a library that aims to make application side effects
/// (i.e. asynchronous things like data fetching and impure things like
/// accessing the browser cache) easier to manage, more efficient to execute,
/// easy to test, and better at handling failures.
///
library redux_saga;

import 'dart:async';
import 'dart:collection';
import 'package:redux/redux.dart';

part 'src/buffers.dart';
part 'src/channel.dart';
part 'src/actions.dart';
part 'src/scheduler.dart';
part 'src/middleware.dart';
part 'src/utils.dart';
part 'src/matcher.dart';
part 'src/monitor.dart';
part 'src/task.dart';
part 'src/uniqueId.dart';
part 'src/meta.dart';
part 'src/exceptions.dart';
part 'src/resolve.dart';
part 'src/context.dart';
part 'src/taskRunner.dart';
part 'src/forkedTasks.dart';
part 'src/effects/effect.dart';
part 'src/effects/effectWithResult.dart';
part 'src/effects/call.dart';
part 'src/effects/fork.dart';
part 'src/effects/getContext.dart';
part 'src/effects/return.dart';
part 'src/effects/setContext.dart';
part 'src/effects/result.dart';
part 'src/effects/delay.dart';
part 'src/effects/cancel.dart';
part 'src/effects/cancelled.dart';
part 'src/effects/join.dart';
part 'src/effects/all.dart';
part 'src/effects/take.dart';
part 'src/effects/takeMaybe.dart';
part 'src/effects/race.dart';
part 'src/effects/spawn.dart';
part 'src/effects/put.dart';
part 'src/effects/putResolve.dart';
part 'src/effects/select.dart';
part 'src/effects/actionChannel.dart';
part 'src/effects/flushChannel.dart';
part 'src/effects/cps.dart';
part 'src/effects/throttle.dart';
part 'src/effects/debounce.dart';
part 'src/effects/retry.dart';
part 'src/effects/takeEvery.dart';
part 'src/effects/takeLatest.dart';
part 'src/effects/takeLeading.dart';
part 'src/effects/apply.dart';
part 'src/effects/try.dart';
part 'src/taskCallback.dart';
part 'src/connector.dart';
part 'src/options.dart';
part 'src/stack.dart';
part 'src/taskResult.dart';
part 'src/functions.dart';
part 'src/cloneableGenerator.dart';
