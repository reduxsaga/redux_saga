part of redux_saga;

/// Defines function type which is invoked when a root saga is starts
///
/// [effectId] Unique ID assigned to this root saga execution
///
/// [saga] The generator function that starts to run
///
/// [args] The arguments passed to the generator function
typedef RootSagaStartedHandler = void Function(
    int effectId, Function saga, List<dynamic> args, Map<Symbol, dynamic> namedArgs);

/// Defines function type which is invoked when an effect triggered by the middleware
///
/// [effectId] Unique ID assigned to the yielded effect
///
/// [parentEffectId] ID of the parent Effect. In the case of a [Race] or
///   `parallel` effect, all effects yielded inside will have the direct
///   race/parallel effect as a parent. In case of a top-level effect, the
///   parent will be the containing Saga
///
/// [label] In case of a [Race]/[All] effect, all child effects will be
///   assigned as label the corresponding keys of the object passed to
///   [Race]/[All]
///
/// [effect] The yielded effect itself
typedef EffectTriggeredHandler = void Function(
    int effectId, int parentEffectId, dynamic label, dynamic effect);

/// Defines function type which is invoked when an effect is successfully resolved by the middleware
///
/// [effectId] The ID of the yielded effect
/// [result] The result of the successful resolution of the effect. In
/// case of [Fork] or [Spawn] effects, the result will be a [Task] object.
typedef EffectResolvedHandler = void Function(int effectId, dynamic result);

/// Defines function type which is invoked when an effect is rejected by the middleware
///
/// [effectId] The ID of the yielded effect
/// [error] Error raised with the rejection of the effect
typedef EffectRejectedHandler = void Function(int effectId, dynamic error);

/// Defines function type which is invoked when an effect is cancelled by the middleware
///
/// [effectId] The ID of the yielded effect
typedef EffectCancelledHandler = void Function(int effectId);

/// Defines function type which is invoked when a Redux action is dispatched
///
/// [action] The dispatched Redux action. If the action was dispatched by
/// a Saga and if action implements [SagaAction] then the actions [SagaAction.dispatched]
/// property is set to true
typedef ActionDispatchedHandler = void Function(dynamic action);

/// Used by the middleware to dispatch monitoring events. Actually the middleware
/// dispatches 6 events:
///
/// - When a root saga is started (via [SagaMiddleware.run]) the
///   middleware invokes [SagaMonitor.rootSagaStarted]
///
/// - When an effect is triggered (via `yield someEffect`) the middleware invokes
///   [SagaMonitor.effectTriggered]
///
/// - If the effect is resolved with success the middleware invokes
///   [SagaMonitor.effectResolved]
///
/// - If the effect is rejected with an error the middleware invokes
///   [SagaMonitor.effectRejected]
///
/// - If the effect is cancelled the middleware invokes
///   [SagaMonitor.effectCancelled]
///
/// - Finally, the middleware invokes [SagaMonitor.actionDispatched] when a Redux
///   action is dispatched.
///
/// Note : All events are attached to an empty function by default.
///
/// ### Example
///
/// ```
/// // create a monitor instance
/// var monitor = SagaMonitor();
///
/// // attach monitor events
/// // monitor.rootSagaStarted = ...
///
/// // pass the monitoring object to the middleware
/// var sagaMiddleware = createMiddleware(options: Options(sagaMonitor: monitor));
///
/// var store = createStore(sagaMiddleware);
///
/// sagaMiddleware.setStore(store);
/// ```
class SagaMonitor {
  /// Invoked when a root saga is started by the middleware
  RootSagaStartedHandler rootSagaStarted;

  /// Invoked when an effect is triggered by the middleware
  EffectTriggeredHandler effectTriggered;

  /// Invoked when an effect is successfully resolved by the middleware
  EffectResolvedHandler effectResolved;

  /// Invoked when an effect is rejected by the middleware
  EffectRejectedHandler effectRejected;

  /// Invoked when an effect is cancelled by the middleware
  EffectCancelledHandler effectCancelled;

  /// Invoked when a Redux action is dispatched
  ActionDispatchedHandler actionDispatched;

  /// Creates a saga monitor instance which
  /// should be given as an option to middleware creation
  SagaMonitor() {
    actionDispatched = (dynamic action) {};
    rootSagaStarted =
        (int effectId, Function saga, List<dynamic> args, Map<Symbol, dynamic> namedArgs) {};
    effectResolved = (int effectId, dynamic result) {};
    effectTriggered = (int effectId, int parentEffectId, dynamic label, dynamic effect) {};
    effectRejected = (int effectId, dynamic error) {};
    effectCancelled = (int effectId) {};
  }
}
