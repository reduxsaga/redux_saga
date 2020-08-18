# Concurrency

In the basics section, we saw how to use the helper effects `TakeEvery` and `TakeLatest` in order to manage concurrency between Effects.

In this section we'll see how those helpers could be implemented using the low-level Effects.

## `TakeEvery`

```dart
  while (true) {
    var action = Result();
    yield Take(pattern: pattern, result: action);

    yield Fork(
      saga,
      args: [...],
      namedArgs: {#action: action.value},
    );
  }
```

`TakeEvery` allows multiple `saga` tasks to be forked concurrently.

## `TakeLatest`

```dart
  var forkedTask = Result<Task>();

  while (true) {
    var action = Result();
    yield Take(pattern: pattern, result: action);

    if (forkedTask.value != null) {
      yield Cancel([forkedTask.value]);
    }

    yield Fork(
      saga,
      args: [...],
      namedArgs: {#action: action.value},
      result: forkedTask,
    );
  }
```

`TakeLatest` doesn't allow multiple Saga tasks to be fired concurrently. As soon as it gets a new dispatched action, it cancels any previously-forked task (if still running).

`TakeLatest` can be useful to handle AJAX requests where we want to only have the response to the latest request.
