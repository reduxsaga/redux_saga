import 'dart:async';
import 'package:redux_saga/redux_saga.dart';
import 'store.dart';

final exceptionToBeCaught = Exception('exceptionToBeCaught');
final exceptionToBeCaught2 = Exception('exceptionToBeCaught2');

class SampleTestObject {
  String name;

  SampleTestObject(this.name);

  @override
  String toString() {
    return name;
  }
}

final value1 = SampleTestObject('Value1');
final value2 = SampleTestObject('Value2');
final value3 = SampleTestObject('Value3');

SagaMiddleware createMiddleware({Options options}) {
  var sagaMiddleware = createSagaMiddleware(
    options ?? Options(onError: (dynamic e, String s) {}), //don't log errors to console
  );
  return sagaMiddleware;
}

class SampleAPI {
  int currentId = 0;

  SampleAPI([int currentId = 0]) {
    this.currentId = currentId;
  }

  void increase() {
    currentId++;
  }

  int getId() {
    return currentId;
  }
}

class TestActionA {
  final int payload;

  TestActionA(this.payload);

  @override
  String toString() {
    return '$payload';
  }
}

class TestActionB {
  final int payload;

  TestActionB(this.payload);

  @override
  String toString() {
    return '$payload';
  }
}

class TestActionC {
  final String payload;

  TestActionC(this.payload);

  @override
  String toString() {
    return '$payload';
  }
}

class TestActionD {
  final dynamic payload;

  TestActionD(this.payload);

  @override
  String toString() {
    return '$payload';
  }
}

class TestActionCancel {
  @override
  String toString() {
    return '$runtimeType';
  }
}

int selectCounter(AppState state) {
  return state.x;
}

void testCPS1(List<int> execution, {CPSCallback cb}) {
  execution.add(1);
  cb.cancel = () {};
  cb.callback(res: value1);
}

void testCPS2(List<int> execution, {CPSCallback cb}) {
  execution.add(1);
  var c = Completer<dynamic>();
  cb.cancel = () {
    c.complete(null);
  };

  cb.callback(res: c.future);

  Future.delayed(Duration(milliseconds: 1), () => c.complete(value1));
}

void testCPS3(List<int> execution, {CPSCallback cb}) {
  execution.add(2);

  //this timer will be cancelled
  var timer = Timer(Duration(seconds: 1), () {
    execution.add(5);
    cb.callback(res: value1);
  });

  cb.cancel = () {
    execution.add(4);
    timer.cancel();
  };
}

List<Completer<T>> createArrayOfCompleters<T>(int length) {
  var list = List<Completer<T>>(length);
  for (var i = 0; i < length; i++) {
    list[i] = Completer<T>();
  }
  return list;
}

//returns a call back returning a future delayed
Function delayF(int milliseconds) {
  return () => Future<void>.delayed(Duration(milliseconds: milliseconds));
}

//returns a call back returning a future executing specified function
Function callF(Function f) {
  return () => Future<void>(() => f());
}

///Runs all future returning callbacks chained
Future ResolveSequentially(List<Function> functions) {
  Future f = Future<void>.sync(() => null);
  functions.forEach((x) {
    f = f.then<dynamic>((dynamic v) => x());
  });
  return f;
}
