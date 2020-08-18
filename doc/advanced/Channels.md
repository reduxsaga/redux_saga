# Using Channels

Until now we've used the `Take` and `Put` effects to communicate with the Redux Store. Channels generalize those Effects to communicate with external event sources or between Sagas themselves. They can also be used to queue specific actions from the Store.

In this section, we'll see:

- How to use the `yield ActionChannel` Effect to buffer specific actions from the Store.

- How to use the `EventChannel` factory function to connect `Take` Effects to external event sources.

- How to create a channel using the generic `Channel` type and use it in `Take`/`Put` Effects to communicate between two Sagas.

## Using the `ActionChannel` Effect

Let's review the canonical example:

```dart
watchRequests() sync* {
  while (true) {
    var result = Result();
    yield Take(pattern: Request, result: result);
    yield Fork(handleRequest, args: [result.value.payload]);
  }
}

handleRequest(payload) sync* {
  ...
}
```

The above example illustrates the typical *watch-and-fork* pattern. The `watchRequests` saga is using `fork` to avoid blocking and thus not missing any action from the store. A `handleRequest` task is created on each `Request` action. So if there are many actions fired at a rapid rate there can be many `handleRequest` tasks executing concurrently.

Imagine now that our requirement is as follows: we want to process `Request` serially. If we have at any moment four actions, we want to handle the first `Request` action, then only after finishing this action we process the second action and so on...

So we want to *queue* all non-processed actions, and once we're done with processing the current request, we get the next message from the queue.

redux_saga provides a little helper Effect `ActionChannel`, which can handle this for us. Let's see how we can rewrite the previous example with it:

```dart
watchRequests() sync* {
  // 1- Create a channel for request actions
  var resultChannel = Result<Channel>();
  yield ActionChannel(Request, result: resultChannel);
  var requestChan = resultChannel.value;
  while (true) {
    // 2- take from the channel
    var result = Result();
    yield Take(channel: requestChan, result: result);
    // 3- Note that we're using a blocking call
    yield Call(handleRequest, args: [result.value.payload]);
  }
}

handleRequest(payload) sync* {
  ...
}
```

The first thing is to create the action channel. We use `yield ActionChannel(pattern)` where pattern is interpreted using the same rules we mentioned previously with `Take(pattern)`. The difference between the 2 forms is that `ActionChannel` **can buffer incoming messages** if the Saga is not yet ready to take them (e.g. blocked on an API call).

Next is the `yield Take(requestChan)`. Besides usage with a `pattern` to take specific actions from the Redux Store, `Take` can also be used with channels (above we created a channel object from specific Redux actions). The `Take` will block the Saga until a message is available on the channel. The take may also resume immediately if there is a message stored in the underlying buffer.

The important thing to note is how we're using a blocking `Call`. The Saga will remain blocked until `Call(handleRequest)` returns. But meanwhile, if other `Request` actions are dispatched while the Saga is still blocked, they will queued internally by `requestChan`. When the Saga resumes from `Call(handleRequest)` and executes the next `yield Take(requestChan)`, the take will resolve with the queued message.

