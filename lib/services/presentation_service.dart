import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_presentation_display/display.dart';
import 'package:flutter_presentation_display/flutter_presentation_display.dart';

enum CfdScreenState {
  idle,
  cartActive,
  paymentPending,
  paymentSuccess, paymentQr;

  static CfdScreenState fromString(String value) {
    switch (value) {
      case 'idle':
        return CfdScreenState.idle;
      case 'cartActive':
        return CfdScreenState.cartActive;
      case 'paymentPending':
        return CfdScreenState.paymentPending;
      case 'paymentSuccess':
        return CfdScreenState.paymentSuccess;
      default:
        return CfdScreenState.idle;
    }
  }
}

class PresentationPayload {
  final CfdScreenState state;
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double totalAmount;
  final String currencySymbol;
  final String? qrData;
  final String? receiptNo;
  final double? cashTendered;
  final double? changeAmount;
  final String? thankYouNote;

  PresentationPayload({
    required this.state,
    this.items = const [],
    this.subtotal = 0.0,
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
    this.totalAmount = 0.0,
    this.currencySymbol = '\$',
    this.qrData,
    this.receiptNo,
    this.cashTendered,
    this.changeAmount,
    this.thankYouNote,
  });

  Map<String, dynamic> toMap() {
    return {
      'state': state.name,
      'items': items,
      'subtotal': subtotal,
      'discountAmount': discountAmount,
      'taxAmount': taxAmount,
      'totalAmount': totalAmount,
      'currencySymbol': currencySymbol,
      'qrData': qrData,
      'receiptNo': receiptNo,
      'cashTendered': cashTendered,
      'changeAmount': changeAmount,
      'thankYouNote': thankYouNote,
    };
  }

  factory PresentationPayload.fromMap(Map<String, dynamic> map) {
    return PresentationPayload(
      state: CfdScreenState.fromString(map['state'] as String? ?? 'idle'),
      items: (map['items'] as List<dynamic>?)
              ?.map((item) => Map<String, dynamic>.from(item as Map))
              .toList() ??
          [],
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (map['discountAmount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['taxAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      currencySymbol: map['currencySymbol'] as String? ?? '\$',
      qrData: map['qrData'] as String?,
      receiptNo: map['receiptNo'] as String?,
      cashTendered: (map['cashTendered'] as num?)?.toDouble(),
      changeAmount: (map['changeAmount'] as num?)?.toDouble(),
      thankYouNote: map['thankYouNote'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory PresentationPayload.fromJson(String jsonStr) =>
      PresentationPayload.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);
}

class PresentationService {
  static final PresentationService _instance = PresentationService._internal();
  factory PresentationService() => _instance;
  PresentationService._internal();

  final FlutterPresentationDisplay _displayManager = FlutterPresentationDisplay();

  // Internal event bus for in-process sync (useful on emulators & debug previews)
  static final StreamController<PresentationPayload> _payloadStreamController =
      StreamController<PresentationPayload>.broadcast();

  Stream<PresentationPayload> get onPayloadReceived => _payloadStreamController.stream;

  PresentationPayload _latestPayload = PresentationPayload(state: CfdScreenState.idle);
  PresentationPayload get latestPayload => _latestPayload;

  List<Display> _connectedDisplays = [];
  List<Display> get connectedDisplays => _connectedDisplays;
  bool _isSecondaryDisplayShowing = false;
  bool get isSecondaryDisplayShowing => _isSecondaryDisplayShowing;

  /// Check available hardware presentation screens with safe timeout
  Future<List<Display>> refreshDisplays() async {
    try {
      final list = await _displayManager
          .getDisplays()
          .timeout(const Duration(milliseconds: 1500), onTimeout: () => []);
      _connectedDisplays = list ?? [];
      return _connectedDisplays;
    } catch (e) {
      debugPrint('Error getting presentation displays: $e');
      _connectedDisplays = [];
      return [];
    }
  }

  /// Launch Secondary Customer-Facing Display
  Future<bool> showCustomerDisplay({int? displayId}) async {
    try {
      final list = await refreshDisplays();
      if (list.isEmpty) {
        debugPrint('No physical secondary display detected.');
        _isSecondaryDisplayShowing = false;
        return false;
      }

      final targetId = displayId ?? list.first.displayId;
      if (targetId == null) return false;

      final success = await _displayManager
          .showSecondaryDisplay(
            displayId: targetId,
            routerName: 'secondaryDisplayMain',
          )
          .timeout(const Duration(seconds: 2), onTimeout: () => false);
      _isSecondaryDisplayShowing = success ?? true;
      return _isSecondaryDisplayShowing;
    } catch (e) {
      debugPrint('Error showing secondary display: $e');
      return false;
    }
  }

  /// Hide Secondary Display
  Future<bool> hideCustomerDisplay({int? displayId}) async {
    try {
      final targetId = displayId ?? _connectedDisplays.firstOrNull?.displayId;
      if (targetId != null) {
        await _displayManager
            .hideSecondaryDisplay(displayId: targetId)
            .timeout(const Duration(seconds: 2), onTimeout: () => false);
      }
      _isSecondaryDisplayShowing = false;
      return true;
    } catch (e) {
      debugPrint('Error hiding secondary display: $e');
      return false;
    }
  }

  /// Send Payload to Customer Display (Called from Cashier App)
  Future<void> sendToCustomerDisplay(PresentationPayload payload) async {
    _latestPayload = payload;

    // 1. Emit to in-process stream
    _payloadStreamController.add(payload);

    // 2. Transfer via hardware presentation display bridge safely
    try {
      final jsonString = payload.toJson();
      await _displayManager
          .transferDataToPresentation(jsonString)
          .timeout(const Duration(milliseconds: 800), onTimeout: () => false);
    } catch (e) {
      debugPrint('Hardware presentation data transfer notice: $e');
    }
  }

  /// Initialize listener on Secondary Display side
  StreamSubscription<PresentationPayload> listenOnCustomerDisplay(
    void Function(PresentationPayload payload) onData,
  ) {
    // Deliver latest known payload immediately
    onData(_latestPayload);

    // 1. Listen to in-process broadcast
    final subscription = _payloadStreamController.stream.listen((payload) {
      onData(payload);
    });

    // 2. Listen to hardware presentation plugin channel
    try {
      _displayManager.listenDataFromMainDisplay((data) {
        if (data != null) {
          try {
            if (data is String) {
              final payload = PresentationPayload.fromJson(data);
              _latestPayload = payload;
              onData(payload);
            } else if (data is Map) {
              final payload = PresentationPayload.fromMap(Map<String, dynamic>.from(data));
              _latestPayload = payload;
              onData(payload);
            }
          } catch (e) {
            debugPrint('Error parsing customer display payload: $e');
          }
        }
      });
    } catch (e) {
      debugPrint('Presentation display hardware channel listener notice: $e');
    }

    return subscription;
  }
}
