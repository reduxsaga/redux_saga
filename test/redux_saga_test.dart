import 'channel_test.dart' as channel_test;
import 'scheduler_test.dart' as scheduler_test;
import 'call_test.dart' as call_test;
import 'fork_test.dart' as fork_test;
import 'all_test.dart' as all_test;
import 'take_test.dart' as take_test;
import 'race_test.dart' as race_test;
import 'cancelled_test.dart' as cancelled_test;
import 'spawn_test.dart' as spawn_test;
import 'put_test.dart' as put_test;
import 'select_test.dart' as select_test;
import 'actionChannel_test.dart' as action_channel_test;
import 'cps_test.dart' as cps_test;
import 'throttle_test.dart' as throttle_test;
import 'debounce_test.dart' as debounce_test;
import 'retry_test.dart' as retry_test;
import 'takeEvery_test.dart' as take_every_test;
import 'takeLatest_test.dart' as take_latest_test;
import 'takeLeading_test.dart' as take_leading_test;
import 'delay_test.dart' as delay_test;
import 'middleware_test.dart' as middleware_test;
import 'taskToFuture_test.dart' as task_to_future_test;
import 'monitoring_test.dart' as monitoring_test;
import 'channelRecipes_test.dart' as channelrecipes_test;
import 'base_test.dart' as base_test;
import 'onerror_test.dart' as onerror_test;
import 'future_test.dart' as future_test;
import 'cancellation_test.dart' as cancellation_test;
import 'context_test.dart' as context_test;
import 'effectMiddlewares_test.dart' as effect_middlewares_test;
import 'flush_test.dart' as flush_test;
import 'forkjoin_test.dart' as forkjoin_test;
import 'forkjoinErrors_test.dart' as fork_join_errors_test;
import 'iterators_test.dart' as iterators_test;
import 'take_sync_test.dart' as take_sync_test;

void main() {
  //middleware
  channel_test.main();
  scheduler_test.main();
  middleware_test.main();
  effect_middlewares_test.main();
  channelrecipes_test.main();
  task_to_future_test.main();
  monitoring_test.main();
  base_test.main();
  onerror_test.main();
  future_test.main();
  iterators_test.main();

  //effects
  call_test.main();
  fork_test.main();
  all_test.main();
  take_test.main();
  race_test.main();
  cancelled_test.main();
  spawn_test.main();
  put_test.main();
  select_test.main();
  action_channel_test.main();
  cps_test.main();
  delay_test.main();
  cancellation_test.main();
  context_test.main();
  flush_test.main();
  forkjoin_test.main();
  fork_join_errors_test.main();
  take_sync_test.main();

  //helpers
  throttle_test.main();
  debounce_test.main();
  retry_test.main();
  take_every_test.main();
  take_latest_test.main();
  take_leading_test.main();
}
