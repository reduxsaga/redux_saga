# Change Log
All notable changes to this project will be documented in this file.

## 1.0.5

- Initial version

No changes yet.

## 1.0.6

- CloneableGenerator and MockTask implementations completed.

## 1.0.7

- Effect combinators fixed.

## 1.0.8

- Beginner tutorial is available now.

## 1.0.9

- Migration guide is available now.

## 1.1.8

- Advanced docs avaliable now.

## 1.1.9

- Saga monitor update.

## 1.1.10

- Saga monitor test fix.

## 1.1.14

- Code formatting fix.

## 1.1.15

- Documentation fix.

## 1.1.16

- Effect helpers action parameter can be dynamic or strict typed

## 2.0.0

- Flutter web build errors fixed. After minification the function closures are changing.
In order to avoid dart mirrors usage (also not avaliable) some changes are made.
Codes are written at previous versions of the library must be migrated to this version.
Please use the following instructions;

1. If you use one of the effects Debounce, TakeEvery, TakeLatest, TakeLeading or Throttle then you must add named `action` parameter to the saga.
Otherwise a parameter mismatch error may occured like the following;

Dynamic call with unexpected named argument 'action'.

Proper usage example :

```
fetchUser({dynamic action}) sync* { //add `{dynamic action}` as parameter
    //...
}

mySaga() sync* {
  yield TakeEvery(fetchUser, pattern: UserFetchRequested);
}
```

2. Catch saga of Try effect must have error and stackTrace arguments.
Otherwise a parameter mismatch error may occured like the following;

Dynamic call with too many arguments.
Receiver: Instance of '() => Iterable<Null>'
Arguments: [Instance of '_Exception', Instance of '_StackTrace']


Proper usage example :

```
  //...

  yield Try(() sync* {

  }, Catch: (e, s) sync* {  //add e and s parameters to saga

  });

  //...
```

## 2.0.1

- Fixed deprecated usages

## 2.0.2

- Readme changed. ci badge added

## 2.1.0

- Redux 5.0.0 and version upgrades.

## 3.0.3

- Updated to null safety

## 3.0.5

- pub.dev fixes

## 3.0.6

- pub.dev fixes and update

## 3.1.0

- removed unnecessary type checks



