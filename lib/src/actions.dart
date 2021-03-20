part of redux_saga;

/// An optional base class/interface for actions
///
/// Since all actions are object instances then it might be useful to
/// inherit them from a single class. It may ease future changes.
class SagaAction {
  /// If the action was dispatched by a Saga an action if it implements [SagaAction]
  /// then the actions [dispatched] property is set to true
  bool dispatched = false;
}

/// [End] action class
///
/// Use [End] action to cancel takers waiting action from channel
/// via [Take] effect
class EndAction extends SagaAction {
  @override
  String toString() {
    return 'END';
  }
}

/// [End] action
///
/// Put this action to channel in order to cancel takers waiting
/// action via [Take] effect
final End = EndAction();

/// Checks whether an action is End action
bool isEnd(dynamic action) => identical(action, End);

/// Checks whether an action is dispatched by a Saga before
///
/// It only works for action types implementing [SagaAction]
bool isSagaDispatchedAction(dynamic action) =>
    (action is SagaAction) && (action.dispatched == true);
