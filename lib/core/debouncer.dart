import 'dart:async';
import 'package:flutter/foundation.dart';

/// Delays execution of [action] until [duration] has elapsed since the last call.
/// Useful for search fields to avoid firing DB queries on every keystroke.
class Debouncer {
  final Duration duration;
  Timer? _timer;

  Debouncer({this.duration = const Duration(milliseconds: 300)});

  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// Cancel any pending invocation.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Whether a call is currently pending.
  bool get isPending => _timer?.isActive ?? false;
}