By default, `ActionChannel` buffers all incoming messages without limit. If you want a more control over the buffering, you can supply a Buffer argument to the effect creator. redux_saga provides some common buffers (none, dropping, sliding) but you can also supply your own buffer implementation. [See API docs](https://pub.dev/documentation/redux_saga/latest/redux_saga/Buffers-class.html) for more details.

For example if you want to handle only the most recent five items you can use:

```dart
watchRequests() sync* {
  var requestChan = Result();
  yield ActionChannel(Request, buffer: Buffers.sliding(5), result: requestChan);
  ...
}
```

## Using the `EventChannel` factory to connect to external events

Like `ActionChannel` (Effect), `EventChannel` (a factory function, not an Effect) creates a Channel for events but from event sources other than the Redux Store.

This basic example creates a Channel from an interval:

```dart
  EventChannel countdown(int secs) {
    return EventChannel(subscribe: (emitter) {
      var v = secs;
      var timer = Timer.periodic(Duration(seconds: 1), (timer) {
        v--;
        if (v > 0) {
          emitter(v);
        } else {
          emitter(End);
        } // this causes the channel to close
      });

      // The subscriber must return an unsubscribe function
      return () => timer.cancel();
    });
  }

  saga() sync* {
    var value = 10;
    var channel = Result<EventChannel>();

    yield Call(countdown, args: [value], result: channel);

    yield Try(() sync* {
      while (true) {
        // Take(pattern:End) will cause the saga to terminate
        // by jumping to the finally block
        var seconds = Result();
        yield Take(channel: channel.value, result: seconds);
        print('countdown: ${seconds.value}');
      }
    }, Finally: () sync* {
      print('countdown terminated');
    });
  }
```

The first argument in `EventChannel` is a *subscriber* function. The role of the subscriber is to initialize the external event source (above using `Timer.periodic`), then routes all incoming events from the source to the channel by invoking the supplied `emitter`. In the above example we're invoking `emitter` on each second.

> Note: You need to sanitize your event sources as to not pass null through the event channel. While it's fine to pass numbers through, we'd recommend structuring your event channel data like your redux actions.

Note also the invocation `emitter(End)`. We use this to notify any channel consumer that the channel has been closed, meaning no other messages will come through this channel.

Let's see how we can use this channel from our Saga.

```dart
  EventChannel countdown(int secs) {
    ...
  }

  saga() sync* {
    var value = 10;
    var channel = Result<EventChannel>();

    yield Call(countdown, args: [value], result: channel);

    yield Try(() sync* {
      while (true) {
        // Take(pattern:End) will cause the saga to terminate
        // by jumping to the finally block
        var seconds = Result();
        yield Take(channel: channel.value, result: seconds);
        print('countdown: ${seconds.value}');
      }
    }, Finally: () sync* {
      print('countdown terminated');
    });
  }
```

So the Saga is yielding a `Take(chan)`. This causes the Saga to block until a message is put on the channel. In our example above, it corresponds to when we invoke `emitter(secs)`. Note also we're executing the whole `while (true) {...}` loop inside a `Try/Finally` effect block. When the interval terminates, the countdown function closes the event channel by invoking `emitter(End)`. Closing a channel has the effect of terminating all Sagas blocked on a `Take` from that channel. In our example, terminating the Saga will cause it to jump to its `Finally` block (if provided, otherwise the Saga terminates).

The subscriber returns an `unsubscribe` function. This is used by the channel to unsubscribe before the event source complete. Inside a Saga consuming messages from an event channel, if we want to *exit early* before the event source complete (e.g. Saga has been cancelled) you can call `chan.close()` to close the channel and unsubscribe from the source.

For example, we can make our Saga support cancellation:

```dart
//creates an event Channel from an interval of seconds
EventChannel countdown(int secs) {
  ...
}

saga() sync* {
  var value = 10;
  var channel = Result<EventChannel>();

  yield Call(countdown, args: [value], result: channel);

  yield Try(() sync* {
    while (true) {
      // Take(pattern:End) will cause the saga to terminate
      // by jumping to the finally block
      var seconds = Result();
      yield Take(channel: channel.value, result: seconds);
      print('countdown: ${seconds.value}');
    }
  }, Finally: () sync* {
    var cancelled = Result<bool>();
    yield Cancelled(result: cancelled);
    if (cancelled.value) {
      channel.value.close();
      print('countdown cancelled');
    }
  });
}
```

### Using channels to communicate between Sagas

Besides action channels and event channels. You can also directly create channels which are not connected to any source by default. You can then manually `Put` on the channel. This is handy when you want to use a channel to communicate between sagas.

To illustrate, let's review the former example of request handling.

```dart
watchRequests() sync* {
  while (true) {
    var result = Result();
    yield Take(pattern: Request, result: result);
    yield Fork(handleRequest, args: [result.value.payload]);
  }
}

handleRequest(payload) sync* {
  ...
}
```

We saw that the watch-and-fork pattern allows handling multiple requests simultaneously, without limit on the number of worker tasks executing concurrently. Then, we used the `ActionChannel` effect to limit the concurrency to one task at a time.

So let's say that our requirement is to have a maximum of three tasks executing at the same time. When we get a request and there are less than three tasks executing, we process the request immediately, otherwise we queue the task and wait for one of the three *slots* to become free.

Below is an example of a solution using channels:

```dart
watchRequests() sync* {
  // create a channel to queue incoming requests
  var chan = Result<Channel>();
  yield Call(channel, result: chan);

  // create 3 worker 'threads'
  for (var i = 0; i < 3; i++) {
    yield Fork(handleRequest, args: [chan.value]);
  }

  while (true) {
    var result = Result();
    yield Take(pattern: Request, result: result);
    yield Put(result.value, channel: chan.value);
  }
}

handleRequest(Channel chan) sync* {
  while (true) {
    var result = Result();
    yield Take(channel: chan, result: result);
    // process the request
  }
}
```

In the above example, we create a channel using the `channel` factory. We get back a channel which by default buffers all messages we put on it (unless there is a pending taker, in which the taker is resumed immediately with the message).

The `watchRequests` saga then forks three worker sagas. Note the created channel is supplied to all forked sagas. `watchRequests` will use this channel to *dispatch* work to the three worker sagas. On each `Request` action the Saga will put the payload on the channel. The payload will then be taken by any *free* worker. Otherwise it will be queued by the channel until a worker Saga is ready to take it.

All the three workers run a typical while loop. On each iteration, a worker will take the next request, or will block until a message is available. Note that this mechanism provides an automatic load-balancing between the 3 workers. Rapid workers are not slowed down by slow workers.
