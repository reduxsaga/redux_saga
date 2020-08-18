part of redux_saga;

/// Returns true is application is in Release mode
const bool _isReleaseMode =
    bool.fromEnvironment('dart.vm.product', defaultValue: false);

/// Returns true is application is in Profile mode
const bool _isProfileMode =
    bool.fromEnvironment('dart.vm.profile', defaultValue: false);

/// Returns true is application is in Debug mode
const bool _isDebugMode = !_isReleaseMode && !_isProfileMode;

/// An empty string variable
const String _emptyString = '';

/// Void callback function handler
typedef Callback = void Function();

/// A empty callback. It does nothing.
void _noop() {}
