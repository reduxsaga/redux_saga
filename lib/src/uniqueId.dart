part of redux_saga;

class _UniqueId {
  int _idCounter = 0;

  int nextSagaId() {
    return ++_idCounter;
  }

  int currentEffectId() {
    return _idCounter;
  }
}
