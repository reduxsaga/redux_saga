part of redux_saga;

const bool _isReleaseMode =
    bool.fromEnvironment('dart.vm.product', defaultValue: false);
const bool _isProfileMode =
    bool.fromEnvironment('dart.vm.profile', defaultValue: false);
const bool _isDebugMode = !_isReleaseMode && !_isProfileMode;

const String _emptyString = '';

/// Void callback function handler
typedef Callback = void Function();

void _noop() {}
