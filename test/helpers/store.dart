import 'dart:convert';
import 'package:redux/redux.dart';
import 'package:redux_saga/redux_saga.dart';

Store<AppState> createStore(SagaMiddleware middleware) {
  return Store<AppState>(
    appReducer,
    initialState: AppState.initial(),
    middleware: [
      applyMiddleware(middleware),
    ],
  );
}

class AppState {
  final int x;

  const AppState({this.x});

  factory AppState.initial() {
    return AppState(x: 0);
  }

  AppState copyWith({int x}) {
    return AppState(
      x: x ?? this.x,
    );
  }

  @override
  int get hashCode => x.hashCode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AppState && x == other.x;

  dynamic toJson() => {
        'x': x,
      };

  static AppState fromJson(dynamic json) {
    return json == null
        ? null
        : AppState(
            x: json['x'] as int,
          );
  }

  @override
  String toString() {
    return 'AppState: ${JsonEncoder.withIndent('  ').convert(this)}';
  }
}

class IncrementCounterAction {}

class DecrementCounterAction {}

AppState appReducer(AppState state, dynamic action) {
  return AppState(
    x: countersReducer(state.x, action),
  );
}

final countersReducer = combineReducers<int>([
  TypedReducer<int, IncrementCounterAction>(_incrementCounterReducer),
  TypedReducer<int, DecrementCounterAction>(_decrementCounterReducer),
]);

int _incrementCounterReducer(int state, IncrementCounterAction action) {
  return state + 1;
}

int _decrementCounterReducer(int state, DecrementCounterAction action) {
  return state - 1;
}

class EmptyState {}
