import 'dart:async';
import 'package:flutter/foundation.dart';

import 'order_receipt_model.dart';
import 'printer_transport.dart';
import 'receipt_byte_builder.dart';

/// Current status of the asynchronous printer queue.
enum PrinterJobStatus {
  idle,
  compiling,
  printing,
  success,
  failed,
}

/// Internal queue item holding the receipt payload and optional completion callbacks.
final class _PrintTask {
  final OrderReceiptModel receipt;
  final Completer<bool>? completer;

  _PrintTask({
    required this.receipt,
    this.completer,
  });
}

/// Production-grade POS Receipt Printer Service.
/// 
/// Core Architectural Guarantees:
/// 1. Zero UI Freeze: Byte compilation executes in a background Isolate via [compute].
/// 2. Non-blocking Execution: Checkout buttons trigger [printOrder] in a fire-and-forget
///    fashion, allowing instant cart reset and zero FPS drops.
/// 3. Serialized FIFO Queue: Prevents concurrent Bluetooth socket collisions when 
///    cashiers process multiple tickets in rapid succession.
/// 4. Error Containment: Hardware failures are caught and logged without crashing the app.
class PosPrinterService {
  final PrinterTransport transport;
  final _queue = <_PrintTask>[];
  bool _isProcessing = false;

  final _statusNotifier = ValueNotifier<PrinterJobStatus>(PrinterJobStatus.idle);
  ValueListenable<PrinterJobStatus> get statusNotifier => _statusNotifier;

  PosPrinterService({required this.transport});

  /// Fire-and-forget non-blocking receipt print trigger.
  /// 
  /// The caller (e.g., checkout button handler) returns IMMEDIATELY.
  /// Does NOT wait for isolate byte generation or physical paper movement.
  void printOrder(OrderReceiptModel receipt) {
    _enqueue(receipt, completer: null);
  }

  /// Optional awaitable variant for background workers, diagnostic screens, or reprints.
  Future<bool> printOrderAsync(OrderReceiptModel receipt) {
    final completer = Completer<bool>();
    _enqueue(receipt, completer: completer);
    return completer.future;
  }

  void _enqueue(OrderReceiptModel receipt, {Completer<bool>? completer}) {
    _queue.add(_PrintTask(receipt: receipt, completer: completer));
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;
    _isProcessing = true;

    while (_queue.isNotEmpty) {
      final task = _queue.removeAt(0);
      bool isSuccess = false;

      try {
        _statusNotifier.value = PrinterJobStatus.compiling;

        // 1. Offload pure ESC/POS binary generation to background Isolate
        final Uint8List rawBytes = await compute(
          ReceiptByteBuilder.buildBytes,
          task.receipt,
        );

        _statusNotifier.value = PrinterJobStatus.printing;

        // 2. Transmit bytes in paced chunks via the configured transport
        await transport.send(rawBytes);

        _statusNotifier.value = PrinterJobStatus.success;
        isSuccess = true;
      } catch (e, stack) {
        _statusNotifier.value = PrinterJobStatus.failed;
        debugPrint('[PosPrinterService] Thermal print failed: $e\n$stack');
        isSuccess = false;
      } finally {
        task.completer?.complete(isSuccess);
      }
    }

    _isProcessing = false;
    _statusNotifier.value = PrinterJobStatus.idle;
  }

  /// Clean up resources when shutting down the POS application.
  Future<void> dispose() async {
    _queue.clear();
    await transport.dispose();
    _statusNotifier.dispose();
  }
}
