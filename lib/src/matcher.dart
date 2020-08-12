part of redux_saga;

/// Matcher type for matching messages on a channel using [Take] effect.
typedef Matcher<T> = bool Function(T message);

///matches every message
Matcher<T> _wilcardMatcher<T>() => (T message) => true;

///matches if message object type is equal to pattern string
///For example take('MyAction') matches MyAction()
Matcher<T> _stringMatcher<T>(String pattern) => (T message) =>
    (message != null) && identical(message.runtimeType.toString(), pattern);

///matches is any of the patterns in the list matches
Matcher<T> _arrayMatcher<T>(List pattern) =>
    (T message) => pattern.any((dynamic p) => _matcher<T>(p)(message));

///matches if evaluation of patterns function is true with the given message as argument
///For example take(Fn(MyFunc)) evaluates MyFunc(message) and if function returns true then matches
Matcher<T> _functionMatcher<T>(Function pattern) =>
    (T message) => _callFunction(pattern, <dynamic>[message], null) as bool;

///matches if message object is instance of pattern type
///For example take(MyAction) matches MyAction()
Matcher<T> _typeMatcher<T>(Type pattern) =>
    (T message) => (message != null) && message.runtimeType == pattern;

void _checkPattern(dynamic pattern) {
  if (identical(pattern, '*') ||
      pattern is String ||
      pattern is Function ||
      pattern is Type) {
    return;
  } else if (pattern is List) {
    pattern.forEach(_checkPattern);
  } else {
    throw InvalidPattern(pattern);
  }
}

Matcher<T> _matcher<T>(dynamic pattern) {
  _checkPattern(pattern);

  var matcherCreator = identical(pattern, '*')
      ? _wilcardMatcher<T>()
      : (pattern is String)
          ? _stringMatcher<T>(pattern)
          : (pattern is List)
              ? _arrayMatcher<T>(pattern)
              : (pattern is Function)
                  ? _functionMatcher<T>(pattern)
                  : (pattern is Type) ? _typeMatcher<T>(pattern) : null;

  if (matcherCreator == null) throw InvalidPattern(pattern);

  return matcherCreator;
}
