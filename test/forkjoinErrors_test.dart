import 'package:redux_saga/redux_saga.dart';
import 'package:test/test.dart';
import 'helpers/utils.dart';
import 'helpers/store.dart';

void main() {
  group('fork join errors tests', () {
    test('saga sync fork failures: functions', () {
      var actual = <dynamic>[];

      var caughtErrors = <dynamic>[];

      var sagaMiddleware =
          createMiddleware(options: Options(onError: (dynamic e, String s) {
        caughtErrors.add(e);
      }));
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      void immediatelyFailingFork() {
        throw 'immediatelyFailingFork';
      }

      Iterable<Effect> genParent() sync* {
        yield Try(() sync* {
          actual.add('start parent');
          yield Fork(immediatelyFailingFork);
          actual.add('success parent');
        }, Catch: (dynamic e, StackTrace s) {
          actual.add('parent caught $e');
        });
      }

      Iterable<Effect> main() sync* {
        yield Try(() sync* {
          actual.add('start main');
          yield Call(genParent);
          actual.add('success main');
        }, Catch: (dynamic e, StackTrace s) {
          actual.add('main caught $e');
        });
      }

      var task = sagaMiddleware.run(main);

      // saga should fails the parent if a forked function fails synchronously
      expect(
          task.toFuture().then((dynamic value) => actual),
          completion([
            'start main',
            'start parent',
            'main caught immediatelyFailingFork'
          ]));
      // all errors are caught. so caughtErrors is empty
      expect(task.toFuture().then((dynamic value) => caughtErrors),
          completion(<dynamic>[]));
    });

    test('saga sync fork failures: functions/error bubbling', () {
      var actual = <dynamic>[];

      var caughtErrors = <dynamic>[];

      var exception = Exception('immediatelyFailingFork');

      var sagaMiddleware =
          createMiddleware(options: Options(onError: (dynamic e, String s) {
        caughtErrors.add(e);
      }));
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      void immediatelyFailingFork() {
        throw exception;
      }

      Iterable<Effect> genParent() sync* {
        yield Try(() sync* {
          actual.add('start parent');
          yield Fork(immediatelyFailingFork);
          actual.add('success parent');
        }, Catch: (dynamic e, StackTrace s) {
          actual.add('parent caught $e');
        });
      }

      Iterable<Effect> main() sync* {
        yield Try(() sync* {
          actual.add('start main');
          yield Fork(genParent);
          actual.add('success main');
        }, Catch: (dynamic e, StackTrace s) {
          actual.add('main caught $e');
        });
      }

      var task = sagaMiddleware.run(main);

      expect(task.toFuture(), throwsA(exception));

      // saga should propagate errors up to the root of fork tree
      expect(task.toFuture().catchError((dynamic e) => actual),
          completion(['start main', 'start parent']));
      // uncaught errors must be logged by middlewares onError
      expect(task.toFuture().catchError((dynamic e) => caughtErrors),
          completion(<dynamic>[exception]));
    });

    test('saga fork\'s failures: generators', () {
      var actual = <dynamic>[];

      var sagaMiddleware = createMiddleware();
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      Iterable<Effect> genChild() sync* {
        throw 'gen error';
      }

      Iterable<Effect> genParent() sync* {
        yield Try(() sync* {
          actual.add('start parent');
          yield Fork(genChild);
          actual.add('success parent');
        }, Catch: (dynamic e, StackTrace s) {
          actual.add('parent caught $e');
        });
      }

      Iterable<Effect> main() sync* {
        yield Try(() sync* {
          actual.add('start main');
          yield Call(genParent);
          actual.add('success main');
        }, Catch: (dynamic e, StackTrace s) {
          actual.add('main caught $e');
        });
      }

      var task = sagaMiddleware.run(main);

      // saga should fails the parent if a forked generator fails synchronously
      expect(task.toFuture().then((dynamic value) => actual),
          completion(['start main', 'start parent', 'main caught gen error']));
    });

    test('saga sync fork failures: spawns (detached forks)', () {
      var actual = <dynamic>[];

      var caughtErrors = <dynamic>[];

      var exception = Exception('gen error');

      var sagaMiddleware =
          createMiddleware(options: Options(onError: (dynamic e, String s) {
        caughtErrors.add(e);
      }));
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      Iterable<Effect> genChild() sync* {
        throw exception;
      }

      Iterable<Effect> main() sync* {
        yield Try(() sync* {
          actual.add('start main');
          var spawnedTask = Result<Task>();
          yield Spawn(genChild, name: 'genChild', result: spawnedTask);
          actual.add('spawn ' + spawnedTask.value!.meta.name!);
          actual.add('success main');
        }, Catch: (dynamic e, StackTrace s) {
          actual.add('main caught $e');
        });
      }

      var task = sagaMiddleware.run(main);

      // saga should not fail a parent with errors from detached forks (using spawn)
      expect(task.toFuture().then((dynamic value) => actual),
          completion(['start main', 'spawn genChild', 'success main']));
    });

    test('saga detached forks failures', () {
      var actual = <dynamic>[];

      var failError = Exception('fail error');

      var sagaMiddleware =
          createMiddleware(options: Options(onError: (dynamic e, String s) {
        actual.add(e);
      }));
      var store = createStore(sagaMiddleware);
      sagaMiddleware.setStore(store);

      void willFail({dynamic action}) {
        if (!(action.fail as bool)) {
          actual.add(action.i);
          return;
        }

        throw failError;
      }

      void wontFail({dynamic action}) {
        actual.add(action.i);
      }

      Iterable<Effect> main() sync* {
        yield TakeEvery(willFail, pattern: _actionType1, detached: true);
        yield TakeEvery(wontFail, pattern: _actionType2);
      }

      sagaMiddleware.run(main);

      var f = ResolveSequentially([
        callF(() => store.dispatch(_actionType1(0))),
        callF(() => store.dispatch(_actionType1(1))),
        callF(() => store.dispatch(_actionType1(2))),
        callF(() => store.dispatch(_actionType1(3, true))),
        callF(() => store.dispatch(_actionType2(4))),
        callF(() => store.dispatch(End)),
      ]);

      // saga should not fail a parent with errors from detached fork
      expect(f.then((dynamic value) => actual),
          completion([0, 1, 2, failError, 4]));
    });
  });
}

class _actionType {
  final int i;
  final bool fail;

  _actionType(this.i, [this.fail = false]);
}

class _actionType1 extends _actionType {
  _actionType1(int i, [bool fail = false]) : super(i, fail);
}

class _actionType2 extends _actionType {
  _actionType2(int i, [bool fail = false]) : super(i, fail);
}
