# Sequencing Sagas via `yield*`

You can use the builtin `yield*` operator to compose multiple Sagas in a sequential way. This allows you to sequence your *macro-tasks* in a procedural style.

```dart
playLevelOne() sync* { ... }

playLevelTwo() sync* { ... }

playLevelThree() sync* { ... }

game() sync* {
  var score1 = Result();
  yield* playLevelOne(score1);
  yield Put(ShowScore(score1));

  var score2 = Result();
  yield* playLevelTwo(score2);
  yield Put(ShowScore(score2));

  var score3 = Result();
  yield* playLevelThree(score3);
  yield Put(ShowScore(score3));
}
```

Note that using `yield*` will cause the Dart runtime to *spread* the whole sequence. The resulting iterator (from `game()`) will yield all values from the nested iterators. A more powerful alternative is to use the more generic middleware composition mechanism.
