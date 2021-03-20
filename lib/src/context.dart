part of redux_saga;

/// Manages saga context. Context is basically a key/value dictionary
/// stored in [objects] member of class. Middleware creates and manages context
/// by instantiating [SagaContext].
///
/// Use [Options] to pass initial context to middleware.
/// In most cases no need to instantiate this class manually.
/// Context can be read and modified by effects [GetContext] and [SetContext]
///
///
///```
///  // create middleware and pass options
///  var sagaMiddleware = createSagaMiddleware(
///    //initiate context with options
///    Options(context: <dynamic, dynamic>{#a: 1}),
///  );
///
///  // create store and apply middleware
///  final store = Store<int>(
///    counterReducer,
///    initialState: 0,
///    middleware: [applyMiddleware(sagaMiddleware)],
///  );
///
///  // attach store
///  sagaMiddleware.setStore(store);
///
///  // run saga
///  sagaMiddleware.run(() sync* {
///   var result = Result<dynamic>();
///
///   //read context
///   yield GetContext(#a, result: result);
///
///   //set context
///   yield SetContext(<dynamic, dynamic>{#b: 2});
///  });
///```
///
class SagaContext {
  /// Context values stored at [objects]. It is a map dictionary with key/value pairs.
  Map<dynamic, dynamic> objects = <dynamic, dynamic>{};

  /// Creates an instance of a [SagaContext].
  ///
  /// Context can be initiated by passing [objects] parameter.
  SagaContext([Map<dynamic, dynamic>? objects]) {
    this.objects = objects ?? <dynamic, dynamic>{};
  }

  /// Indexed get property to access context values
  dynamic operator [](dynamic name) {
    return objects[name];
  }

  /// Adds new item named [name] to the context with the value [object]
  /// if it already exits then set [object] as new value
  void add(dynamic name, dynamic object) {
    objects[name] = object;
  }

  /// Removes context item with [name]
  void remove(dynamic name) {
    objects.remove(name);
  }

  /// Returns context items keys
  List<dynamic> get keys => objects.keys.toList();

  void _extend(Map<dynamic, dynamic> context) {
    for (var kv in context.entries) {
      objects[kv.key] = kv.value;
    }
  }

  @override
  String toString() {
    var s = '{';
    for (var kv in objects.entries) {
      s += '${kv.key} : ${kv.value},';
    }
    s += '}';
    return s;
  }
}
