import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../database/order_dao.dart';
import '../models/order_model.dart';
import '../models/store_settings_model.dart';

class ExcelExportService {
  static final ExcelExportService _instance = ExcelExportService._internal();
  factory ExcelExportService() => _instance;
  ExcelExportService._internal();

  /// Request storage permission on Android (handles Android 11 Scoped Storage / MANAGE_EXTERNAL_STORAGE)
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    try {
      // Check if MANAGE_EXTERNAL_STORAGE is already granted
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }

      // Request MANAGE_EXTERNAL_STORAGE for Android 11 (API 30+)
      final requestedManage = await Permission.manageExternalStorage.request();
      if (requestedManage.isGranted) {
        return true;
      }

      // Fallback for standard storage permissions
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Export Sales Report to .xlsx File in Device Documents/Downloads directory
  Future<String> exportSalesReport({
    required SalesMetrics metrics,
    required List<OrderModel> orders,
    required List<TopSellingItem> topItems,
    required List<ReceiptLogModel> logs,
    required StoreSettingsModel settings,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) {
      excel.delete(defaultSheet);
    }

    final dateRangeStr = (startDate != null && endDate != null)
        ? '${DateFormat('yyyy-MM-dd').format(startDate)} to ${DateFormat('yyyy-MM-dd').format(endDate)}'
        : 'All Time';
    final generatedAt = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    // -------------------------------------------------------------
    // SHEET 1: Sales Summary
    // -------------------------------------------------------------
    final summarySheet = excel['Sales Summary'];
    summarySheet.appendRow([TextCellValue('OMNIPOS SALES & ANALYTICS REPORT')]);
    summarySheet.appendRow([TextCellValue('Store Name:'), TextCellValue(settings.storeName)]);
    summarySheet.appendRow([TextCellValue('Reporting Period:'), TextCellValue(dateRangeStr)]);
    summarySheet.appendRow([TextCellValue('Exported At:'), TextCellValue(generatedAt)]);
    summarySheet.appendRow([TextCellValue('')]);

    summarySheet.appendRow([TextCellValue('KEY METRIC'), TextCellValue('VALUE')]);
    summarySheet.appendRow([TextCellValue('Total Revenue'), TextCellValue('${settings.currencySymbol}${metrics.totalRevenue.toStringAsFixed(2)}')]);
    summarySheet.appendRow([TextCellValue('Estimated Cost'), TextCellValue('${settings.currencySymbol}${metrics.totalCost.toStringAsFixed(2)}')]);
    summarySheet.appendRow([TextCellValue('Gross Profit'), TextCellValue('${settings.currencySymbol}${metrics.grossProfit.toStringAsFixed(2)}')]);
    summarySheet.appendRow([TextCellValue('Completed Orders'), IntCellValue(metrics.totalOrders)]);
    summarySheet.appendRow([TextCellValue('Total Items Sold'), IntCellValue(metrics.totalItemsSold)]);
    summarySheet.appendRow([TextCellValue('Average Order Value (AOV)'), TextCellValue('${settings.currencySymbol}${metrics.averageOrderValue.toStringAsFixed(2)}')]);
    summarySheet.appendRow([TextCellValue('')]);

    summarySheet.appendRow([TextCellValue('PAYMENT BREAKDOWN'), TextCellValue('REVENUE'), TextCellValue('ORDERS')]);
    summarySheet.appendRow([
      TextCellValue('Cash Payment'),
      TextCellValue('${settings.currencySymbol}${metrics.cashRevenue.toStringAsFixed(2)}'),
      IntCellValue(metrics.cashOrderCount),
    ]);
    summarySheet.appendRow([
      TextCellValue('QR Code Payment'),
      TextCellValue('${settings.currencySymbol}${metrics.qrRevenue.toStringAsFixed(2)}'),
      IntCellValue(metrics.qrOrderCount),
    ]);

    // -------------------------------------------------------------
    // SHEET 2: Orders Register
    // -------------------------------------------------------------
    final ordersSheet = excel['Orders Register'];
    ordersSheet.appendRow([
      TextCellValue('Receipt No'),
      TextCellValue('Daily Order #'),
      TextCellValue('Date/Time'),
      TextCellValue('Order Type'),
      TextCellValue('Table / Spot'),
      TextCellValue('Customer Name'),
      TextCellValue('Items Count'),
      TextCellValue('Subtotal'),
      TextCellValue('Discount'),
      TextCellValue('Tax'),
      TextCellValue('Total Amount'),
      TextCellValue('Payment Method'),
      TextCellValue('Status'),
    ]);

    for (var o in orders) {
      ordersSheet.appendRow([
        TextCellValue(o.receiptNo),
        TextCellValue(o.orderNumber != null ? '#${o.orderNumber}' : ''),
        TextCellValue(DateFormat('yyyy-MM-dd HH:mm:ss').format(o.createdAt)),
        TextCellValue(o.orderType),
        TextCellValue(o.tableNumber ?? 'N/A'),
        TextCellValue(o.customerName ?? 'Guest'),
        IntCellValue(o.items.fold(0, (sum, i) => sum + i.quantity)),
        DoubleCellValue(o.subtotal),
        DoubleCellValue(o.discountAmount),
        DoubleCellValue(o.taxAmount),
        DoubleCellValue(o.totalAmount),
        TextCellValue(o.paymentMethod.displayName),
        TextCellValue(o.status.displayName),
      ]);
    }

    // -------------------------------------------------------------
    // SHEET 3: Itemized Line Items
    // -------------------------------------------------------------
    final itemsSheet = excel['Itemized Sales'];
    itemsSheet.appendRow([
      TextCellValue('Receipt No'),
      TextCellValue('Date'),
      TextCellValue('Product Name'),
      TextCellValue('Quantity'),
      TextCellValue('Unit Price'),
      TextCellValue('Total Price'),
      TextCellValue('Notes'),
    ]);

    for (var o in orders) {
      for (var item in o.items) {
        itemsSheet.appendRow([
          TextCellValue(o.receiptNo),
          TextCellValue(DateFormat('yyyy-MM-dd').format(o.createdAt)),
          TextCellValue(item.productName),
          IntCellValue(item.quantity),
          DoubleCellValue(item.unitPrice),
          DoubleCellValue(item.totalPrice),
          TextCellValue(item.notes ?? ''),
        ]);
      }
    }

    // -------------------------------------------------------------
    // SHEET 4: Top Selling Items
    // -------------------------------------------------------------
    final topSheet = excel['Top Selling Items'];
    topSheet.appendRow([
      TextCellValue('Rank'),
      TextCellValue('Product Name'),
      TextCellValue('Total Quantity Sold'),
      TextCellValue('Total Revenue'),
    ]);

    for (var i = 0; i < topItems.length; i++) {
      final t = topItems[i];
      topSheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(t.productName),
        IntCellValue(t.totalQuantity),
        DoubleCellValue(t.totalRevenue),
      ]);
    }

    // -------------------------------------------------------------
    // SHEET 5: Receipt Logs
    // -------------------------------------------------------------
    final logsSheet = excel['Receipt Logs'];
    logsSheet.appendRow([
      TextCellValue('Log ID'),
      TextCellValue('Receipt No'),
      TextCellValue('Order ID'),
      TextCellValue('Action'),
      TextCellValue('Timestamp'),
      TextCellValue('Success'),
      TextCellValue('File Path'),
    ]);

    for (var l in logs) {
      logsSheet.appendRow([
        TextCellValue(l.id),
        TextCellValue(l.receiptNo),
        TextCellValue(l.orderId),
        TextCellValue(l.action),
        TextCellValue(DateFormat('yyyy-MM-dd HH:mm:ss').format(l.timestamp)),
        TextCellValue(l.isSuccess ? 'YES' : 'NO'),
        TextCellValue(l.receiptFilePath ?? ''),
      ]);
    }

    // Encode bytes
    final fileBytes = excel.encode();
    if (fileBytes == null) {
      throw Exception('Failed to generate Excel file bytes');
    }

    final timestampStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'OmniPOS_Report_$timestampStr.xlsx';

    // 1. Request Android 11 Storage Permission & write to public Downloads folder
    String? finalPath;
    try {
      await requestStoragePermission();
      const publicDownloadDir = '/storage/emulated/0/Download/POS_Reports';
      final dir = Directory(publicDownloadDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File('$publicDownloadDir/$fileName');
      await file.writeAsBytes(fileBytes, flush: true);
      finalPath = file.path;
    } catch (_) {}

    // 2. Also save to App Documents
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final reportsDir = Directory('${docsDir.path}/reports');
      if (!await reportsDir.exists()) {
        await reportsDir.create(recursive: true);
      }
      final docFile = File('${reportsDir.path}/$fileName');
      await docFile.writeAsBytes(fileBytes, flush: true);
      finalPath ??= docFile.path;
    } catch (_) {}

    return finalPath ?? fileName;
  }

  /// Open Excel file directly in Microsoft Excel / Google Sheets
  Future<OpenResult> openExcelFile(String filePath) async {
    return await OpenFilex.open(filePath);
  }

  /// Share Excel file via Android system share sheet
  Future<ShareResult> shareExcelFile(String filePath) async {
    return await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        subject: 'OmniPOS Sales & Analytics Report',
      ),
    );
  }
}
