import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Abstract transport layer for thermal printers.
/// Follows Dependency Inversion Principle (DIP) to decouple byte generation from hardware I/O.
abstract interface class PrinterTransport {
  /// Transmits raw binary bytes to the physical printer.
  Future<void> send(Uint8List bytes);

  /// Releases socket connections or hardware handles.
  Future<void> dispose();
}

/// Production-grade Bluetooth transmitter with hardware pacing and chunking.
/// 
/// Real-world Problem:
/// Sending >1KB payloads directly to Android Bluetooth SPP/RFCOMM or BLE sockets 
/// causes native buffer overflow, packet drops, or SIGSEGV crashes on low-spec POS boards.
/// 
/// Solution:
/// Slices bytes into 512-byte chunks with an inter-packet pacing delay (10-20ms) 
/// to let the printer's hardware FIFO buffer drain smoothly.
class BluetoothChunkedTransmitter implements PrinterTransport {
  final Future<void> Function(Uint8List chunk) writeSocket;
  final int chunkSize;
  final Duration interChunkDelay;

  BluetoothChunkedTransmitter({
    required this.writeSocket,
    this.chunkSize = 512,
    this.interChunkDelay = const Duration(milliseconds: 15),
  });

  @override
  Future<void> send(Uint8List bytes) async {
    final totalLength = bytes.length;
    int offset = 0;

    while (offset < totalLength) {
      final end = (offset + chunkSize < totalLength) ? offset + chunkSize : totalLength;
      final chunk = bytes.sublist(offset, end);

      await writeSocket(chunk);
      offset = end;

      // Hardware pacing delay between chunks
      if (offset < totalLength && interChunkDelay > Duration.zero) {
        await Future.delayed(interChunkDelay);
      }
    }
  }

  @override
  Future<void> dispose() async {}
}

/// Android POS terminal built-in printer transport (e.g. Sunmi, iMin, CA H2).
/// Bridges directly to native printer hardware via Android MethodChannel.
class AndroidNativeChannelTransport implements PrinterTransport {
  static const MethodChannel _channel = MethodChannel('com.casolution.pos/printer');

  @override
  Future<void> send(Uint8List bytes) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('printRawData', {'bytes': bytes});
    } catch (e) {
      debugPrint('[AndroidNativeChannelTransport] Native print error: $e');
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {}
}

/// High-performance TCP/IP socket transport for Ethernet / WiFi thermal printers (Port 9100).
class TcpSocketTransport implements PrinterTransport {
  final String host;
  final int port;
  final Duration timeout;

  TcpSocketTransport({
    required this.host,
    this.port = 9100,
    this.timeout = const Duration(seconds: 3),
  });

  @override
  Future<void> send(Uint8List bytes) async {
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      socket.add(bytes);
      await socket.flush();
    } finally {
      await socket?.close();
    }
  }

  @override
  Future<void> dispose() async {}
}

/// Fallback / Mock transport for development and debug testing.
class DebugConsoleTransport implements PrinterTransport {
  @override
  Future<void> send(Uint8List bytes) async {
    debugPrint('[DebugConsoleTransport] Emitted ${bytes.length} ESC/POS bytes successfully.');
  }

  @override
  Future<void> dispose() async {}
}
