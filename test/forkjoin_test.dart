import 'dart:async';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/utils.dart';
import 'helpers/store.dart';

void main() {
  group('fork join tests', () {
    test('saga fork handling: generators', () {
      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      Iterable<Effect> subGen(dynamic arg) sync* {
        yield Call(() => Future(() => 1));
        yield Return(arg);
      }

      var inst = _C(2);

      var forkedTask = Result<Task>();
      var forkedTask2 = Result<Task>();

      var task = sagaMiddleware.run(() sync* {
        yield Fork(subGen,
            args: <dynamic>[1], name: 'subGen', result: forkedTask);
        yield Fork(inst.gen, result: forkedTask2);
      });

      expect(task.toFuture(), completion(null));

      //fork result must include the name of the forked effect name
      expect(forkedTask.value!.meta.name, equals('subGen'));

      //fork result must resolve with the return value of the forked task
      expect(forkedTask.value!.toFuture(), completion(1));

      //fork must also handle generators defined as instance methods
      expect(forkedTask2.value!.toFuture(), completion(2));
    });

    test('saga join handling : generators', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var comps = createArrayOfCompleters<dynamic>(2);

      Iterable<Effect> subGen(dynamic arg) sync* {
        yield Call(
            () => comps[1].future); // will be resolved after the action-1
        yield Return(arg);
      }

      var forkedTask = Result<Task>();

      Iterable<Effect> genFn() sync* {
        yield Fork(subGen, args: <dynamic>[1], result: forkedTask);

        var result = Result<dynamic>();
        yield Call(() => comps[0].future, result: result);
        actual.add(result.value);

        yield Take(pattern: TestActionA, result: result);
        actual.add(result.value);

        var joinResult = JoinResult();
        yield Join(<dynamic, Task>{#task: forkedTask.value!},
            result: joinResult);
        actual.add(joinResult.value);
      }

      var task = sagaMiddleware.run(genFn);

      var action = TestActionA(1);

      ResolveSequentially([
        callF(() => comps[0].complete(true)),
        callF(() => store.dispatch(action)),
        // the result of the fork will be resolved the last
        // saga must not block and miss the 2 precedent effects
        callF(() => comps[1].complete(2)),
      ]);

      // saga must not block on forked tasks, but block on joined tasks
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            true,
            action,
            {#task: 1}
          ]));
    });

    test('saga fork/join handling : functions', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var comps = createArrayOfCompleters<dynamic>(2);

      ResolveSequentially([
        callF(() => comps[0].complete(true)),
        callF(() => comps[1].complete(2)),
      ]);

      Future api() {
        return comps[1].future;
      }

      String syncFn() {
        return 'sync';
      }

      var forkedTask = Result<Task>();
      var forkedSyncTask = Result<Task>();

      Iterable<Effect> genFn() sync* {
        yield Fork(api, result: forkedTask);

        yield Fork(syncFn, result: forkedSyncTask);

        var result = Result<dynamic>();
        yield Call(() => comps[0].future, result: result);
        actual.add(result.value);

        var joinResult = JoinResult();
        yield Join(<dynamic, Task>{#task: forkedTask.value!},
            result: joinResult);
        actual.add(joinResult.value);

        yield Join(<dynamic, Task>{#task: forkedSyncTask.value!},
            result: joinResult);
        actual.add(joinResult.value);
      }

      var task = sagaMiddleware.run(genFn);

      // saga must not block on forked tasks, but block on joined tasks
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            true,
            {#task: 2},
            {#task: 'sync'},
          ]));
    });

    test('saga fork wait for attached children', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var rootComp = Completer<dynamic>();
      var childAComp = Completer<dynamic>();
      var childBComp = Completer<dynamic>();
      var comps = createArrayOfCompleters<dynamic>(4);

      ResolveSequentially([
        callF(() => childAComp.complete(true)),
        callF(() => rootComp.complete(true)),
        callF(() => comps[0].complete(true)),
        callF(() => childBComp.complete(true)),
        callF(() => comps[2].complete(true)),
        callF(() => comps[3].complete(true)),
        callF(() => comps[1].complete(true)),
      ]);

      Iterable<Effect> leaf(int idx) sync* {
        var result = Result<dynamic>();
        yield Call(() => comps[idx].future, result: result);
        actual.add(idx);
      }

      Iterable<Effect> childA() sync* {
        yield Fork(leaf, args: <dynamic>[0]);
        yield Call(() => childAComp.future);
        yield Fork(leaf, args: <dynamic>[1]);
      }

      Iterable<Effect> childB() sync* {
        yield Fork(leaf, args: <dynamic>[2]);
        yield Call(() => childBComp.future);
        yield Fork(leaf, args: <dynamic>[3]);
      }

      Iterable<Effect> root() sync* {
        yield Fork(childA);
        yield Call(() => rootComp.future);
        yield Fork(childB);
      }

      var task = sagaMiddleware.run(root);

      // parent task must wait for all forked tasks before terminating
      expect(task.toFuture().then((dynamic value) => actual),
          completion([0, 2, 3, 1]));
    });

    test('saga auto cancel forks on error', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var mainComp = Completer<dynamic>();
      var childAComp = Completer<dynamic>();
      var childBComp = Completer<dynamic>();
      var comps = createArrayOfCompleters<dynamic>(4);

      ResolveSequentially([
        callF(() => childAComp.complete('childA resolved')),
        callF(() => comps[0].complete('leaf 1 resolved')),
        callF(() => childBComp.complete('childB resolved')),
        callF(() => comps[1].complete('leaf 2 resolved')),
        callF(() => mainComp.completeError('main error')),
        callF(() => comps[2].complete('leaf 3 resolved')),
        callF(() => comps[3].complete('leaf 4 resolved')),
      ]);

      Iterable<Effect> leaf(int idx) sync* {
        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Call(() => comps[idx].future, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value!) {
            actual.add('leaf ${idx + 1} cancelled');
          }
        });
      }

      Iterable<Effect> childA() sync* {
        yield Try(() sync* {
          yield Fork(leaf, args: <dynamic>[0]);

          var result = Result<dynamic>();
          yield Call(() => childAComp.future, result: result);
          actual.add(result.value);

          yield Fork(leaf, args: <dynamic>[1]);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value!) {
            actual.add('childA cancelled');
          }
        });
      }

      Iterable<Effect> childB() sync* {
        yield Try(() sync* {
          yield Fork(leaf, args: <dynamic>[2]);
          yield Fork(leaf, args: <dynamic>[3]);

          var result = Result<dynamic>();
          yield Call(() => childBComp.future, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value!) {
            actual.add('childB cancelled');
          }
        });
      }

      Iterable<Effect> main() sync* {
        yield Try(() sync* {
          yield Fork(childA);
          yield Fork(childB);
          var result = Result<dynamic>();
          yield Call(() => mainComp.future, result: result);
          actual.add(result.value);
        }, Catch: (Object e, StackTrace s) sync* {
          actual.add(e);
          throw e;
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value!) {
            actual.add('main cancelled');
          }
        });
      }

      Iterable<Effect> root() sync* {
        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Call(main, result: result);
          actual.add(result.value);
        }, Catch: (dynamic e, StackTrace s) sync* {
          actual.add('root caught $e');
        });
      }

      var task = sagaMiddleware.run(root);

      // parent task must cancel all forked tasks when it aborts
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            'childA resolved',
            'leaf 1 resolved',
            'childB resolved',
            'leaf 2 resolved',
            'main error',
            'leaf 3 cancelled',
            'leaf 4 cancelled',
            'root caught main error'
          ]));
    });

    test('saga auto cancel forks on main cancelled', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var rootComp = Completer<dynamic>();
      var mainComp = Completer<dynamic>();
      var childAComp = Completer<dynamic>();
      var childBComp = Completer<dynamic>();
      var comps = createArrayOfCompleters<dynamic>(4);

      ResolveSequentially([
        callF(() => childAComp.complete('childA resolved')),
        callF(() => comps[0].complete('leaf 1 resolved')),
        callF(() => childBComp.complete('childB resolved')),
        callF(() => comps[1].complete('leaf 2 resolved')),
        callF(() => rootComp.complete('root resolved')),
        callF(() => mainComp.complete('main resolved')),
        callF(() => comps[2].complete('leaf 3 resolved')),
        callF(() => comps[3].complete('leaf 4 resolved')),
      ]);

      Iterable<Effect> leaf(int idx) sync* {
        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Call(() => comps[idx].future, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value!) {
            actual.add('leaf ${idx + 1} cancelled');
          }
        });
      }

      Iterable<Effect> childA() sync* {
        yield Try(() sync* {
          yield Fork(leaf, args: <dynamic>[0]);

          var result = Result<dynamic>();
          yield Call(() => childAComp.future, result: result);
          actual.add(result.value);

          yield Fork(leaf, args: <dynamic>[1]);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value!) {
            actual.add('childA cancelled');
          }
        });
      }

      Iterable<Effect> childB() sync* {
        yield Try(() sync* {
          yield Fork(leaf, args: <dynamic>[2]);
          yield Fork(leaf, args: <dynamic>[3]);

          var result = Result<dynamic>();
          yield Call(() => childBComp.future, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value!) {
            actual.add('childB cancelled');
          }
        });
      }

      Iterable<Effect> main() sync* {
        yield Try(() sync* {
          yield Fork(childA);
          yield Fork(childB);
          var result = Result<dynamic>();
          yield Call(() => mainComp.future, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value!) {
            actual.add('main cancelled');
          }
        });
      }

      Iterable<Effect> root() sync* {
        yield Try(() sync* {
          var forkedTask = Result<Task>();
          yield Fork(main, result: forkedTask);

          var result = Result<dynamic>();
          yield Call(() => rootComp.future, result: result);
          actual.add(result.value);

          yield Cancel([forkedTask.value!]);
        }, Catch: (dynamic e, StackTrace s) sync* {
          actual.add('root caught $e');
        });
      }

      var task = sagaMiddleware.run(root);

      // parent task must cancel all forked tasks when it's cancelled
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            'childA resolved',
            'leaf 1 resolved',
            'childB resolved',
            'leaf 2 resolved',
            'root resolved',
            'main cancelled',
            'leaf 3 cancelled',
            'leaf 4 cancelled',
          ]));
    });

    test('saga auto cancel forks if a child aborts', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var mainComp = Completer<dynamic>();
      var childAComp = Completer<dynamic>();
      var childBComp = Completer<dynamic>();
      var comps = createArrayOfCompleters<dynamic>(4);

      ResolveSequentially([
        callF(() => childAComp.complete('childA resolved')),
        callF(() => comps[0].complete('leaf 1 resolved')),
        callF(() => childBComp.complete('childB resolved')),
        callF(() => comps[1].complete('leaf 2 resolved')),
        callF(() => mainComp.complete('main resolved')),
        callF(() => comps[2].completeError('leaf 3 error')),
        callF(() => comps[3].complete('leaf 4 resolved')),
      ]);

      Iterable<Effect> leaf(int idx) sync* {
        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Call(() => comps[idx].future, result: result);
          actual.add(result.value);
        }, Catch: (Object e, StackTrace s) sync* {
          actual.add(e);
          throw e;
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value!) {
            actual.add('leaf ${idx + 1} cancelled');
          }
        });
      }

      Iterable<Effect> childA() sync* {
        yield Try(() sync* {
          yield Fork(leaf, args: <dynamic>[0]);

          var result = Result<dynamic>();
          yield Call(() => childAComp.future, result: result);
          actual.add(result.value);

          yield Fork(leaf, args: <dynamic>[1]);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value!) {
            actual.add('childA cancelled');
          }
        });
      }

      Iterable<Effect> childB() sync* {
        yield Try(() sync* {
          yield Fork(leaf, args: <dynamic>[2]);
          yield Fork(leaf, args: <dynamic>[3]);

          var result = Result<dynamic>();
          yield Call(() => childBComp.future, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value!) {
            actual.add('childB cancelled');
          }
        });
      }

      Iterable<Effect> main() sync* {
        yield Try(() sync* {
          yield Fork(childA);
          yield Fork(childB);
          var result = Result<dynamic>();
          yield Call(() => mainComp.future, result: result);
          actual.add(result.value);
          yield Return('main returned');
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value!) {
            actual.add('main cancelled');
          }
        });
      }

      Iterable<Effect> root() sync* {
        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Call(main, result: result);
          actual.add(result.value);
        }, Catch: (dynamic e, StackTrace s) sync* {
          actual.add('root caught $e');
        });
      }

      var task = sagaMiddleware.run(root);

      // parent task must cancel all forked tasks when it aborts
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            'childA resolved',
            'leaf 1 resolved',
            'childB resolved',
            'leaf 2 resolved',
            'main resolved',
            'leaf 3 error',
            'leaf 4 cancelled',
            'root caught leaf 3 error',
          ]));
    });

    test('saga auto cancel parent + forks if a child aborts', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var mainComp = Completer<dynamic>();
      var childAComp = Completer<dynamic>();
      var childBComp = Completer<dynamic>();
      var comps = createArrayOfCompleters<dynamic>(4);

      ResolveSequentially([
        callF(() => childAComp.complete('childA resolved')),
        callF(() => comps[0].complete('leaf 1 resolved')),
        callF(() => childBComp.complete('childB resolved')),
        callF(() => comps[1].complete('leaf 2 resolved')),
        callF(() => comps[2].completeError('leaf 3 error')),
        callF(() => mainComp.complete('main resolved')),
        callF(() => comps[3].complete('leaf 4 resolved')),
      ]);

      Iterable<Effect> leaf(int idx) sync* {
        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Call(() => comps[idx].future, result: result);
          actual.add(result.value);
        }, Catch: (Object e, StackTrace s) sync* {
          actual.add(e);
          throw e;
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value!) {
            actual.add('leaf ${idx + 1} cancelled');
          }
        });
      }

      Iterable<Effect> childA() sync* {
        yield Try(() sync* {
          yield Fork(leaf, args: <dynamic>[0]);

          var result = Result<dynamic>();
          yield Call(() => childAComp.future, result: result);
          actual.add(result.value);

          yield Fork(leaf, args: <dynamic>[1]);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value!) {
            actual.add('childA cancelled');
          }
        });
      }

      Iterable<Effect> childB() sync* {
        yield Try(() sync* {
          yield Fork(leaf, args: <dynamic>[2]);
          yield Fork(leaf, args: <dynamic>[3]);

          var result = Result<dynamic>();
          yield Call(() => childBComp.future, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value!) {
            actual.add('childB cancelled');
          }
        });
      }

      Iterable<Effect> main() sync* {
        yield Try(() sync* {
          yield Fork(childA);
          yield Fork(childB);
          var result = Result<dynamic>();
          yield Call(() => mainComp.future, result: result);
          actual.add(result.value);
          yield Return('main returned');
        }, Catch: (Object e, StackTrace s) sync* {
          actual.add(e);
          throw e;
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value!) {
            actual.add('main cancelled');
          }
        });
      }

      Iterable<Effect> root() sync* {
        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Call(main, result: result);
          actual.add(result.value);
        }, Catch: (dynamic e, StackTrace s) sync* {
          actual.add('root caught $e');
        });
      }

      var task = sagaMiddleware.run(root);

      // parent task must cancel all forked tasks when it aborts
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            'childA resolved',
            'leaf 1 resolved',
            'childB resolved',
            'leaf 2 resolved',
            'leaf 3 error',
            'leaf 4 cancelled',
            'main cancelled',
            'root caught leaf 3 error',
          ]));
    });

    test('joining multiple tasks', () {
      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var comps = createArrayOfCompleters<dynamic>(3);

      Iterable<Effect> worker(int i) sync* {
        yield Return(comps[i].future);
      }

      var actual = JoinResult();

      Iterable<Effect> root() sync* {
        var task1 = Result<Task>();
        yield Fork(worker, args: <dynamic>[0], result: task1);

        var task2 = Result<Task>();
        yield Fork(worker, args: <dynamic>[1], result: task2);

        var task3 = Result<Task>();
        yield Fork(worker, args: <dynamic>[2], result: task3);

        yield Join(<dynamic, Task>{
          #task1: task1.value!,
          #task2: task2.value!,
          #task3: task3.value!
        }, result: actual);
      }

      var task = sagaMiddleware.run(root);

      ResolveSequentially([
        callF(() => comps[0].complete(1)),
        callF(() => comps[2].complete(3)),
        callF(() => comps[1].complete(2)),
      ]);

      // it must be possible to join on multiple tasks
      expect(task.toFuture().then((dynamic value) => actual.value),
          completion({#task1: 1, #task2: 2, #task3: 3}));
    });
  });
}

class _C {
  dynamic val;

  _C(this.val);

  Iterable<Effect> gen() sync* {
    yield Return(val);
  }
}
