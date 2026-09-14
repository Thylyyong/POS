import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  final String? qrImagePath;
  final String? receiptNo;
  final double? cashTendered;
  final double? changeAmount;
  final String? thankYouNote;

  // Real-time synchronization with Cashier POS Screen
  final String selectedCategoryId;
  final String? selectedSubcategoryId;
  final String searchQuery;
  final double scrollOffset;
  final String gridTemplate;
  final double fontSizeScale;

  PresentationPayload({
    required this.state,
    this.items = const [],
    this.subtotal = 0.0,
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
    this.totalAmount = 0.0,
    this.currencySymbol = '\$',
    this.qrData,
    this.qrImagePath,
    this.receiptNo,
    this.cashTendered,
    this.changeAmount,
    this.thankYouNote,
    this.selectedCategoryId = 'ALL',
    this.selectedSubcategoryId,
    this.searchQuery = '',
    this.scrollOffset = 0.0,
    this.gridTemplate = '4x6',
    this.fontSizeScale = 1.0,
  });

  PresentationPayload copyWith({
    CfdScreenState? state,
    List<Map<String, dynamic>>? items,
    double? subtotal,
    double? discountAmount,
    double? taxAmount,
    double? totalAmount,
    String? currencySymbol,
    String? qrData,
    String? qrImagePath,
    String? receiptNo,
    double? cashTendered,
    double? changeAmount,
    String? thankYouNote,
    String? selectedCategoryId,
    String? selectedSubcategoryId,
    String? searchQuery,
    double? scrollOffset,
    String? gridTemplate,
    double? fontSizeScale,
  }) {
    return PresentationPayload(
      state: state ?? this.state,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      qrData: qrData ?? this.qrData,
      qrImagePath: qrImagePath ?? this.qrImagePath,
      receiptNo: receiptNo ?? this.receiptNo,
      cashTendered: cashTendered ?? this.cashTendered,
      changeAmount: changeAmount ?? this.changeAmount,
      thankYouNote: thankYouNote ?? this.thankYouNote,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      selectedSubcategoryId: selectedSubcategoryId ?? this.selectedSubcategoryId,
      searchQuery: searchQuery ?? this.searchQuery,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      gridTemplate: gridTemplate ?? this.gridTemplate,
      fontSizeScale: fontSizeScale ?? this.fontSizeScale,
    );
  }

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
      'qrImagePath': qrImagePath,
      'receiptNo': receiptNo,
      'cashTendered': cashTendered,
      'changeAmount': changeAmount,
      'thankYouNote': thankYouNote,
      'selectedCategoryId': selectedCategoryId,
      'selectedSubcategoryId': selectedSubcategoryId,
      'searchQuery': searchQuery,
      'scrollOffset': scrollOffset,
      'gridTemplate': gridTemplate,
      'fontSizeScale': fontSizeScale,
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
      qrImagePath: map['qrImagePath'] as String?,
      receiptNo: map['receiptNo'] as String?,
      cashTendered: (map['cashTendered'] as num?)?.toDouble(),
      changeAmount: (map['changeAmount'] as num?)?.toDouble(),
      thankYouNote: map['thankYouNote'] as String?,
      selectedCategoryId: map['selectedCategoryId'] as String? ?? 'ALL',
      selectedSubcategoryId: map['selectedSubcategoryId'] as String?,
      searchQuery: map['searchQuery'] as String? ?? '',
      scrollOffset: (map['scrollOffset'] as num?)?.toDouble() ?? 0.0,
      gridTemplate: map['gridTemplate'] as String? ?? '4x6',
      fontSizeScale: (map['fontSizeScale'] as num?)?.toDouble() ?? 1.0,
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
    if (!kIsWeb && Platform.isAndroid) {
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
    _connectedDisplays = [];
    return [];
  }

  /// Launch Secondary Customer Window on Windows or Android Dual-Screen POS
  Future<bool> launchSecondaryWindow() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        final exe = Platform.resolvedExecutable;
        await Process.start(
          exe,
          ['--cfd'],
          mode: ProcessStartMode.detached,
          workingDirectory: File(exe).parent.path,
        );
        _isSecondaryDisplayShowing = true;
        return true;
      } catch (e) {
        debugPrint('Failed to launch desktop secondary window: $e');
        return false;
      }
    } else if (!kIsWeb && Platform.isAndroid) {
      return await showCustomerDisplay();
    }
    return false;
  }

  /// Launch Secondary Customer-Facing Display (Android hardware presentation)
  Future<bool> showCustomerDisplay({int? displayId}) async {
    if (!kIsWeb && Platform.isAndroid) {
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
    return false;
  }

  /// Hide Secondary Display
  Future<bool> hideCustomerDisplay({int? displayId}) async {
    if (!kIsWeb && Platform.isAndroid) {
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
    _isSecondaryDisplayShowing = false;
    return true;
  }

  /// Send Payload to Customer Display (Called from Cashier App)
  Future<void> sendToCustomerDisplay(PresentationPayload payload) async {
    _latestPayload = payload;

    // 1. Emit to in-process stream
    _payloadStreamController.add(payload);

    // 2. Persist to IPC file for desktop multi-window synchronization
    if (!kIsWeb) {
      try {
        final tempDir = Directory.systemTemp;
        final file = File('${tempDir.path}/omni_pos_cfd_state.json');
        await file.writeAsString(payload.toJson(), flush: true);
      } catch (_) {}
    }

    // 3. Transfer via Android hardware presentation display bridge
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final jsonString = payload.toJson();
        await _displayManager
            .transferDataToPresentation(jsonString)
            .timeout(const Duration(milliseconds: 800), onTimeout: () => false);
      } catch (e) {
        debugPrint('Hardware presentation data transfer notice: $e');
      }
    }
  }

  /// Broadcast POS UI navigation state (category, subcategory, search, scroll offset, grid template)
  Future<void> syncPosNavigation({
    String? selectedCategoryId,
    String? selectedSubcategoryId,
    bool clearSubcategory = false,
    String? searchQuery,
    double? scrollOffset,
    String? gridTemplate,
    double? fontSizeScale,
  }) async {
    final updated = _latestPayload.copyWith(
      selectedCategoryId: selectedCategoryId ?? _latestPayload.selectedCategoryId,
      selectedSubcategoryId: clearSubcategory ? null : (selectedSubcategoryId ?? _latestPayload.selectedSubcategoryId),
      searchQuery: searchQuery ?? _latestPayload.searchQuery,
      scrollOffset: scrollOffset ?? _latestPayload.scrollOffset,
      gridTemplate: gridTemplate ?? _latestPayload.gridTemplate,
      fontSizeScale: fontSizeScale ?? _latestPayload.fontSizeScale,
    );
    await sendToCustomerDisplay(updated);
  }

  /// Persist latest menu data (categories, subcategories, products) to IPC for standalone CFD window
  Future<void> sendMenuToCustomerDisplay({
    required List<Map<String, dynamic>> categories,
    required List<Map<String, dynamic>> subcategories,
    required List<Map<String, dynamic>> products,
  }) async {
    if (!kIsWeb) {
      try {
        final tempDir = Directory.systemTemp;
        final file = File('${tempDir.path}/omni_pos_cfd_menu.json');
        final data = {
          'categories': categories,
          'subcategories': subcategories,
          'products': products,
        };
        await file.writeAsString(jsonEncode(data), flush: true);
      } catch (_) {}
    }
  }

  /// Read menu data from IPC file (used by standalone CFD when SQLite is isolated)
  Future<Map<String, dynamic>?> readMenuForCustomerDisplay() async {
    if (!kIsWeb) {
      try {
        final tempDir = Directory.systemTemp;
        final file = File('${tempDir.path}/omni_pos_cfd_menu.json');
        if (await file.exists()) {
          final text = await file.readAsString();
          if (text.isNotEmpty) {
            return jsonDecode(text) as Map<String, dynamic>;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Initialize listener on Secondary Display side
  StreamSubscription<PresentationPayload> listenOnCustomerDisplay(
    void Function(PresentationPayload payload) onData,
  ) {
    // Deliver latest known payload immediately
    onData(_latestPayload);

    Timer? ipcTimer;
    final controller = StreamController<PresentationPayload>();

    final sub = _payloadStreamController.stream.listen((payload) {
      if (!controller.isClosed) controller.add(payload);
    });

    // 2. Fast Poll IPC file on Desktop to receive live state from primary process (100ms)
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      String lastReadJson = '';
      ipcTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
        try {
          final tempDir = Directory.systemTemp;
          final file = File('${tempDir.path}/omni_pos_cfd_state.json');
          if (await file.exists()) {
            final content = await file.readAsString();
            if (content.isNotEmpty && content != lastReadJson) {
              lastReadJson = content;
              final payload = PresentationPayload.fromJson(content);
              _latestPayload = payload;
              if (!controller.isClosed) controller.add(payload);
            }
          }
        } catch (_) {}
      });
    }

    // 3. Listen to hardware presentation plugin channel on Android
    if (!kIsWeb && Platform.isAndroid) {
      try {
        _displayManager.listenDataFromMainDisplay((data) {
          if (data != null) {
            try {
              if (data is String) {
                final payload = PresentationPayload.fromJson(data);
                _latestPayload = payload;
                if (!controller.isClosed) controller.add(payload);
              } else if (data is Map) {
                final payload = PresentationPayload.fromMap(Map<String, dynamic>.from(data));
                _latestPayload = payload;
                if (!controller.isClosed) controller.add(payload);
              }
            } catch (e) {
              debugPrint('Error parsing customer display payload: $e');
            }
          }
        });
      } catch (e) {
        debugPrint('Presentation display hardware channel listener notice: $e');
      }
    }

    controller.onCancel = () {
      ipcTimer?.cancel();
      sub.cancel();
    };

    return controller.stream.listen(onData);
  }
}
