import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/order_dao.dart';
import '../models/order_model.dart';
import '../models/accounting_model.dart';
import '../models/store_settings_model.dart';

class ExcelExportService {
  static final ExcelExportService _instance = ExcelExportService._internal();
  factory ExcelExportService() => _instance;
  ExcelExportService._internal();

  // -------------------------------------------------------------
  // Corporate Design System & Styles for Excel Templates
  // -------------------------------------------------------------
  static final Border _thinBorder = Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.fromHexString('#CBD5E1'),
  );

  // Sheet Title Block: Navy slate #0F172A, bold white text, 13pt
  static final CellStyle _titleStyle = CellStyle(
    fontFamily: getFontFamily(FontFamily.Calibri),
    fontSize: 13,
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    backgroundColorHex: ExcelColor.fromHexString('#0F172A'),
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
  );

  // Metadata key / label: light slate fill #F1F5F9, dark slate text #475569, bold 10pt
  static final CellStyle _metaLabelStyle = CellStyle(
    fontFamily: getFontFamily(FontFamily.Calibri),
    fontSize: 10,
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#475569'),
    backgroundColorHex: ExcelColor.fromHexString('#F1F5F9'),
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
    rightBorder: _thinBorder,
  );

  // Metadata value: white background, #1E293B text, 10pt
  static final CellStyle _metaValueStyle = CellStyle(
    fontFamily: getFontFamily(FontFamily.Calibri),
    fontSize: 10,
    bold: false,
    fontColorHex: ExcelColor.fromHexString('#1E293B'),
    backgroundColorHex: ExcelColor.fromHexString('#FFFFFF'),
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
    rightBorder: _thinBorder,
  );

  // Primary Table Header: Deep Corporate Teal #0F766E, bold white text, 11pt
  static final CellStyle _tableHeaderLeftStyle = CellStyle(
    fontFamily: getFontFamily(FontFamily.Calibri),
    fontSize: 11,
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    backgroundColorHex: ExcelColor.fromHexString('#0F766E'),
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
    rightBorder: _thinBorder,
  );

  static final CellStyle _tableHeaderCenterStyle = CellStyle(
    fontFamily: getFontFamily(FontFamily.Calibri),
    fontSize: 11,
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    backgroundColorHex: ExcelColor.fromHexString('#0F766E'),
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
    rightBorder: _thinBorder,
  );

  static final CellStyle _tableHeaderRightStyle = CellStyle(
    fontFamily: getFontFamily(FontFamily.Calibri),
    fontSize: 11,
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    backgroundColorHex: ExcelColor.fromHexString('#0F766E'),
    horizontalAlign: HorizontalAlign.Right,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
    rightBorder: _thinBorder,
  );

  // Sub-Header: Slate #334155, bold white text, 10pt
  static final CellStyle _subHeaderLeftStyle = CellStyle(
    fontFamily: getFontFamily(FontFamily.Calibri),
    fontSize: 10,
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    backgroundColorHex: ExcelColor.fromHexString('#334155'),
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
    rightBorder: _thinBorder,
  );

  static final CellStyle _subHeaderRightStyle = CellStyle(
    fontFamily: getFontFamily(FontFamily.Calibri),
    fontSize: 10,
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    backgroundColorHex: ExcelColor.fromHexString('#334155'),
    horizontalAlign: HorizontalAlign.Right,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
    rightBorder: _thinBorder,
  );

  static final CellStyle _subHeaderCenterStyle = CellStyle(
    fontFamily: getFontFamily(FontFamily.Calibri),
    fontSize: 10,
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    backgroundColorHex: ExcelColor.fromHexString('#334155'),
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
    rightBorder: _thinBorder,
  );

  // Data rows (White)
  static final CellStyle _dataLeftStyle = CellStyle(
    fontFamily: getFontFamily(FontFamily.Calibri),
    fontSize: 10,
    fontColorHex: ExcelColor.fromHexString('#1E293B'),
    backgroundColorHex: ExcelColor.fromHexString('#FFFFFF'),
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
    rightBorder: _thinBorder,
  );

  static final CellStyle _dataCenterStyle = CellStyle(
    fontFamily: getFontFamily(FontFamily.Calibri),
    fontSize: 10,
    fontColorHex: ExcelColor.fromHexString('#1E293B'),
    backgroundColorHex: ExcelColor.fromHexString('#FFFFFF'),
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
    rightBorder: _thinBorder,
  );

  static final CellStyle _dataRightStyle = CellStyle(
    fontFamily: getFontFamily(FontFamily.Calibri),
    fontSize: 10,
    fontColorHex: ExcelColor.fromHexString('#0F172A'),
    backgroundColorHex: ExcelColor.fromHexString('#FFFFFF'),
    horizontalAlign: HorizontalAlign.Right,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
    rightBorder: _thinBorder,
  );

  // Data rows (Alternating / Zebra Stripe #F8FAFC)
  static final CellStyle _dataLeftZebraStyle = CellStyle(
    fontFamily: getFontFamily(FontFamily.Calibri),
    fontSize: 10,
    fontColorHex: ExcelColor.fromHexString('#1E293B'),
    backgroundColorHex: ExcelColor.fromHexString('#F8FAFC'),
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
    rightBorder: _thinBorder,
  );

  static final CellStyle _dataCenterZebraStyle = CellStyle(
    fontFamily: getFontFamily(FontFamily.Calibri),
    fontSize: 10,
    fontColorHex: ExcelColor.fromHexString('#1E293B'),
    backgroundColorHex: ExcelColor.fromHexString('#F8FAFC'),
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
    rightBorder: _thinBorder,
  );

  static final CellStyle _dataRightZebraStyle = CellStyle(
    fontFamily: getFontFamily(FontFamily.Calibri),
    fontSize: 10,
    fontColorHex: ExcelColor.fromHexString('#0F172A'),
    backgroundColorHex: ExcelColor.fromHexString('#F8FAFC'),
    horizontalAlign: HorizontalAlign.Right,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
    rightBorder: _thinBorder,
  );

  // Highlight / Summary / Total Row: Soft Teal #CCFBF1, bold dark teal text #0F766E
  static final CellStyle _totalRowLeftStyle = CellStyle(
    fontFamily: getFontFamily(FontFamily.Calibri),
    fontSize: 10,
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#0F766E'),
    backgroundColorHex: ExcelColor.fromHexString('#CCFBF1'),
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
    rightBorder: _thinBorder,
  );

  static final CellStyle _totalRowCenterStyle = CellStyle(
    fontFamily: getFontFamily(FontFamily.Calibri),
    fontSize: 10,
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#0F766E'),
    backgroundColorHex: ExcelColor.fromHexString('#CCFBF1'),
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
    rightBorder: _thinBorder,
  );

  static final CellStyle _totalRowRightStyle = CellStyle(
    fontFamily: getFontFamily(FontFamily.Calibri),
    fontSize: 10,
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#0F766E'),
    backgroundColorHex: ExcelColor.fromHexString('#CCFBF1'),
    horizontalAlign: HorizontalAlign.Right,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
    rightBorder: _thinBorder,
  );

  // Status Badges
  static final CellStyle _badgeSuccessStyle = CellStyle(
    fontFamily: getFontFamily(FontFamily.Calibri),
    fontSize: 10,
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#166534'),
    backgroundColorHex: ExcelColor.fromHexString('#DCFCE7'),
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
    rightBorder: _thinBorder,
  );

  static final CellStyle _badgePendingStyle = CellStyle(
    fontFamily: getFontFamily(FontFamily.Calibri),
    fontSize: 10,
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#854D0E'),
    backgroundColorHex: ExcelColor.fromHexString('#FEF9C3'),
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
    rightBorder: _thinBorder,
  );

  static final CellStyle _badgeFailedStyle = CellStyle(
    fontFamily: getFontFamily(FontFamily.Calibri),
    fontSize: 10,
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#991B1B'),
    backgroundColorHex: ExcelColor.fromHexString('#FEE2E2'),
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
    rightBorder: _thinBorder,
  );

  /// Helper to append a styled row into a sheet
  void _appendStyledRow(
    Sheet sheet,
    List<CellValue?> values, {
    CellStyle? defaultStyle,
    List<CellStyle?>? cellStyles,
  }) {
    final rowIndex = sheet.maxRows;
    sheet.appendRow(values);
    for (var col = 0; col < values.length; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
      );
      if (cellStyles != null && col < cellStyles.length && cellStyles[col] != null) {
        cell.cellStyle = cellStyles[col];
      } else if (defaultStyle != null) {
        cell.cellStyle = defaultStyle;
      }
    }
  }

  /// Request storage permission on Android
  Future<bool> requestStoragePermission() async {
    return true;
  }

  /// Export Profit & Loss Reports to a beautifully formatted .xlsx file
  Future<String> exportProfitLossReports({
    required List<ProfitLossReportModel> reports,
    required StoreSettingsModel settings,
    required String periodLabel,
  }) async {
    final excel = Excel.createExcel();
    final defaultSheetName = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheetName, 'P&L Reports');
    excel.setDefaultSheet('P&L Reports');

    final sheet = excel['P&L Reports'];
    final currency = settings.currencySymbol;
    final generatedAt = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    // Title Block
    _appendStyledRow(
      sheet,
      [TextCellValue('OMNIPOS PROFIT & LOSS FINANCIAL REPORT')],
      defaultStyle: _titleStyle,
    );

    // Metadata
    _appendStyledRow(sheet, [
      TextCellValue('Store / Organization:'),
      TextCellValue(settings.storeName.isNotEmpty ? settings.storeName : 'OmniPOS'),
    ], cellStyles: [_metaLabelStyle, _metaValueStyle]);

    _appendStyledRow(sheet, [
      TextCellValue('Reporting Period:'),
      TextCellValue(periodLabel),
    ], cellStyles: [_metaLabelStyle, _metaValueStyle]);

    _appendStyledRow(sheet, [
      TextCellValue('Generated At:'),
      TextCellValue(generatedAt),
    ], cellStyles: [_metaLabelStyle, _metaValueStyle]);

    _appendStyledRow(sheet, [
      TextCellValue('Currency:'),
      TextCellValue(currency),
    ], cellStyles: [_metaLabelStyle, _metaValueStyle]);

    sheet.appendRow([TextCellValue('')]);

    // Headers
    _appendStyledRow(
      sheet,
      [
        TextCellValue('Branch / Store'),
        TextCellValue('Gross Sales ($currency)'),
        TextCellValue('COGS ($currency)'),
        TextCellValue('Gross Profit ($currency)'),
        TextCellValue('Operating Expenses ($currency)'),
        TextCellValue('Rent / Royalty ($currency)'),
        TextCellValue('Net Operating Income ($currency)'),
        TextCellValue('Other Income ($currency)'),
        TextCellValue('Other Expenses ($currency)'),
        TextCellValue('Net Income ($currency)'),
      ],
      cellStyles: [
        _tableHeaderLeftStyle,
        _tableHeaderRightStyle,
        _tableHeaderRightStyle,
        _tableHeaderRightStyle,
        _tableHeaderRightStyle,
        _tableHeaderRightStyle,
        _tableHeaderRightStyle,
        _tableHeaderRightStyle,
        _tableHeaderRightStyle,
        _tableHeaderRightStyle,
      ],
    );

    double totalGrossSales = 0.0;
    double totalCogs = 0.0;
    double totalGrossProfit = 0.0;
    double totalOpex = 0.0;
    double totalRent = 0.0;
    double totalNetOperating = 0.0;
    double totalOtherInc = 0.0;
    double totalOtherExp = 0.0;
    double totalNetIncome = 0.0;

    for (var i = 0; i < reports.length; i++) {
      final report = reports[i];
      final isZebra = (i % 2 == 1);
      final leftStyle = isZebra ? _dataLeftZebraStyle : _dataLeftStyle;
      final rightStyle = isZebra ? _dataRightZebraStyle : _dataRightStyle;

      totalGrossSales += report.grossSalesRevenue;
      totalCogs += report.costOfSales;
      totalGrossProfit += report.grossProfit;
      totalOpex += report.operatingExpenses;
      totalRent += report.totalHybridSettlementToMainBoss;
      totalNetOperating += report.netOperatingIncome;
      totalOtherInc += report.otherIncome;
      totalOtherExp += report.otherExpenses;
      totalNetIncome += report.netIncome;

      _appendStyledRow(
        sheet,
        [
          TextCellValue(report.branchName),
          DoubleCellValue(report.grossSalesRevenue),
          DoubleCellValue(report.costOfSales),
          DoubleCellValue(report.grossProfit),
          DoubleCellValue(report.operatingExpenses),
          DoubleCellValue(report.totalHybridSettlementToMainBoss),
          DoubleCellValue(report.netOperatingIncome),
          DoubleCellValue(report.otherIncome),
          DoubleCellValue(report.otherExpenses),
          DoubleCellValue(report.netIncome),
        ],
        cellStyles: [
          leftStyle,
          rightStyle,
          rightStyle,
          rightStyle,
          rightStyle,
          rightStyle,
          rightStyle,
          rightStyle,
          rightStyle,
          rightStyle,
        ],
      );
    }

    // Grand Total Row
    if (reports.isNotEmpty) {
      _appendStyledRow(
        sheet,
        [
          TextCellValue('GRAND TOTAL (${reports.length} branches)'),
          DoubleCellValue(totalGrossSales),
          DoubleCellValue(totalCogs),
          DoubleCellValue(totalGrossProfit),
          DoubleCellValue(totalOpex),
          DoubleCellValue(totalRent),
          DoubleCellValue(totalNetOperating),
          DoubleCellValue(totalOtherInc),
          DoubleCellValue(totalOtherExp),
          DoubleCellValue(totalNetIncome),
        ],
        cellStyles: [
          _totalRowLeftStyle,
          _totalRowRightStyle,
          _totalRowRightStyle,
          _totalRowRightStyle,
          _totalRowRightStyle,
          _totalRowRightStyle,
          _totalRowRightStyle,
          _totalRowRightStyle,
          _totalRowRightStyle,
          _totalRowRightStyle,
        ],
      );
    }

    // Set Column Widths for professional readability
    sheet.setColumnWidth(0, 28.0);
    sheet.setColumnWidth(1, 20.0);
    sheet.setColumnWidth(2, 18.0);
    sheet.setColumnWidth(3, 20.0);
    sheet.setColumnWidth(4, 24.0);
    sheet.setColumnWidth(5, 20.0);
    sheet.setColumnWidth(6, 26.0);
    sheet.setColumnWidth(7, 18.0);
    sheet.setColumnWidth(8, 18.0);
    sheet.setColumnWidth(9, 22.0);

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Failed to generate P&L Excel file');
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'OmniPOS_PL_Reports_${periodLabel.replaceAll(' ', '_')}_$timestamp.xlsx';

    return await _saveExcelBytes(bytes, fileName);
  }

  /// Export Sales & Profit Report to a complete professional multi-sheet .xlsx workbook
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

    // Setup Default Sheet
    final defaultSheetName = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheetName, 'Sales & Profit Summary');
    excel.setDefaultSheet('Sales & Profit Summary');

    final dateRangeStr = (startDate != null && endDate != null)
        ? '${DateFormat('yyyy-MM-dd').format(startDate)} to ${DateFormat('yyyy-MM-dd').format(endDate)}'
        : 'All Time / Complete History';
    final generatedAt = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final currency = settings.currencySymbol;

    // Calculate totals
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

    // =============================================================
    // SHEET 1: Sales & Profit Summary (Executive Dashboard)
    // =============================================================
    final summarySheet = excel['Sales & Profit Summary'];

    // Title Block
    _appendStyledRow(
      summarySheet,
      [TextCellValue('OMNIPOS EXECUTIVE SALES & PROFIT REPORT')],
      defaultStyle: _titleStyle,
    );

    // Meta Block
    _appendStyledRow(summarySheet, [
      TextCellValue('Store Name:'),
      TextCellValue(settings.storeName.isNotEmpty ? settings.storeName : 'OmniPOS'),
    ], cellStyles: [_metaLabelStyle, _metaValueStyle]);

    _appendStyledRow(summarySheet, [
      TextCellValue('Reporting Period:'),
      TextCellValue(dateRangeStr),
    ], cellStyles: [_metaLabelStyle, _metaValueStyle]);

    _appendStyledRow(summarySheet, [
      TextCellValue('Generated At:'),
      TextCellValue(generatedAt),
    ], cellStyles: [_metaLabelStyle, _metaValueStyle]);

    _appendStyledRow(summarySheet, [
      TextCellValue('Currency:'),
      TextCellValue(currency),
    ], cellStyles: [_metaLabelStyle, _metaValueStyle]);

    summarySheet.appendRow([TextCellValue('')]);

    // Financial Metrics Header
    _appendStyledRow(
      summarySheet,
      [
        TextCellValue('FINANCIAL METRIC'),
        TextCellValue('AMOUNT / VALUE'),
        TextCellValue('EXPLANATORY NOTES'),
      ],
      cellStyles: [
        _tableHeaderLeftStyle,
        _tableHeaderRightStyle,
        _tableHeaderLeftStyle,
      ],
    );

    // KPI Rows
    final kpis = [
      (
        'Total Revenue (Net Sales)',
        '$currency${metrics.totalRevenue.toStringAsFixed(2)}',
        'Total revenue collected from completed orders',
        true,
      ),
      (
        'Gross Sales (Before Discounts)',
        '$currency${(totalGrossSales > 0 ? totalGrossSales : metrics.totalRevenue).toStringAsFixed(2)}',
        'Subtotal of all items before discounts and tax',
        false,
      ),
      (
        'Estimated Cost of Goods (COGS)',
        '$currency${metrics.totalCost.toStringAsFixed(2)}',
        'Total product purchase / production cost',
        false,
      ),
      (
        'Net Gross Profit',
        '$currency${metrics.grossProfit.toStringAsFixed(2)}',
        'Revenue minus Cost of Goods',
        true,
      ),
      (
        'Gross Profit Margin',
        '${profitMargin.toStringAsFixed(1)}%',
        'Gross profit expressed as percentage of total revenue',
        false,
      ),
      (
        'Total Discounts Given',
        '$currency${totalDiscount.toStringAsFixed(2)}',
        'Total discounts applied across all customer orders',
        false,
      ),
      (
        'Total Tax Collected',
        '$currency${totalTax.toStringAsFixed(2)}',
        'Sales tax / VAT collected for government remittance',
        false,
      ),
      (
        'Completed Orders Count',
        '${metrics.totalOrders > 0 ? metrics.totalOrders : orders.length}',
        'Total successfully completed transactions',
        false,
      ),
      (
        'Total Items Sold',
        '${metrics.totalItemsSold}',
        'Total menu item units sold',
        false,
      ),
      (
        'Average Order Value (AOV)',
        '$currency${metrics.averageOrderValue.toStringAsFixed(2)}',
        'Average customer spending per transaction',
        false,
      ),
    ];

    for (var i = 0; i < kpis.length; i++) {
      final item = kpis[i];
      final isZebra = (i % 2 == 1);
      final isHighlight = item.$4;

      final leftStyle = isHighlight
          ? _totalRowLeftStyle
          : (isZebra ? _dataLeftZebraStyle : _dataLeftStyle);
      final rightStyle = isHighlight
          ? _totalRowRightStyle
          : (isZebra ? _dataRightZebraStyle : _dataRightStyle);
      final noteStyle = isHighlight
          ? _totalRowLeftStyle
          : (isZebra ? _dataLeftZebraStyle : _dataLeftStyle);

      _appendStyledRow(
        summarySheet,
        [
          TextCellValue(item.$1),
          TextCellValue(item.$2),
          TextCellValue(item.$3),
        ],
        cellStyles: [leftStyle, rightStyle, noteStyle],
      );
    }

    summarySheet.appendRow([TextCellValue('')]);

    // Payment Methods Breakdown Header
    _appendStyledRow(
      summarySheet,
      [
        TextCellValue('PAYMENT METHOD'),
        TextCellValue('REVENUE ($currency)'),
        TextCellValue('TRANSACTIONS'),
        TextCellValue('REVENUE SHARE %'),
      ],
      cellStyles: [
        _subHeaderLeftStyle,
        _subHeaderRightStyle,
        _subHeaderCenterStyle,
        _subHeaderRightStyle,
      ],
    );

    final double cashShare = metrics.totalRevenue > 0
        ? (metrics.cashRevenue / metrics.totalRevenue) * 100
        : 0.0;
    final double qrShare = metrics.totalRevenue > 0
        ? (metrics.qrRevenue / metrics.totalRevenue) * 100
        : 0.0;

    _appendStyledRow(
      summarySheet,
      [
        TextCellValue('Cash Payment'),
        DoubleCellValue(metrics.cashRevenue),
        IntCellValue(metrics.cashOrderCount),
        TextCellValue('${cashShare.toStringAsFixed(1)}%'),
      ],
      cellStyles: [
        _dataLeftStyle,
        _dataRightStyle,
        _dataCenterStyle,
        _dataRightStyle,
      ],
    );

    _appendStyledRow(
      summarySheet,
      [
        TextCellValue('QR Code / Digital Payment'),
        DoubleCellValue(metrics.qrRevenue),
        IntCellValue(metrics.qrOrderCount),
        TextCellValue('${qrShare.toStringAsFixed(1)}%'),
      ],
      cellStyles: [
        _dataLeftZebraStyle,
        _dataRightZebraStyle,
        _dataCenterZebraStyle,
        _dataRightZebraStyle,
      ],
    );

    _appendStyledRow(
      summarySheet,
      [
        TextCellValue('TOTAL PAYMENTS'),
        DoubleCellValue(metrics.cashRevenue + metrics.qrRevenue),
        IntCellValue(metrics.cashOrderCount + metrics.qrOrderCount),
        TextCellValue('100.0%'),
      ],
      cellStyles: [
        _totalRowLeftStyle,
        _totalRowRightStyle,
        _totalRowCenterStyle,
        _totalRowRightStyle,
      ],
    );

    // Set Column Widths for Sheet 1
    summarySheet.setColumnWidth(0, 36.0);
    summarySheet.setColumnWidth(1, 24.0);
    summarySheet.setColumnWidth(2, 48.0);
    summarySheet.setColumnWidth(3, 20.0);

    // =============================================================
    // SHEET 2: Product Profitability
    // =============================================================
    final topSheet = excel['Product Profitability'];

    _appendStyledRow(
      topSheet,
      [TextCellValue('PRODUCT SALES & PROFITABILITY RANKING')],
      defaultStyle: _titleStyle,
    );

    _appendStyledRow(topSheet, [
      TextCellValue('Total Products Tracked:'),
      TextCellValue('${topItems.length} items'),
    ], cellStyles: [_metaLabelStyle, _metaValueStyle]);

    topSheet.appendRow([TextCellValue('')]);

    _appendStyledRow(
      topSheet,
      [
        TextCellValue('Rank'),
        TextCellValue('Product Name'),
        TextCellValue('Quantity Sold'),
        TextCellValue('Total Revenue ($currency)'),
        TextCellValue('Est. Revenue Share'),
      ],
      cellStyles: [
        _tableHeaderCenterStyle,
        _tableHeaderLeftStyle,
        _tableHeaderCenterStyle,
        _tableHeaderRightStyle,
        _tableHeaderRightStyle,
      ],
    );

    int totalTopQty = 0;
    double totalTopRevenue = 0.0;

    for (var i = 0; i < topItems.length; i++) {
      final t = topItems[i];
      final isZebra = (i % 2 == 1);
      final double share = metrics.totalRevenue > 0
          ? (t.totalRevenue / metrics.totalRevenue) * 100
          : 0.0;

      totalTopQty += t.totalQuantity;
      totalTopRevenue += t.totalRevenue;

      _appendStyledRow(
        topSheet,
        [
          IntCellValue(i + 1),
          TextCellValue(t.productName),
          IntCellValue(t.totalQuantity),
          DoubleCellValue(t.totalRevenue),
          TextCellValue('${share.toStringAsFixed(1)}%'),
        ],
        cellStyles: [
          isZebra ? _dataCenterZebraStyle : _dataCenterStyle,
          isZebra ? _dataLeftZebraStyle : _dataLeftStyle,
          isZebra ? _dataCenterZebraStyle : _dataCenterStyle,
          isZebra ? _dataRightZebraStyle : _dataRightStyle,
          isZebra ? _dataRightZebraStyle : _dataRightStyle,
        ],
      );
    }

    if (topItems.isNotEmpty) {
      _appendStyledRow(
        topSheet,
        [
          TextCellValue('TOTAL'),
          TextCellValue('${topItems.length} Products'),
          IntCellValue(totalTopQty),
          DoubleCellValue(totalTopRevenue),
          TextCellValue('100.0%'),
        ],
        cellStyles: [
          _totalRowCenterStyle,
          _totalRowLeftStyle,
          _totalRowCenterStyle,
          _totalRowRightStyle,
          _totalRowRightStyle,
        ],
      );
    }

    topSheet.setColumnWidth(0, 10.0);
    topSheet.setColumnWidth(1, 38.0);
    topSheet.setColumnWidth(2, 18.0);
    topSheet.setColumnWidth(3, 24.0);
    topSheet.setColumnWidth(4, 22.0);

    // =============================================================
    // SHEET 3: Orders Register
    // =============================================================
    final ordersSheet = excel['Orders Register'];

    _appendStyledRow(
      ordersSheet,
      [
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
      ],
      cellStyles: [
        _tableHeaderCenterStyle,
        _tableHeaderCenterStyle,
        _tableHeaderCenterStyle,
        _tableHeaderCenterStyle,
        _tableHeaderCenterStyle,
        _tableHeaderLeftStyle,
        _tableHeaderCenterStyle,
        _tableHeaderRightStyle,
        _tableHeaderRightStyle,
        _tableHeaderRightStyle,
        _tableHeaderRightStyle,
        _tableHeaderCenterStyle,
        _tableHeaderCenterStyle,
      ],
    );

    int sumItemCount = 0;
    double sumSubtotal = 0.0;
    double sumDiscount = 0.0;
    double sumTax = 0.0;
    double sumTotal = 0.0;

    for (var i = 0; i < orders.length; i++) {
      final o = orders[i];
      final isZebra = (i % 2 == 1);
      final itemCount = o.items.fold(0, (sum, item) => sum + item.quantity);

      sumItemCount += itemCount;
      sumSubtotal += o.subtotal;
      sumDiscount += o.discountAmount;
      sumTax += o.taxAmount;
      sumTotal += o.totalAmount;

      CellStyle statusStyle = _badgeSuccessStyle;
      if (o.status == OrderStatus.pending) {
        statusStyle = _badgePendingStyle;
      } else if (o.status == OrderStatus.cancelled) {
        statusStyle = _badgeFailedStyle;
      }

      _appendStyledRow(
        ordersSheet,
        [
          TextCellValue(o.receiptNo),
          TextCellValue(o.orderNumber != null ? '#${o.orderNumber}' : ''),
          TextCellValue(DateFormat('yyyy-MM-dd HH:mm:ss').format(o.createdAt)),
          TextCellValue(o.orderType),
          TextCellValue(o.tableNumber ?? 'N/A'),
          TextCellValue(o.customerName ?? 'Guest'),
          IntCellValue(itemCount),
          DoubleCellValue(o.subtotal),
          DoubleCellValue(o.discountAmount),
          DoubleCellValue(o.taxAmount),
          DoubleCellValue(o.totalAmount),
          TextCellValue(o.paymentMethod.displayName),
          TextCellValue(o.status.displayName),
        ],
        cellStyles: [
          isZebra ? _dataCenterZebraStyle : _dataCenterStyle,
          isZebra ? _dataCenterZebraStyle : _dataCenterStyle,
          isZebra ? _dataCenterZebraStyle : _dataCenterStyle,
          isZebra ? _dataCenterZebraStyle : _dataCenterStyle,
          isZebra ? _dataCenterZebraStyle : _dataCenterStyle,
          isZebra ? _dataLeftZebraStyle : _dataLeftStyle,
          isZebra ? _dataCenterZebraStyle : _dataCenterStyle,
          isZebra ? _dataRightZebraStyle : _dataRightStyle,
          isZebra ? _dataRightZebraStyle : _dataRightStyle,
          isZebra ? _dataRightZebraStyle : _dataRightStyle,
          isZebra ? _dataRightZebraStyle : _dataRightStyle,
          isZebra ? _dataCenterZebraStyle : _dataCenterStyle,
          statusStyle,
        ],
      );
    }

    if (orders.isNotEmpty) {
      _appendStyledRow(
        ordersSheet,
        [
          TextCellValue('TOTAL (${orders.length} orders)'),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          IntCellValue(sumItemCount),
          DoubleCellValue(sumSubtotal),
          DoubleCellValue(sumDiscount),
          DoubleCellValue(sumTax),
          DoubleCellValue(sumTotal),
          TextCellValue(''),
          TextCellValue(''),
        ],
        cellStyles: [
          _totalRowLeftStyle,
          _totalRowCenterStyle,
          _totalRowCenterStyle,
          _totalRowCenterStyle,
          _totalRowCenterStyle,
          _totalRowLeftStyle,
          _totalRowCenterStyle,
          _totalRowRightStyle,
          _totalRowRightStyle,
          _totalRowRightStyle,
          _totalRowRightStyle,
          _totalRowCenterStyle,
          _totalRowCenterStyle,
        ],
      );
    }

    ordersSheet.setColumnWidth(0, 24.0);
    ordersSheet.setColumnWidth(1, 16.0);
    ordersSheet.setColumnWidth(2, 22.0);
    ordersSheet.setColumnWidth(3, 16.0);
    ordersSheet.setColumnWidth(4, 16.0);
    ordersSheet.setColumnWidth(5, 22.0);
    ordersSheet.setColumnWidth(6, 14.0);
    ordersSheet.setColumnWidth(7, 18.0);
    ordersSheet.setColumnWidth(8, 16.0);
    ordersSheet.setColumnWidth(9, 14.0);
    ordersSheet.setColumnWidth(10, 20.0);
    ordersSheet.setColumnWidth(11, 18.0);
    ordersSheet.setColumnWidth(12, 16.0);

    // =============================================================
    // SHEET 4: Itemized Sales Details
    // =============================================================
    final itemsSheet = excel['Itemized Sales Details'];

    _appendStyledRow(
      itemsSheet,
      [
        TextCellValue('Receipt No'),
        TextCellValue('Date'),
        TextCellValue('Product Name'),
        TextCellValue('Quantity'),
        TextCellValue('Unit Price ($currency)'),
        TextCellValue('Total Revenue ($currency)'),
        TextCellValue('Special Notes'),
      ],
      cellStyles: [
        _tableHeaderCenterStyle,
        _tableHeaderCenterStyle,
        _tableHeaderLeftStyle,
        _tableHeaderCenterStyle,
        _tableHeaderRightStyle,
        _tableHeaderRightStyle,
        _tableHeaderLeftStyle,
      ],
    );

    int rowIndex = 0;
    for (var o in orders) {
      for (var item in o.items) {
        final isZebra = (rowIndex % 2 == 1);
        rowIndex++;

        _appendStyledRow(
          itemsSheet,
          [
            TextCellValue(o.receiptNo),
            TextCellValue(DateFormat('yyyy-MM-dd').format(o.createdAt)),
            TextCellValue(item.productName),
            IntCellValue(item.quantity),
            DoubleCellValue(item.unitPrice),
            DoubleCellValue(item.totalPrice),
            TextCellValue(item.notes ?? ''),
          ],
          cellStyles: [
            isZebra ? _dataCenterZebraStyle : _dataCenterStyle,
            isZebra ? _dataCenterZebraStyle : _dataCenterStyle,
            isZebra ? _dataLeftZebraStyle : _dataLeftStyle,
            isZebra ? _dataCenterZebraStyle : _dataCenterStyle,
            isZebra ? _dataRightZebraStyle : _dataRightStyle,
            isZebra ? _dataRightZebraStyle : _dataRightStyle,
            isZebra ? _dataLeftZebraStyle : _dataLeftStyle,
          ],
        );
      }
    }

    itemsSheet.setColumnWidth(0, 24.0);
    itemsSheet.setColumnWidth(1, 16.0);
    itemsSheet.setColumnWidth(2, 34.0);
    itemsSheet.setColumnWidth(3, 14.0);
    itemsSheet.setColumnWidth(4, 18.0);
    itemsSheet.setColumnWidth(5, 20.0);
    itemsSheet.setColumnWidth(6, 28.0);

    // =============================================================
    // SHEET 5: Audit & Receipt Logs
    // =============================================================
    final logsSheet = excel['Audit & Receipt Logs'];

    _appendStyledRow(
      logsSheet,
      [
        TextCellValue('Log ID'),
        TextCellValue('Receipt No'),
        TextCellValue('Order ID'),
        TextCellValue('Action'),
        TextCellValue('Timestamp'),
        TextCellValue('Status'),
        TextCellValue('File Reference'),
      ],
      cellStyles: [
        _tableHeaderCenterStyle,
        _tableHeaderCenterStyle,
        _tableHeaderCenterStyle,
        _tableHeaderLeftStyle,
        _tableHeaderCenterStyle,
        _tableHeaderCenterStyle,
        _tableHeaderLeftStyle,
      ],
    );

    for (var i = 0; i < logs.length; i++) {
      final l = logs[i];
      final isZebra = (i % 2 == 1);

      _appendStyledRow(
        logsSheet,
        [
          TextCellValue(l.id),
          TextCellValue(l.receiptNo),
          TextCellValue(l.orderId),
          TextCellValue(l.action),
          TextCellValue(DateFormat('yyyy-MM-dd HH:mm:ss').format(l.timestamp)),
          TextCellValue(l.isSuccess ? 'SUCCESS' : 'FAILED'),
          TextCellValue(l.receiptFilePath ?? ''),
        ],
        cellStyles: [
          isZebra ? _dataCenterZebraStyle : _dataCenterStyle,
          isZebra ? _dataCenterZebraStyle : _dataCenterStyle,
          isZebra ? _dataCenterZebraStyle : _dataCenterStyle,
          isZebra ? _dataLeftZebraStyle : _dataLeftStyle,
          isZebra ? _dataCenterZebraStyle : _dataCenterStyle,
          l.isSuccess ? _badgeSuccessStyle : _badgeFailedStyle,
          isZebra ? _dataLeftZebraStyle : _dataLeftStyle,
        ],
      );
    }

    logsSheet.setColumnWidth(0, 26.0);
    logsSheet.setColumnWidth(1, 22.0);
    logsSheet.setColumnWidth(2, 24.0);
    logsSheet.setColumnWidth(3, 20.0);
    logsSheet.setColumnWidth(4, 22.0);
    logsSheet.setColumnWidth(5, 14.0);
    logsSheet.setColumnWidth(6, 45.0);

    // Encode bytes
    final fileBytes = excel.encode();
    if (fileBytes == null) {
      throw Exception('Failed to generate Excel file bytes');
    }

    final timestampStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'OmniPOS_Sales_Profit_Report_$timestampStr.xlsx';

    return await _saveExcelBytes(fileBytes, fileName);
  }

  /// Internal helper to save Excel bytes to persistent Downloads / Documents storage
  Future<String> _saveExcelBytes(List<int> bytes, String fileName) async {
    String? finalPath;

    // 1. Windows Downloads folder -> Downloads\POS_Reports
    if (Platform.isWindows) {
      try {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          final reportsDir = Directory('${downloadsDir.path}\\POS_Reports');
          if (!await reportsDir.exists()) {
            await reportsDir.create(recursive: true);
          }
          final file = File('${reportsDir.path}\\$fileName');
          await file.writeAsBytes(bytes, flush: true);
          finalPath = file.path;
        }
      } catch (_) {}
    } else if (Platform.isAndroid) {
      // 2. Android Public Downloads folder
      try {
        await requestStoragePermission();
        const publicDownloadDir = '/storage/emulated/0/Download/POS_Reports';
        final dir = Directory(publicDownloadDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final file = File('$publicDownloadDir/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        finalPath = file.path;
      } catch (_) {}
    }

    // 3. Fallback: Save to App Documents
    if (finalPath == null) {
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final sep = Platform.isWindows ? '\\' : '/';
        final reportsDir = Directory('${docsDir.path}${sep}reports');
        if (!await reportsDir.exists()) {
          await reportsDir.create(recursive: true);
        }
        final docFile = File('${reportsDir.path}$sep$fileName');
        await docFile.writeAsBytes(bytes, flush: true);
        finalPath = docFile.path;
      } catch (_) {}
    }

    // 4. Fallback for test / headless environments
    if (finalPath == null) {
      try {
        final fallbackDir = Directory(
          '${Directory.systemTemp.path}${Platform.pathSeparator}pos_reports',
        );
        if (!await fallbackDir.exists()) {
          await fallbackDir.create(recursive: true);
        }
        final fallbackFile = File(
          '${fallbackDir.path}${Platform.pathSeparator}$fileName',
        );
        await fallbackFile.writeAsBytes(bytes, flush: true);
        finalPath = fallbackFile.path;
      } catch (_) {
        final fallbackFile = File(fileName);
        await fallbackFile.writeAsBytes(bytes, flush: true);
        finalPath = fallbackFile.path;
      }
    }

    return finalPath;
  }

  /// Open Excel file directly in Microsoft Excel / default spreadsheet viewer
  Future<OpenResult> openExcelFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return OpenResult(
          type: ResultType.fileNotFound,
          message: 'Excel file not found at: $filePath',
        );
      }
      final absolutePath = file.absolute.path;
      if (Platform.isWindows) {
        try {
          final result = await Process.run('cmd', [
            '/c',
            'start',
            '',
            absolutePath,
          ], runInShell: true);
          if (result.exitCode == 0) {
            return OpenResult(type: ResultType.done, message: 'Opened');
          }
        } catch (_) {}
      }
      return await OpenFilex.open(absolutePath);
    } catch (e) {
      return await OpenFilex.open(filePath);
    }
  }

  /// Highlight and reveal Excel file in Windows File Explorer
  Future<void> showInExplorer(String filePath) async {
    if (Platform.isWindows) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await Process.run('explorer.exe', [
            '/select,',
            file.absolute.path,
          ], runInShell: true);
        }
      } catch (_) {}
    }
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
