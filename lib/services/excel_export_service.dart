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

  /// Request storage permission on Android
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    try {
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }
      final requestedManage = await Permission.manageExternalStorage.request();
      if (requestedManage.isGranted) {
        return true;
      }
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Export Sales & Profit Report to .xlsx file
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

    // Rename default sheet to ensure clean Excel compatibility
    final defaultSheetName = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheetName, 'Sales & Profit Summary');
    excel.setDefaultSheet('Sales & Profit Summary');

    final dateRangeStr = (startDate != null && endDate != null)
        ? '${DateFormat('yyyy-MM-dd').format(startDate)} to ${DateFormat('yyyy-MM-dd').format(endDate)}'
        : 'All Time / Complete History';
    final generatedAt = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final currency = settings.currencySymbol;

    // Calculate total discount and tax from actual orders if available
    double totalDiscount = 0.0;
    double totalTax = 0.0;
    double totalGrossSales = 0.0;
    for (var o in orders) {
      totalDiscount += o.discountAmount;
      totalTax += o.taxAmount;
      totalGrossSales += o.subtotal;
    }

    final double profitMargin = metrics.totalRevenue > 0
        ? (metrics.grossProfit / metrics.totalRevenue) * 100
        : 0.0;

    // -------------------------------------------------------------
    // SHEET 1: Sales & Profit Summary
    // -------------------------------------------------------------
    final summarySheet = excel['Sales & Profit Summary'];
    summarySheet.appendRow([TextCellValue('OMNIPOS EXECUTIVE SALES & PROFIT REPORT')]);
    summarySheet.appendRow([TextCellValue('Store Name:'), TextCellValue(settings.storeName.isNotEmpty ? settings.storeName : 'OmniPOS')]);
    summarySheet.appendRow([TextCellValue('Reporting Period:'), TextCellValue(dateRangeStr)]);
    summarySheet.appendRow([TextCellValue('Generated At:'), TextCellValue(generatedAt)]);
    summarySheet.appendRow([TextCellValue('Currency:'), TextCellValue(currency)]);
    summarySheet.appendRow([TextCellValue('')]);

    // Financial Metrics Header
    summarySheet.appendRow([TextCellValue('FINANCIAL METRIC'), TextCellValue('AMOUNT / VALUE'), TextCellValue('NOTES')]);
    summarySheet.appendRow([
      TextCellValue('Total Revenue (Net Sales)'),
      TextCellValue('$currency${metrics.totalRevenue.toStringAsFixed(2)}'),
      TextCellValue('Total revenue collected from completed orders'),
    ]);
    summarySheet.appendRow([
      TextCellValue('Gross Sales (Before Discounts)'),
      TextCellValue('$currency${(totalGrossSales > 0 ? totalGrossSales : metrics.totalRevenue).toStringAsFixed(2)}'),
      TextCellValue('Subtotal of all items before discounts and tax'),
    ]);
    summarySheet.appendRow([
      TextCellValue('Estimated Cost of Goods (COGS)'),
      TextCellValue('$currency${metrics.totalCost.toStringAsFixed(2)}'),
      TextCellValue('Total product purchase / production cost'),
    ]);
    summarySheet.appendRow([
      TextCellValue('Net Gross Profit'),
      TextCellValue('$currency${metrics.grossProfit.toStringAsFixed(2)}'),
      TextCellValue('Revenue minus Cost of Goods'),
    ]);
    summarySheet.appendRow([
      TextCellValue('Gross Profit Margin'),
      TextCellValue('${profitMargin.toStringAsFixed(1)}%'),
      TextCellValue('Profit as percentage of total revenue'),
    ]);
    summarySheet.appendRow([
      TextCellValue('Total Discounts Given'),
      TextCellValue('$currency${totalDiscount.toStringAsFixed(2)}'),
      TextCellValue('Total discounts applied across all orders'),
    ]);
    summarySheet.appendRow([
      TextCellValue('Total Tax Collected'),
      TextCellValue('$currency${totalTax.toStringAsFixed(2)}'),
      TextCellValue('Sales tax / VAT collected'),
    ]);
    summarySheet.appendRow([
      TextCellValue('Completed Orders Count'),
      IntCellValue(metrics.totalOrders > 0 ? metrics.totalOrders : orders.length),
      TextCellValue('Total completed transactions'),
    ]);
    summarySheet.appendRow([
      TextCellValue('Total Items Sold'),
      IntCellValue(metrics.totalItemsSold),
      TextCellValue('Total menu item quantity sold'),
    ]);
    summarySheet.appendRow([
      TextCellValue('Average Order Value (AOV)'),
      TextCellValue('$currency${metrics.averageOrderValue.toStringAsFixed(2)}'),
      TextCellValue('Average spending per order'),
    ]);
    summarySheet.appendRow([TextCellValue('')]);

    // Payment Methods Breakdown
    summarySheet.appendRow([TextCellValue('PAYMENT METHOD'), TextCellValue('REVENUE ($currency)'), TextCellValue('TRANSACTIONS'), TextCellValue('SHARE %')]);
    final double cashShare = metrics.totalRevenue > 0 ? (metrics.cashRevenue / metrics.totalRevenue) * 100 : 0.0;
    final double qrShare = metrics.totalRevenue > 0 ? (metrics.qrRevenue / metrics.totalRevenue) * 100 : 0.0;

    summarySheet.appendRow([
      TextCellValue('Cash Payment'),
      DoubleCellValue(metrics.cashRevenue),
      IntCellValue(metrics.cashOrderCount),
      TextCellValue('${cashShare.toStringAsFixed(1)}%'),
    ]);
    summarySheet.appendRow([
      TextCellValue('QR Code / Digital Payment'),
      DoubleCellValue(metrics.qrRevenue),
      IntCellValue(metrics.qrOrderCount),
      TextCellValue('${qrShare.toStringAsFixed(1)}%'),
    ]);

    // -------------------------------------------------------------
    // SHEET 2: Product Profitability
    // -------------------------------------------------------------
    final topSheet = excel['Product Profitability'];
    topSheet.appendRow([
      TextCellValue('Rank'),
      TextCellValue('Product Name'),
      TextCellValue('Quantity Sold'),
      TextCellValue('Total Revenue ($currency)'),
      TextCellValue('Est. Profit Share'),
    ]);

    for (var i = 0; i < topItems.length; i++) {
      final t = topItems[i];
      final double share = metrics.totalRevenue > 0 ? (t.totalRevenue / metrics.totalRevenue) * 100 : 0.0;
      topSheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(t.productName),
        IntCellValue(t.totalQuantity),
        DoubleCellValue(t.totalRevenue),
        TextCellValue('${share.toStringAsFixed(1)}%'),
      ]);
    }

    // -------------------------------------------------------------
    // SHEET 3: Orders Register
    // -------------------------------------------------------------
    final ordersSheet = excel['Orders Register'];
    ordersSheet.appendRow([
      TextCellValue('Receipt No'),
      TextCellValue('Daily Order #'),
      TextCellValue('Date / Time'),
      TextCellValue('Order Type'),
      TextCellValue('Table / Spot'),
      TextCellValue('Customer Name'),
      TextCellValue('Item Count'),
      TextCellValue('Subtotal ($currency)'),
      TextCellValue('Discount ($currency)'),
      TextCellValue('Tax ($currency)'),
      TextCellValue('Total Amount ($currency)'),
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
    // SHEET 4: Itemized Sales Details
    // -------------------------------------------------------------
    final itemsSheet = excel['Itemized Sales Details'];
    itemsSheet.appendRow([
      TextCellValue('Receipt No'),
      TextCellValue('Date'),
      TextCellValue('Product Name'),
      TextCellValue('Quantity'),
      TextCellValue('Unit Price ($currency)'),
      TextCellValue('Total Revenue ($currency)'),
      TextCellValue('Special Notes'),
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
    // SHEET 5: Audit & Receipt Logs
    // -------------------------------------------------------------
    final logsSheet = excel['Audit & Receipt Logs'];
    logsSheet.appendRow([
      TextCellValue('Log ID'),
      TextCellValue('Receipt No'),
      TextCellValue('Order ID'),
      TextCellValue('Action'),
      TextCellValue('Timestamp'),
      TextCellValue('Status'),
      TextCellValue('File Reference'),
    ]);

    for (var l in logs) {
      logsSheet.appendRow([
        TextCellValue(l.id),
        TextCellValue(l.receiptNo),
        TextCellValue(l.orderId),
        TextCellValue(l.action),
        TextCellValue(DateFormat('yyyy-MM-dd HH:mm:ss').format(l.timestamp)),
        TextCellValue(l.isSuccess ? 'SUCCESS' : 'FAILED'),
        TextCellValue(l.receiptFilePath ?? ''),
      ]);
    }

    // Encode bytes
    final fileBytes = excel.encode();
    if (fileBytes == null) {
      throw Exception('Failed to generate Excel file bytes');
    }

    final timestampStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'OmniPOS_Sales_Profit_Report_$timestampStr.xlsx';

    // 1. Request Android Storage Permission & write to public Downloads folder
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

  /// Share Excel file via system share sheet
  Future<ShareResult> shareExcelFile(String filePath) async {
    return await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        subject: 'OmniPOS Sales & Profit Report',
      ),
    );
  }
}
