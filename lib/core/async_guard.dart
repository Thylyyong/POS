/// Guards against stale async results when a new operation supersedes an
/// in-flight one (e.g. rapid category switching while a DB query is running).
///
/// Usage:
/// ```dart
/// final _guard = AsyncGuard();
///
/// Future<void> loadData() async {
///   final token = _guard.start();           // invalidates previous calls
///   final result = await someAsyncWork();
///   if (_guard.isStale(token)) return;      // discard if superseded
///   _data = result;
///   notifyListeners();
/// }
/// ```
class AsyncGuard {
  int _generation = 0;

  /// Starts a new operation. Returns an opaque [token] that can be checked
  /// later to determine whether this operation is still the current one.
  int start() => ++_generation;

  /// Returns `true` if the operation identified by [token] has been superseded
  /// by a newer [start] call and its result should be discarded.
  bool isStale(int token) => token != _generation;

  /// Resets the guard (e.g. on dispose).
  void reset() => _generation = 0;
}
