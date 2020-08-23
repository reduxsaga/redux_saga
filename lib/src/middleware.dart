part of redux_saga;

/// Handler to dispatch actions to store
///
/// [action] argument provided by the Saga to the [Put] Effect
typedef DispatchHandler = dynamic Function(dynamic action);

/// Handler to get store state
typedef GetStateHandler = dynamic Function();

/// Middleware class that runs Sagas. It is an abstract class. To instantiate a middleware
/// use [createSagaMiddleware] helper function.
abstract class SagaMiddleware {
  /// Dynamically run `saga`. Can be used to run Sagas **only after** the
  /// [applyMiddleware] and [SagaMiddleware.setStore] phase.
  ///
  /// The method returns a [Task] descriptor.
  ///
  /// #### Notes
  ///
  /// `saga` must be a [synchronous generator function](https://dart.dev/guides/language/language-tour#generators)
  /// which returns a [Iterable] object.
  /// The middleware will then iterate over the Generator and execute all yielded
  /// Effects.
  ///
  /// `saga` may also start other sagas using the various Effects provided by the
  /// library. The iteration process described below is also applied to all child
  /// sagas.
  ///
  /// In the first iteration, the middleware invokes the `moveNext()` method to
  /// retrieve the next Effect. The middleware then executes the yielded Effect
  /// as specified by the Effects API below. Meanwhile, the Generator will be
  /// suspended until the effect execution terminates. Upon receiving the result
  /// of the execution, the middleware calls `moveNext()` again. This process is repeated
  /// until the Generator terminates normally or by throwing some error.
  ///
  /// If the execution results in an error (as specified by each Effect creator)
  /// then the `Catch` method is called instead. If the
  /// Generator function defines a `Try/Catch` surrounding the current yield
  /// instruction, then the `Catch` block will be invoked by the underlying
  /// Generator runtime. The runtime will also invoke any corresponding Finally
  /// block.
  ///
  /// In the case a Saga is cancelled (either manually or using the provided
  /// Effects), the middleware will stop execution of the Generator function.
  /// This will cause the Generator to skip directly to the finally block.
  ///
  /// [saga] is  a Generator function with the return type of [Iterable]
  ///
  /// If it is required arguments [args] and [namedArgs] can be provided to [saga].
  /// Unhandled errors can be caught by [Catch].
  ///
  /// If provided [Finally] will be invoked before stopping execution of [saga]
  ///
  /// Both [Catch] and [Finally] can be either a saga generator or sync/async function
  ///
  /// An optional [name] can be provided in order to ease trace/debug operations
  Task run(Function saga,
      {List<dynamic> args,
      Map<Symbol, dynamic> namedArgs,
      Function Catch,
      Function Finally,
      String name});

  /// Extends middlewares default context with the provided [context]
  void setContext(Map<dynamic, dynamic> context);

  /// Sets middleware store. It must be set right after [applyMiddleware].
  void setStore(Store value);

  /// Used to fulfill [Put] effects.
  ///
  /// This method can be set a fake method in order to handle tests
  DispatchHandler dispatch;

  /// Used to fulfill [Select] effects
  ///
  /// This method can be set a fake method in order to handle tests
  GetStateHandler getState;
}

class _SagaMiddleware extends SagaMiddleware {
  SagaContext context;
  Channel channel;
  SagaMonitor sagaMonitor;
  OnErrorHandler onError;
  List<EffectMiddlewareHandler> effectMiddlewares;
  _UniqueId uniqueId = _UniqueId();
  bool connectedToStore = false;

  _SagaMiddleware([Options options]) {
    context = options == null ? SagaContext() : SagaContext(options.context);
    channel = options == null || options.channel == null
        ? StdChannel()
        : options.channel;
    sagaMonitor = options == null ? null : options.sagaMonitor;
    onError = options == null || options.onError == null
        ? (_isDebugMode ? _logError : _logErrorEmpty)
        : options.onError;
    effectMiddlewares = options == null ? null : options.effectMiddlewares;
  }

  bool get monitoring => sagaMonitor != null;

  final errorStack = _SagaErrorStack();

  @override
  Task run(Function saga,
      {List<dynamic> args,
      Map<Symbol, dynamic> namedArgs,
      Function Catch,
      Function Finally,
      String name}) {
    if (!connectedToStore) throw SagaMustBeConnectedToTheStore();
    if (_store == null) throw SagaStoreMustBeSet();
    if (dispatch == null) throw SagaMiddlewareDispatchMustBeSet();
    if (getState == null) throw SagaMiddlewareGetStateMustBeSet();
    if (saga == null) throw SagaFunctionMustBeNonNullException();

    dynamic result = _callFunction(saga, args, namedArgs);

    Iterator iterator;

    if (result is Iterable) {
      iterator = result.iterator;
    } else {
      throw SagaFunctionMustBeGeneratorException();
    }

    final effectId = uniqueId.nextSagaId();

    if (monitoring) {
      sagaMonitor.rootSagaStarted(effectId, saga, args, namedArgs, 'root');
    }

    return immediately(() {
      var task = _createTask(context, iterator, Catch, Finally, effectId,
          SagaMeta(name, effectId), true, null);

      if (monitoring) {
        sagaMonitor.effectResolved(effectId, task);
      }

      return task;
    });
  }

  _RunEffectFinalizer getRunEffectFinalizer() {
    if (effectMiddlewares == null) {
      return (f) => f;
    } else {
      var composedMiddleware = getComposedMiddleware();
      return (_RunEffectHandler runEffect) {
        return (dynamic effect, int effectId, _TaskCallback currCb) {
          var plainRunEffect =
              (dynamic eff) => runEffect(eff, effectId, currCb);
          composedMiddleware(effect, plainRunEffect);
        };
      };
    }
  }

  EffectMiddlewareHandler getComposedMiddleware() {
    EffectMiddlewareHandler composedMiddleware;
    effectMiddlewares.reversed.forEach((EffectMiddlewareHandler middleware) {
      var currentDispatcher = composedMiddleware;
      composedMiddleware = currentDispatcher == null
          ? (dynamic effect, NextMiddlewareHandler runEffect) =>
              middleware(effect, runEffect)
          : (dynamic effect, NextMiddlewareHandler runEffect) => middleware(
              effect, (dynamic effect) => currentDispatcher(effect, runEffect));
    });
    return composedMiddleware;
  }

  @override
  void setContext(Map<dynamic, dynamic> context) {
    this.context._extend(context);
  }

  void put(dynamic action) {
    if (sagaMonitor != null && sagaMonitor.actionDispatched != null) {
      sagaMonitor.actionDispatched(action);
    }
    channel.put(action);
  }

  Store _store;

  @override
  void setStore(Store value) {
    if (value == null) throw SagaStoreCanNotBeNull();
    _store = value;
    dispatch = _dispatch;
    getState = _getState;
  }

  dynamic _getState() {
    return _store.state;
  }

  dynamic _dispatch(dynamic action) {
    if (action is SagaAction) {
      action.dispatched = true;
    }
    return _store.dispatch(action);
  }

  Task _createTask(
      SagaContext parentContext,
      Iterator iterator,
      Function onError,
      Function onFinally,
      int parentEffectId,
      SagaMeta meta,
      bool isRoot,
      _TaskCallback continueCallback) {
    var runner = _taskRunner(this, parentContext, iterator, onError, onFinally,
        parentEffectId, meta, isRoot, continueCallback);
    return runner.createTask();
  }
}
