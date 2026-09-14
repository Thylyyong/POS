import 'dart:async';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../controllers/settings_controller.dart';
import '../services/printer_service.dart';

/// Modal dialog for diagnosing and testing every installed printer on the machine
class PrinterDiagnosticsDialog extends StatefulWidget {
  const PrinterDiagnosticsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PrinterDiagnosticsDialog(),
    );
  }

  @override
  State<PrinterDiagnosticsDialog> createState() => _PrinterDiagnosticsDialogState();
}

class _PrinterDiagnosticsDialogState extends State<PrinterDiagnosticsDialog> {
  final PrinterService _printerService = PrinterService();
  List<Printer> _printers = [];
  bool _isLoading = true;
  bool _isTestingAll = false;
  String? _testingPrinterName;
  final Map<String, String> _printerTestStatus = {}; // 'printing', 'success', 'failed'
  String _statusMessage = 'Scanning for installed printers...';
  String? _sumatraPath;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Scanning Windows installed printers...';
    });

    try {
      final list = await _printerService.getInstalledPrinters();
      final sumatra = await _printerService.findSumatraPdfExecutable();
      if (!mounted) return;
      setState(() {
        _printers = list;
        _sumatraPath = sumatra;
        _isLoading = false;
        _statusMessage = list.isEmpty
            ? 'No printers found. Please check Windows Settings > Devices > Printers.'
            : 'Found ${list.length} printer devices. Tap "Test" on any device to verify.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = 'Failed to scan printers: $e';
      });
    }
  }

  Future<void> _testSinglePrinter(Printer printer) async {
    if (_testingPrinterName != null || _isTestingAll) return;

    setState(() {
      _testingPrinterName = printer.name;
      _printerTestStatus[printer.name] = 'printing';
      _statusMessage = 'Sending test slip to "${printer.name}"...';
    });

    final settings = context.read<SettingsController>().settings;
    final success = await _printerService.printTestReceiptToDevice(
      printer: printer,
      settings: settings,
    );

    if (!mounted) return;
    setState(() {
      _testingPrinterName = null;
      _printerTestStatus[printer.name] = success ? 'success' : 'failed';
      _statusMessage = success
          ? '✅ Test slip sent to "${printer.name}"! Check if paper feeds and cuts.'
          : '❌ Could not print to "${printer.name}". Printer may be offline or unreachable.';
    });
  }

  Future<void> _testAllPrinters() async {
    if (_printers.isEmpty || _isTestingAll) return;

    setState(() {
      _isTestingAll = true;
      _statusMessage = 'Testing all ${_printers.length} printers sequentially...';
    });

    final settings = context.read<SettingsController>().settings;
    int successCount = 0;

    for (int i = 0; i < _printers.length; i++) {
      if (!mounted) return;
      final printer = _printers[i];

      setState(() {
        _testingPrinterName = printer.name;
        _printerTestStatus[printer.name] = 'printing';
        _statusMessage = '(${i + 1}/${_printers.length}) Testing: "${printer.name}"...';
      });

      final success = await _printerService.printTestReceiptToDevice(
        printer: printer,
        settings: settings,
      );

      if (!mounted) return;
      if (success) successCount++;
      setState(() {
        _printerTestStatus[printer.name] = success ? 'success' : 'failed';
      });

      // Brief delay between printer spool jobs
      await Future.delayed(const Duration(milliseconds: 900));
    }

    if (!mounted) return;
    setState(() {
      _isTestingAll = false;
      _testingPrinterName = null;
      _statusMessage = 'Test complete! Sent test slip to $successCount of ${_printers.length} devices. Check which device printed paper.';
    });
  }

  Future<void> _setAsActivePrinter(Printer printer) async {
    final settingsCtrl = context.read<SettingsController>();
    final updated = settingsCtrl.settings.copyWith(
      selectedPrinterName: printer.name,
    );
    await settingsCtrl.updateSettings(updated);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Active POS printer set to: "${printer.name}"'),
        backgroundColor: const Color(0xFF0D9488),
        duration: const Duration(seconds: 2),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentSelectedName = context.select<SettingsController, String>(
      (c) => c.settings.selectedPrinterName,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 780),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.print_rounded,
                        color: Color(0xFF14B8A6),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PRINTER HARDWARE DIAGNOSTICS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Test every detected printer to verify CA H2 built-in hardware',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Action & Status Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _isLoading || _isTestingAll ? null : _loadPrinters,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Rescan'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isLoading || _isTestingAll || _printers.isEmpty
                          ? null
                          : _testAllPrinters,
                      icon: _isTestingAll
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.rocket_launch, size: 16),
                      label: Text(_isTestingAll ? 'Testing All...' : 'Test All Printers'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Printers List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF0D9488)),
                            SizedBox(height: 14),
                            Text('Detecting Windows printer devices...'),
                          ],
                        ),
                      )
                    : _printers.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.print_disabled,
                                    size: 56,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No Printer Devices Found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Windows does not see any installed printers.\nFor CA H2 terminals, install the POS-80 / Thermal driver via Windows Device Manager or manufacturer driver installer.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _loadPrinters,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Check Again'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0D9488),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _printers.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final printer = _printers[index];
                              final isCurrentActive = currentSelectedName.isNotEmpty
                                  ? printer.name.toLowerCase() == currentSelectedName.toLowerCase()
                                  : printer.isDefault;
                              final testStatus = _printerTestStatus[printer.name];
                              final isBeingTested = _testingPrinterName == printer.name;

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isCurrentActive
                                      ? const Color(0xFFF0FDF4)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCurrentActive
                                        ? const Color(0xFF86EFAC)
                                        : const Color(0xFFE2E8F0),
                                    width: isCurrentActive ? 1.8 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Device Icon
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: isCurrentActive
                                            ? const Color(0xFFDCFCE7)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.print,
                                        color: isCurrentActive
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFF64748B),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),

                                    // Device Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  printer.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              if (isCurrentActive)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF16A34A),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    'ACTIVE POS',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              if (printer.isDefault && !isCurrentActive) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFE2E8F0),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    'Windows Default',
                                                    style: TextStyle(
                                                      color: Color(0xFF475569),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            printer.url.isNotEmpty
                                                ? 'Port: ${printer.url}'
                                                : (printer.isAvailable ? 'Status: Ready' : 'Status: Unknown'),
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Status Badge
                                    if (testStatus != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: testStatus == 'success'
                                              ? const Color(0xFFDCFCE7)
                                              : (testStatus == 'printing'
                                                  ? const Color(0xFFFEF3C7)
                                                  : const Color(0xFFFEE2E2)),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (testStatus == 'printing')
                                              const SizedBox(
                                                width: 10,
                                                height: 10,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              )
                                            else
                                              Icon(
                                                testStatus == 'success'
                                                    ? Icons.check
                                                    : Icons.close,
                                                size: 14,
                                                color: testStatus == 'success'
                                                    ? const Color(0xFF16A34A)
                                                    : const Color(0xFFDC2626),
                                              ),
                                            const SizedBox(width: 4),
                                            Text(
                                              testStatus == 'success'
                                                  ? 'Printed'
                                                  : (testStatus == 'printing'
                                                      ? 'Printing...'
                                                      : 'Failed'),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: testStatus == 'success'
                                                    ? const Color(0xFF16A34A)
                                                    : (testStatus == 'printing'
                                                        ? const Color(0xFFD97706)
                                                        : const Color(0xFFDC2626)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                    ],

                                    // Action Buttons
                                    OutlinedButton.icon(
                                      onPressed: isBeingTested || _isTestingAll
                                          ? null
                                          : () => _testSinglePrinter(printer),
                                      icon: isBeingTested
                                          ? const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.print_outlined, size: 14),
                                      label: const Text('Test Print', style: TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF0D9488),
                                        side: const BorderSide(color: Color(0xFF0D9488)),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    if (!isCurrentActive)
                                      ElevatedButton(
                                        onPressed: () => _setAsActivePrinter(printer),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF0F172A),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                        child: const Text('Set Active', style: TextStyle(fontSize: 12)),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),

              // Footer Tip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 18, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Tip: On CA H2, look for "POS-80", "XP-80", or "Thermal Printer". Tap "Test Print" to find which printer feeds paper, then click "Set Active".',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                          ),
                          if (_sumatraPath != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.bolt, size: 13, color: Color(0xFF059669)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'SumatraPDF Engine Ready: $_sumatraPath (Active Backup Spooler)',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF059669),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
