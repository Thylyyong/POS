import 'dart:async';
import 'package:flutter/services.dart';

typedef BarcodeScannedCallback = void Function(String barcode);

class BarcodeService {
  static final BarcodeService _instance = BarcodeService._internal();
  factory BarcodeService() => _instance;
  BarcodeService._internal();

  final StringBuffer _buffer = StringBuffer();
  DateTime _lastKeystrokeTime = DateTime.now();
  Timer? _debounceTimer;
  BarcodeScannedCallback? _callback;

  bool _isListening = false;
  bool get isListening => _isListening;

  /// Start listening globally to hardware scanner keystrokes
  void startListening(BarcodeScannedCallback onBarcodeScanned) {
    _callback = onBarcodeScanned;
    if (_isListening) return;

    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _isListening = true;
  }

  /// Stop listening
  void stopListening() {
    if (!_isListening) return;
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _debounceTimer?.cancel();
    _buffer.clear();
    _isListening = false;
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final now = DateTime.now();
    final timeDiff = now.difference(_lastKeystrokeTime).inMilliseconds;
    _lastKeystrokeTime = now;

    // If gap between keys is > 100ms, it's likely manual typing rather than rapid hardware scanner
    if (timeDiff > 120 && _buffer.isNotEmpty) {
      _buffer.clear();
    }

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      final code = _buffer.toString().trim();
      _buffer.clear();
      _debounceTimer?.cancel();

      if (code.isNotEmpty) {
        _callback?.call(code);
        return true; // Consume event
      }
      return false;
    }

    // Append printable character
    final char = event.character;
    if (char != null && char.isNotEmpty && RegExp(r'[a-zA-Z0-9\-_]').hasMatch(char)) {
      _buffer.write(char);

      // Timeout fallback in case scanner doesn't send Enter
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 100), () {
        if (_buffer.length >= 3) {
          final code = _buffer.toString().trim();
          _buffer.clear();
          _callback?.call(code);
        }
      });
    }

    return false;
  }
}
