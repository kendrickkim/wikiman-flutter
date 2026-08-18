class WikimanBackExitGate {
  WikimanBackExitGate({
    this.window = const Duration(seconds: 2),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration window;
  final DateTime Function() _now;
  DateTime? _promptedAt;

  bool confirmExit() {
    final now = _now();
    if (_promptedAt != null && now.difference(_promptedAt!) < window) {
      return true;
    }
    _promptedAt = now;
    return false;
  }

  void reset() {
    _promptedAt = null;
  }
}
