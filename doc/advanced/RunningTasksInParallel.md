# Running Tasks In Parallel

The `yield` statement is great for representing asynchronous control flow in a linear style, but we also need to do things in parallel. We can't write:

```dart
  // wrong, effects will be executed in sequence
  var users = Result();
  yield Call(fetch, args: ['/users'], result: users);
  var repos = Result();
  yield Call(fetch, args: ['/repos'], result: repos);
```

Because the 2nd effect will not get executed until the first call resolves. Instead we have to write:

```dart
  // correct, effects will get executed in parallel
  var result = AllResult();
  yield All(
    {
      #users: Call(fetch, args: ['/users'], result: users),
      #repos: Call(fetch, args: ['/repos'], result: users),
    },
    result: result,
  );
```

When we yield an array of effects, the generator is blocked until all the effects are resolved or as soon as one is rejected (just like how `Future.wait` behaves).
