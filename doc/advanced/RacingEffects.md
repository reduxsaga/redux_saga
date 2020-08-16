## Starting a race between multiple Effects

Sometimes we start multiple tasks in parallel but we don't want to wait for all of them, we just need
to get the *winner*: the first one that resolves (or rejects). The `Race` Effect offers a way of
triggering a race between multiple Effects.

The following sample shows a task that triggers a remote fetch request, and constrains the response within a
1 second timeout.

```dart
fetchPostsWithTimeout() sync* {
  var result = RaceResult();

  yield Race({
    #posts: Call(fetchApi, args: ['/posts']),
    #timeout: Delay(Duration(seconds: 1))
  });

  if (result.key == #posts) {
    yield Put(PostsReceived(posts));
  } else {
    yield Put(TimeoutError());
  }
}
```

Another useful feature of `Race` is that it automatically cancels the loser Effects. For example,
suppose we have 2 UI buttons:

- The first starts a task in the background that runs in an endless loop `while (true)`
(e.g. syncing some data with the server each x seconds).

- Once the background task is started, we enable a second button which will cancel the task


```dart
backgroundTask() sync* {
  while (true) {
  ...
  }
}

watchStartBackgroundTask() sync* {
  while (true) {
    yield Take(pattern: 'StartBackgroundTask');
    yield Race({
      #task: Call(backgroundTask),
      #cancel: Take(pattern: 'CancelTask'),
    });
  }
}
```

In the case a `CancelTask` action is dispatched, the `Race` Effect will automatically cancel
`backgroundTask` by throwing a cancellation error inside it.
