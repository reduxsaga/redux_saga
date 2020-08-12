import 'package:redux/redux.dart';
import 'package:redux_saga/redux_saga.dart';

// Reducer method
// Changes state according to the actions dispatched
int counterReducer(int state, dynamic action) {
  if (action is IncrementAction) {
    return state + 1;
  } else if (action is DecrementAction) {
    return state - 1;
  }

  return state;
}

//Actions
class IncrementAction {}

class DecrementAction {}

class IncrementAsyncAction {}

//incrementAsync Saga increasing count delayed
Iterable incrementAsync() sync* {
  yield Delay(Duration(seconds: 1));
  yield Put(IncrementAction());
}

// counterSaga takes every IncrementAsyncAction
// action and forks incrementAsync
Iterable counterSaga() sync* {
  yield TakeEvery(incrementAsync, pattern: IncrementAsyncAction);
}

void main() {
  // create middleware
  var sagaMiddleware = createSagaMiddleware();

  // create store and apply middleware
  final store = Store<int>(
    counterReducer,
    initialState: 0,
    middleware: [applyMiddleware(sagaMiddleware)],
  );

  // attach store
  sagaMiddleware.setStore(store);

  // run root saga
  sagaMiddleware.run(counterSaga);

  //subscribe to the store
  store.onChange.listen(render);

  //dispatch some sample events
  store.dispatch(IncrementAction());
  store.dispatch(IncrementAction());
  store.dispatch(IncrementAction());

  store.dispatch(DecrementAction());

  store.dispatch(IncrementAsyncAction());

  // Output :
  // 1
  // 2
  // 3
  // 2
  // 2
  // 3
}

//this method may render the ui according to the store data
//now it is just printing to the console for every change
void render(int state) {
  print(state);
}
