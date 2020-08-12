part of redux_saga;

/// Defines a scheduler task to queue
typedef TaskCallback = void Function();

/// Defines a scheduler task to execute immediately
typedef TaskCallbackImmediately = Task Function();

final _queue = Queue<TaskCallback>();

/// Variable to hold a counting semaphore
/// - Incrementing adds a lock and puts the scheduler in a `suspended` state (if it's not
/// already suspended)
/// - Decrementing releases a lock. Zero locks puts the scheduler in a `released` state. This
/// triggers flushing the queued tasks.
var _semaphore = 0;

bool get _released => _semaphore == 0;

bool get _hasPendingTasks => _queue.isNotEmpty;

/// Executes a task 'atomically'. Tasks scheduled during this execution will be queued
/// and flushed after this task has finished (assuming the scheduler ends up in a released
/// state).
void _exec(TaskCallback task) {
  try {
    _suspend();
    task();
  } finally {
    _release();
  }
}

/// Executes or queues a task depending on the state of the scheduler (`suspended` or `released`)
void asap(TaskCallback task) {
  _queue.add(task);

  if (_released) {
    _suspend();
    _flush();
  }
}

/// Puts the scheduler in a `suspended` state and executes a task immediately.
Task immediately(TaskCallbackImmediately task) {
  try {
    _suspend();
    return task();
  } finally {
    _flush();
  }
}

/// Puts the scheduler in a `suspended` state. Scheduled tasks will be queued until the
/// scheduler is released.
void _suspend() {
  _semaphore++;
}

/// Puts the scheduler in a `released` state.
void _release() {
  _semaphore--;
}

/// Releases the current lock. Executes all queued tasks if the scheduler is in the released state.
void _flush() {
  _release();

  while (_released && _hasPendingTasks) {
    _exec(_queue.removeFirst());
  }
}
