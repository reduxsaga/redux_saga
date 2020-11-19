import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/utils.dart';
import 'helpers/store.dart';

void main() {
  group('cancellation', () {
    test('saga cancellation: call effect', () {
      var actual = <dynamic>[];

      var startComp = Completer<String>();
      var cancelComp = Completer<String>();
      var subroutineComp = Completer<String>();

      ResolveSequentially([
        callF(() => startComp.complete('start')),
        callF(() => cancelComp.complete('cancel')),
        callF(() => subroutineComp.complete('subroutine'))
      ]);

      Iterable<Effect> subroutine() sync* {
        var result = Result<dynamic>();
        yield Call(() => 'subroutine start', result: result);
        actual.add(result.value);

        yield Try(() sync* {
          yield Call(() => subroutineComp.future, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            yield Call(() => 'subroutine cancelled', result: result);
            actual.add(result.value);
          }
        });
      }

      Iterable<Effect> main() sync* {
        var result = Result<dynamic>();
        yield Call(() => startComp.future, result: result);
        actual.add(result.value);

        yield Try(() sync* {
          yield Call(subroutine, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            yield Call(() => 'cancelled', result: result);
            actual.add(result.value);
          }
        });
      }

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(main);

      cancelComp.future.then((dynamic value) {
        actual.add(value);
        task.cancel();
      });

      expect(task.toFuture(), completion(TaskCancel));

      //cancelled call effect must throw exception inside called subroutine
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            'start',
            'subroutine start',
            'cancel',
            'subroutine cancelled',
            'cancelled'
          ]));
    });

    test('saga cancellation: forked children', () {
      var actual = <dynamic>[];

      var cancelComp = Completer<String>();
      var rootComp = Completer<String>();
      var childAComp = Completer<String>();
      var childBComp = Completer<String>();
      var neverComp = Completer<String>();
      var Comps = createArrayOfCompleters<String>(4);

      ResolveSequentially([
        callF(() => childAComp.complete('childA resolve')),
        callF(() => rootComp.complete('root resolve')),
        callF(() => Comps[0].complete('leaf 0 resolve')),
        callF(() => childBComp.complete('childB resolve')),
        callF(() => cancelComp.complete('cancel')),
        callF(() => Comps[3].complete('leaf 3 resolve')),
        callF(() => Comps[2].complete('leaf 2 resolve')),
        callF(() => Comps[1].complete('leaf 1 resolve')),
      ]);

      Iterable<Effect> leaf(int idx) sync* {
        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Call(() => Comps[idx].future, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('leaf $idx cancelled');
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

          yield Call(() => neverComp.future);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('childA cancelled');
          }
        });
      }

      Iterable<Effect> childB() sync* {
        yield Try(() sync* {
          yield Fork(leaf, args: <dynamic>[2]);

          var result = Result<dynamic>();
          yield Call(() => childBComp.future, result: result);
          actual.add(result.value);

          yield Fork(leaf, args: <dynamic>[3]);

          yield Call(() => neverComp.future);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('childB cancelled');
          }
        });
      }

      Iterable<Effect> main() sync* {
        yield Try(() sync* {
          yield Fork(childA);

          var resultA = Result<dynamic>();
          yield Call(() => rootComp.future, result: resultA);
          actual.add(resultA.value);

          yield Fork(childB);

          var resultB = Result<dynamic>();
          yield Call(() => neverComp.future, result: resultB);
          actual.add(resultB.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('main cancelled');
          }
        });
      }

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(main);

      cancelComp.future.then((dynamic value) {
        task.cancel();
      });

      expect(task.toFuture(), completion(TaskCancel));

      //cancelled main task must cancel all forked sub-tasks
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            'childA resolve',
            'root resolve',
            'leaf 0 resolve',
            'childB resolve',
            //cancel
            'main cancelled',
            'childA cancelled',
            'leaf 1 cancelled',
            'childB cancelled',
            'leaf 2 cancelled',
            'leaf 3 cancelled',
          ]));
    });

    test('saga cancellation: take effect', () {
      var actual = <dynamic>[];

      var startComp = Completer<String>();
      var cancelComp = Completer<String>();

      Iterable<Effect> main() sync* {
        var result = Result<dynamic>();
        yield Call(() => startComp.future, result: result);
        actual.add(result.value);

        yield Try(() sync* {
          yield Take(pattern: TestActionA);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('cancelled');
          }
        });
      }

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(main);

      cancelComp.future.then((dynamic value) {
        actual.add(value);
        task.cancel();
      });

      ResolveSequentially([
        callF(() => startComp.complete('start')),
        callF(() => cancelComp.complete('cancel')),
        callF(() => store.dispatch(TestActionA(0))),
      ]);

      expect(task.toFuture(), completion(TaskCancel));

      //cancelled take effect must stop waiting for action
      expect(task.toFuture().then((dynamic value) => actual),
          completion(['start', 'cancel', 'cancelled']));
    });

    test('saga cancellation: join effect (joining from a different task)', () {
      var actual = <dynamic>[];

      var cancelComp = Completer<String>();
      var subroutineComp = Completer<String>();

      ResolveSequentially([
        callF(() => cancelComp.complete('cancel')),
        callF(() => subroutineComp.complete('subroutine')),
      ]);

      Iterable<Effect> subroutine() sync* {
        actual.add('subroutine start');

        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Call(() => subroutineComp.future, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('subroutine cancelled');
          }
        });
      }

      Iterable<Effect> joiner1(Task task) sync* {
        actual.add('joiner1 start');

        yield Try(() sync* {
          var jr = JoinResult();
          yield Join(<dynamic, Task>{#task: task}, result: jr);
          actual.add(jr.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('joiner1 cancelled');
          }
        });
      }

      Iterable<Effect> joiner2(Task task) sync* {
        actual.add('joiner2 start');

        yield Try(() sync* {
          var jr = JoinResult();
          yield Join(<dynamic, Task>{#task: task}, result: jr);
          actual.add(jr.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('joiner2 cancelled');
          }
        });
      }

      Iterable<Effect> callerOfJoiner1(Task task) sync* {
        yield Try(() sync* {
          var result = AllResult();
          yield All(<dynamic, Effect>{
            #call: Call(joiner1, args: <dynamic>[task]),
            #future: Call(() => Future<void>(() {}))
          }, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('caller of joiner1 cancelled');
          }
        });
      }

      Iterable<Effect> main() sync* {
        actual.add('start');
        var task = Result<Task>();
        yield Fork(subroutine, result: task);

        yield Fork(callerOfJoiner1, args: <dynamic>[task.value]);

        yield Fork(joiner2, args: <dynamic>[task.value]);

        var result = Result<dynamic>();
        yield Call(() => cancelComp.future, result: result);
        actual.add(result.value);

        yield Cancel([task.value]);
      }

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(main);

      expect(task.toFuture(), completion(null));

      //cancelled task must cancel foreign joiners
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            'start',
            'subroutine start',
            'joiner1 start',
            'joiner2 start',
            'cancel',
            'subroutine cancelled',
            'joiner1 cancelled',
            'caller of joiner1 cancelled',
            'joiner2 cancelled',
          ]));
    });

    test('saga cancellation: join effect (join from the same task\'s parent)',
        () {
      var actual = <dynamic>[];

      var startComp = Completer<String>();
      var cancelComp = Completer<String>();
      var subroutineComp = Completer<String>();

      ResolveSequentially([
        callF(() => startComp.complete('start')),
        callF(() => cancelComp.complete('cancel')),
        callF(() => subroutineComp.complete('subroutine')),
      ]);

      Iterable<Effect> subroutine() sync* {
        actual.add('subroutine start');

        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Call(() => subroutineComp.future, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('subroutine cancelled');
          }
        });
      }

      Iterable<Effect> main() sync* {
        var result = Result<dynamic>();
        yield Call(() => startComp.future, result: result);
        actual.add(result.value);

        var task = Result<Task>();
        yield Fork(subroutine, result: task);

        yield Try(() sync* {
          var jr = JoinResult();
          yield Join(<dynamic, Task>{#task: task.value}, result: jr);
          actual.add(jr.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('cancelled');
          }
        });
      }

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(main);

      cancelComp.future.then((dynamic value) {
        actual.add(value);
        task.cancel();
      });

      expect(task.toFuture(), completion(TaskCancel));

      //Since now attached forks are cancelled when their parent is cancelled
      //cancellation of main will trigger in order: 1. cancel parent (main) 2. then cancel children (subroutine)
      //Join cancellation has the following semantics: cancellation of a task triggers cancellation of all its
      //joiners (similar to future1.then(future2): future2 depends on future1, if future1 is cancelled,
      //then so future2 must be cancelled).
      //In the present test, main is joining on of its proper children, so this would cause an endless loop, but
      //since cancellation is noop on an already terminated task the deadlock wont happen

      //cancelled routine must cancel proper joiners
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            'start',
            'subroutine start',
            'cancel',
            'cancelled',
            'subroutine cancelled'
          ]));
    });

    test('saga cancellation: parallel effect', () {
      var actual = <dynamic>[];

      var startComp = Completer<String>();
      var cancelComp = Completer<String>();
      var subroutineComps = createArrayOfCompleters<String>(2);

      ResolveSequentially([
        callF(() => startComp.complete('start')),
        callF(() => subroutineComps[0].complete('subroutine 1')),
        callF(() => cancelComp.complete('cancel')),
        callF(() => subroutineComps[1].complete('subroutine 2')),
      ]);

      Iterable<Effect> subroutine1() sync* {
        actual.add('subroutine 1 start');

        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Call(() => subroutineComps[0].future, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('subroutine 1 cancelled');
          }
        });
      }

      Iterable<Effect> subroutine2() sync* {
        actual.add('subroutine 2 start');

        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Call(() => subroutineComps[1].future, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('subroutine 2 cancelled');
          }
        });
      }

      Iterable<Effect> main() sync* {
        var result = Result<dynamic>();
        yield Call(() => startComp.future, result: result);
        actual.add(result.value);

        yield Try(() sync* {
          var all = AllResult();
          yield All(<dynamic, Effect>{
            #call1: Call(subroutine1),
            #call2: Call(subroutine2)
          }, result: all);
          actual.add(all.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('cancelled');
          }
        });
      }

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(main);

      cancelComp.future.then((dynamic value) {
        actual.add(value);
        task.cancel();
      });

      expect(task.toFuture(), completion(TaskCancel));

      //cancelled parallel effect must cancel all sub-effects
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            'start',
            'subroutine 1 start',
            'subroutine 2 start',
            'subroutine 1',
            'cancel',
            'subroutine 2 cancelled',
            'cancelled'
          ]));
    });

    test('saga cancellation: race effect', () {
      var actual = <dynamic>[];

      var startComp = Completer<String>();
      var cancelComp = Completer<String>();
      var subroutineComps = createArrayOfCompleters<String>(2);

      ResolveSequentially([
        callF(() => startComp.complete('start')),
        callF(() => cancelComp.complete('cancel')),
        callF(() => subroutineComps[0].complete('subroutine 1')),
        callF(() => subroutineComps[1].complete('subroutine 2')),
      ]);

      Iterable<Effect> subroutine1() sync* {
        actual.add('subroutine 1 start');

        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Call(() => subroutineComps[0].future, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('subroutine cancelled');
          }
        });
      }

      Iterable<Effect> subroutine2() sync* {
        actual.add('subroutine 2 start');

        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Call(() => subroutineComps[1].future, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('subroutine cancelled');
          }
        });
      }

      Iterable<Effect> main() sync* {
        var result = Result<dynamic>();
        yield Call(() => startComp.future, result: result);
        actual.add(result.value);

        yield Try(() sync* {
          var race = RaceResult();
          yield Race(<dynamic, Effect>{
            #subroutine1: Call(subroutine1),
            #subroutine2: Call(subroutine2)
          }, result: race);
          actual.add(race.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('cancelled');
          }
        });
      }

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(main);

      cancelComp.future.then((dynamic value) {
        actual.add(value);
        task.cancel();
      });

      expect(task.toFuture(), completion(TaskCancel));

      //cancelled race effect must cancel all sub-effects
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            'start',
            'subroutine 1 start',
            'subroutine 2 start',
            'cancel',
            'subroutine cancelled',
            'subroutine cancelled',
            'cancelled',
          ]));
    });

    test('saga cancellation: automatic parallel effect cancellation', () {
      var actual = <dynamic>[];

      var subtask1Comps = createArrayOfCompleters<String>(2);
      var subtask2Comps = createArrayOfCompleters<String>(2);

      ResolveSequentially([
        callF(() => subtask1Comps[0].complete('subtask_1')),
        callF(() => subtask2Comps[0].complete('subtask_2')),
        callF(() => subtask1Comps[1].completeError('subtask_1 rejection')),
        callF(() => subtask2Comps[1].complete('subtask_2_2')),
      ]);

      Iterable<Effect> subtask1() sync* {
        var result = Result<dynamic>();
        yield Call(() => subtask1Comps[0].future, result: result);
        actual.add(result.value);

        yield Call(() => subtask1Comps[1].future, result: result);
        actual.add(result.value);
      }

      Iterable<Effect> subtask2() sync* {
        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Call(() => subtask2Comps[0].future, result: result);
          actual.add(result.value);

          yield Call(() => subtask2Comps[1].future, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('subtask 2 cancelled');
          }
        });
      }

      Iterable<Effect> main() sync* {
        yield Try(() sync* {
          yield All(<dynamic, Effect>{
            #call1: Call(subtask1),
            #call2: Call(subtask2)
          });
        }, Catch: (dynamic e, StackTrace s) sync* {
          actual.add('caught $e');
        });
      }

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(main);

      expect(task.toFuture(), completion(null));

      //saga must cancel parallel sub-effects on rejection
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            'subtask_1',
            'subtask_2',
            'subtask 2 cancelled',
            'caught subtask_1 rejection'
          ]));
    });

    test('saga cancellation: automatic race competitor cancellation', () {
      var actual = <dynamic>[];

      var winnerSubtaskComps = createArrayOfCompleters<String>(2);
      var loserSubtaskComps = createArrayOfCompleters<String>(2);
      var parallelSubtaskComps = createArrayOfCompleters<String>(2);

      ResolveSequentially([
        callF(() => winnerSubtaskComps[0].complete('winner_1')),
        callF(() => loserSubtaskComps[0].complete('loser_1')),
        callF(() => parallelSubtaskComps[0].complete('parallel_1')),
        callF(() => winnerSubtaskComps[1].complete('winner_2')),
        callF(() => loserSubtaskComps[1].complete('loser_2')),
        callF(() => parallelSubtaskComps[1].complete('parallel_2')),
      ]);

      Iterable<Effect> winnerSubtask() sync* {
        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Call(() => winnerSubtaskComps[0].future, result: result);
          actual.add(result.value);

          yield Call(() => winnerSubtaskComps[1].future, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('winner subtask cancelled');
          }
        });
      }

      Iterable<Effect> loserSubtask() sync* {
        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Call(() => loserSubtaskComps[0].future, result: result);
          actual.add(result.value);

          yield Call(() => loserSubtaskComps[1].future, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('loser subtask cancelled');
          }
        });
      }

      Iterable<Effect> parallelSubtask() sync* {
        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Call(() => parallelSubtaskComps[0].future, result: result);
          actual.add(result.value);

          yield Call(() => parallelSubtaskComps[1].future, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('parallel subtask cancelled');
          }
        });
      }

      Iterable<Effect> main() sync* {
        yield All(<dynamic, Effect>{
          #race: Race(<dynamic, Effect>{
            #winner: Call(winnerSubtask),
            #loser: Call(loserSubtask)
          }),
          #parallelSubtask: Call(parallelSubtask)
        });
      }

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(main);

      expect(task.toFuture(), completion(null));

      //saga must cancel race competitors except for the winner
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            'winner_1',
            'loser_1',
            'parallel_1',
            'winner_2',
            'loser subtask cancelled',
            'parallel_2'
          ]));
    });

    test('saga cancellation:  manual task cancellation', () {
      var actual = <dynamic>[];

      var signIn = Completer<String>();
      var signOut = Completer<String>();
      var expires = createArrayOfCompleters<String>(3);

      ResolveSequentially([
        callF(() => signIn.complete('signIn')),
        callF(() => expires[0].complete('expire_1')),
        callF(() => expires[1].complete('expire_2')),
        callF(() => signOut.complete('signOut')),
        callF(() => expires[2].complete('expire_3')),
      ]);

      Iterable<Effect> subtask() sync* {
        yield Try(() sync* {
          for (var i = 0; i < expires.length; i++) {
            var result = Result<dynamic>();
            yield Call(() => expires[i].future, result: result);
            actual.add(result.value);
          }
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('task cancelled');
          }
        });
      }

      Iterable<Effect> main() sync* {
        var result = Result<dynamic>();
        yield Call(() => signIn.future, result: result);
        actual.add(result.value);

        var task = Result<Task>();
        yield Fork(subtask, result: task);

        yield Call(() => signOut.future, result: result);
        actual.add(result.value);

        yield Cancel([task.value]);
      }

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(main);

      expect(task.toFuture(), completion(null));

      //saga must cancel forked tasks
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion(
              ['signIn', 'expire_1', 'expire_2', 'signOut', 'task cancelled']));
    });

    test('saga cancellation: nested task cancellation', () {
      var actual = <dynamic>[];

      var start = Completer<String>();
      var stop = Completer<String>();
      var subtaskComps = createArrayOfCompleters<String>(2);
      var nestedTask1Comps = createArrayOfCompleters<String>(2);
      var nestedTask2Comps = createArrayOfCompleters<String>(2);

      ResolveSequentially([
        callF(() => start.complete('start')),
        callF(() => subtaskComps[0].complete('subtask_1')),
        callF(() => nestedTask1Comps[0].complete('nested_task_1_1')),
        callF(() => nestedTask2Comps[0].complete('nested_task_2_1')),
        callF(() => stop.complete('stop')),
        callF(() => nestedTask1Comps[1].complete('nested_task_1_2')),
        callF(() => nestedTask2Comps[1].complete('nested_task_2_2')),
        callF(() => subtaskComps[1].complete('subtask_2')),
      ]);

      Iterable<Effect> nestedTask1() sync* {
        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Call(() => nestedTask1Comps[0].future, result: result);
          actual.add(result.value);

          yield Call(() => nestedTask1Comps[1].future, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('nested task 1 cancelled');
          }
        });
      }

      Iterable<Effect> nestedTask2() sync* {
        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Call(() => nestedTask2Comps[0].future, result: result);
          actual.add(result.value);

          yield Call(() => nestedTask2Comps[1].future, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('nested task 2 cancelled');
          }
        });
      }

      Iterable<Effect> subtask() sync* {
        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Call(() => subtaskComps[0].future, result: result);
          actual.add(result.value);

          yield All(<dynamic, Effect>{
            #call1: Call(nestedTask1),
            #call2: Call(nestedTask2)
          });

          yield Call(() => subtaskComps[1].future, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('subtask cancelled');
          }
        });
      }

      Iterable<Effect> main() sync* {
        var result = Result<dynamic>();
        yield Call(() => start.future, result: result);
        actual.add(result.value);

        var task = Result<Task>();
        yield Fork(subtask, result: task);

        yield Call(() => stop.future, result: result);
        actual.add(result.value);

        yield Cancel([task.value]);
      }

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(main);

      expect(task.toFuture(), completion(null));

      //saga must cancel forked task and its nested subtask
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            'start',
            'subtask_1',
            'nested_task_1_1',
            'nested_task_2_1',
            'stop',
            'nested task 1 cancelled',
            'nested task 2 cancelled',
            'subtask cancelled'
          ]));
    });

    test('saga cancellation: nested forked task cancellation', () {
      var actual = <dynamic>[];

      var start = Completer<String>();
      var stop = Completer<String>();
      var subtaskComps = createArrayOfCompleters<String>(2);
      var nestedTaskComps = createArrayOfCompleters<String>(2);

      ResolveSequentially([
        callF(() => start.complete('start')),
        callF(() => subtaskComps[0].complete('subtask_1')),
        callF(() => nestedTaskComps[0].complete('nested_task_1')),
        callF(() => stop.complete('stop')),
        callF(() => nestedTaskComps[1].complete('nested_task_2')),
        callF(() => subtaskComps[1].complete('subtask_2')),
      ]);

      Iterable<Effect> nestedTask() sync* {
        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Call(() => nestedTaskComps[0].future, result: result);
          actual.add(result.value);

          yield Call(() => nestedTaskComps[1].future, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('nested task cancelled');
          }
        });
      }

      Iterable<Effect> subtask() sync* {
        yield Try(() sync* {
          var result = Result<dynamic>();
          yield Call(() => subtaskComps[0].future, result: result);
          actual.add(result.value);

          yield Fork(nestedTask);

          yield Call(() => subtaskComps[1].future, result: result);
          actual.add(result.value);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('subtask cancelled');
          }
        });
      }

      Iterable<Effect> main() sync* {
        var result = Result<dynamic>();
        yield Call(() => start.future, result: result);
        actual.add(result.value);

        var task = Result<Task>();
        yield Fork(subtask, result: task);

        yield Call(() => stop.future, result: result);
        actual.add(result.value);

        yield Cancel([task.value]);
      }

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(main);

      expect(task.toFuture(), completion(null));

      //saga must cancel forked task and its forked nested subtask
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            'start',
            'subtask_1',
            'nested_task_1',
            'stop',
            'subtask cancelled',
            'nested task cancelled'
          ]));
    });

    test('cancel should be able to cancel multiple tasks', () {
      var actual = <dynamic>[];

      var Comps = createArrayOfCompleters<String>(3);

      Iterable<Effect> worker(int i) sync* {
        yield Try(() sync* {
          yield Call(() => Comps[i].future);
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add(i);
          }
        });
      }

      Iterable<Effect> main() sync* {
        var task1 = Result<Task>();
        yield Fork(worker, args: <dynamic>[0], result: task1);

        var task2 = Result<Task>();
        yield Fork(worker, args: <dynamic>[1], result: task2);

        var task3 = Result<Task>();
        yield Fork(worker, args: <dynamic>[2], result: task3);

        yield Cancel([task1.value, task2.value, task3.value]);
      }

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(main);

      expect(task.toFuture(), completion(null));

      //it must be possible to cancel multiple tasks at once
      expect(task.toFuture().then((dynamic value) => actual),
          completion([0, 1, 2]));
    });

    test('cancel should support for self cancellation', () {
      var actual = <dynamic>[];

      Iterable<Effect> worker() sync* {
        yield Try(() sync* {
          yield Cancel();
        }, Finally: () sync* {
          var cancelled = Result<bool>();
          yield Cancelled(result: cancelled);
          if (cancelled.value) {
            actual.add('self cancellation');
          }
        });
      }

      Iterable<Effect> main() sync* {
        yield Fork(worker);
      }

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      var task = sagaMiddleware.run(main);

      expect(task.toFuture(), completion(null));

      //it must be possible to cancel multiple tasks at once
      expect(task.toFuture().then((dynamic value) => actual),
          completion(['self cancellation']));
    });

    test('should bubble an exception thrown during cancellation', () {
      fakeAsync((async) {
        Iterable<Effect> child() sync* {
          yield Try(() sync* {
            yield Delay(Duration(milliseconds: 100));
          }, Finally: () sync* {
            throw exceptionToBeCaught;
          });
        }

        Iterable<Effect> main() sync* {
          var taskA = Result<Task>();
          yield Fork(child, result: taskA);
          yield Delay(Duration(milliseconds: 100));
          yield Cancel([taskA.value]);
        }

        dynamic caughtMiddlewareError;
        var sagaMiddleware =
            createMiddleware(options: Options(onError: (dynamic e, String s) {
          caughtMiddlewareError = e;
        }));
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(main);

        expect(task.toFuture(), throwsA(exceptionToBeCaught));
        expect(task.toFuture().catchError((dynamic e) => e),
            completion(exceptionToBeCaught));
        expect(task.toFuture().catchError((dynamic e) => caughtMiddlewareError),
            completion(exceptionToBeCaught));

        async.elapse(Duration(milliseconds: 500));
      });
    });

    test('task should end in cancelled state when joining cancelled child', () {
      fakeAsync((async) {
        Iterable<Effect> child() sync* {
          yield Delay(Duration(milliseconds: 0));
          yield Cancel();
        }

        Iterable<Effect> main() sync* {
          var taskA = Result<Task>();
          yield Fork(child, result: taskA);
          yield Join(<dynamic, Task>{#taskA: taskA.value});
        }

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(main);

        expect(
            task.toFuture().then((dynamic value) =>
                [task.isCancelled, task.isRunning, task.isAborted]),
            completion([true, false, false]));

        async.elapse(Duration(milliseconds: 500));
      });
    });

    test('task should end in cancelled state when parent gets cancelled', () {
      fakeAsync((async) {
        var Comp = Completer<int>();

        Iterable<Effect> child() sync* {
          // just block
          yield Call(() => Comp.future);
        }

        var forkedTask = Result<Task>();

        Iterable<Effect> parent() sync* {
          yield Fork(child, result: forkedTask);
        }

        Iterable<Effect> main() sync* {
          var parentTask = Result<Task>();
          yield Fork(parent, result: parentTask);
          yield Delay(Duration(milliseconds: 0));
          yield Cancel([parentTask.value]);
        }

        var sagaMiddleware = createMiddleware();
        var store = createStore(sagaMiddleware);
        sagaMiddleware.setStore(store);

        var task = sagaMiddleware.run(main);

        expect(
            task.toFuture().then((dynamic value) => [
                  forkedTask.value.isCancelled,
                  forkedTask.value.isRunning,
                  forkedTask.value.isAborted
                ]),
            completion([true, false, false]));

        async.elapse(Duration(milliseconds: 500));
      });
    });
  });
}
