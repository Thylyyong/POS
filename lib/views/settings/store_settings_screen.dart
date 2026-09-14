import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';

import '../../app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/cart_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../services/presentation_service.dart';
import '../../services/printer_service.dart';
import '../../core/device_profile.dart';
import '../../widgets/app_logo_widget.dart';
import '../../widgets/image_picker_dialog.dart';
import '../../widgets/printer_diagnostics_dialog.dart';
import '../../widgets/floating_customer_display_modal.dart';
import '../../core/theme/asset_theme.dart';
import '../../core/theme/sprite_icons.dart';
import '../../widgets/app_svg_icon.dart';
import '../../database/db_helper.dart';
import '../splash/splash_screen.dart';

class StoreSettingsScreen extends StatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _currencyCtrl;
  late TextEditingController _taxCtrl;
  late TextEditingController _footerCtrl;
  late TextEditingController _qrPaymentCtrl;
  late TextEditingController _usdToKhrRateCtrl;

  late double _fontSizeScale;
  late String _gridTemplate;
  late bool _cfdEnabled;
  late bool _isPaperSize80mm;
  late String _printerProfile;
  late bool _showKhrDualCurrency;
  late bool _autoPrintOnPayment;
  late bool _autoKickCashDrawer;
  late String _selectedPrinterName;
  late String _deviceProfile;
  late bool _useSumatraPdf;
  late bool _printLogoOnReceipt;
  late double _printerMarginTop;
  late double _printerMarginBottom;
  late double _printerMarginLeft;
  late double _printerMarginRight;
  String? _sumatraExecutablePath;
  List<Printer> _availablePrinters = [];
  String? _detectedPrinterName;
  bool _isScanningPrinters = false;
  bool _isPrintingTest = false;
  String? _logoPath;
  String? _qrImagePath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsController>().settings;
    _nameCtrl = TextEditingController(text: s.storeName);
    _addressCtrl = TextEditingController(text: s.storeAddress);
    _phoneCtrl = TextEditingController(text: s.storePhone);
    _emailCtrl = TextEditingController(text: s.storeEmail);
    _currencyCtrl = TextEditingController(text: s.currencySymbol);
    _taxCtrl = TextEditingController(text: s.defaultTaxRate.toString());
    _footerCtrl = TextEditingController(text: s.footerNote);
    _qrPaymentCtrl = TextEditingController(text: s.qrPayloadTemplate);
    _usdToKhrRateCtrl = TextEditingController(
      text: s.usdToKhrRate.toStringAsFixed(0),
    );

    _fontSizeScale = s.fontSizeScale;
    _gridTemplate = s.gridTemplate;
    _cfdEnabled = s.cfdEnabled;
    _isPaperSize80mm = s.isPaperSize80mm;
    _printerProfile = s.printerProfile;
    _showKhrDualCurrency = s.showKhrDualCurrency;
    _autoPrintOnPayment = s.autoPrintOnPayment;
    _autoKickCashDrawer = s.autoKickCashDrawer;
    _selectedPrinterName = s.selectedPrinterName;
    _deviceProfile = s.deviceProfile;
    _useSumatraPdf = s.useSumatraPdf;
    _printLogoOnReceipt = s.printLogoOnReceipt;
    _printerMarginTop = s.printerMarginTop;
    _printerMarginBottom = s.printerMarginBottom;
    _printerMarginLeft = s.printerMarginLeft;
    _printerMarginRight = s.printerMarginRight;
    _logoPath = s.logoPath;
    _qrImagePath = s.qrImagePath;

    _scanPrinters();
  }

  Future<void> _scanPrinters() async {
    setState(() => _isScanningPrinters = true);
    final printers = await PrinterService().getInstalledPrinters();
    final detected = await PrinterService().autoDetectThermalPrinter(
      preferredName: _selectedPrinterName,
    );
    final sumatra = await PrinterService().findSumatraPdfExecutable();
    if (!mounted) return;
    setState(() {
      _availablePrinters = printers;
      _detectedPrinterName = detected?.name;
      _sumatraExecutablePath = sumatra;
      _isScanningPrinters = false;
    });
  }

  Future<void> _testPrint() async {
    if (_isPrintingTest) return;
    setState(() => _isPrintingTest = true);
    final s = context.read<SettingsController>().settings.copyWith(
      selectedPrinterName: _selectedPrinterName,
      isPaperSize80mm: _isPaperSize80mm,
      storeName: _nameCtrl.text.trim(),
      useSumatraPdf: _useSumatraPdf,
      printLogoOnReceipt: _printLogoOnReceipt,
      printerMarginTop: _printerMarginTop,
      printerMarginBottom: _printerMarginBottom,
      printerMarginLeft: _printerMarginLeft,
      printerMarginRight: _printerMarginRight,
    );
    final success = await PrinterService().printTestReceipt(settings: s);
    if (!mounted) return;
    setState(() => _isPrintingTest = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '✅ Test slip successfully printed to ${_detectedPrinterName ?? "built-in printer"}!'
              : '❌ Print failed. Please check printer connection & Windows driver.',
        ),
        backgroundColor: success
            ? const Color(0xFF0D9488)
            : const Color(0xFFEF4444),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _currencyCtrl.dispose();
    _taxCtrl.dispose();
    _footerCtrl.dispose();
    _qrPaymentCtrl.dispose();
    _usdToKhrRateCtrl.dispose();
    super.dispose();
  }

  bool get _hasLogo => _logoPath != null && _logoPath!.trim().isNotEmpty;
  bool get _hasQrImage =>
      _qrImagePath != null && _qrImagePath!.trim().isNotEmpty;

  Future<void> _pickStoreLogo() async {
    final pickedPath = await ImagePickerDialog.pickImage(
      context,
      title: 'Select Store Profile Logo',
    );
    if (pickedPath != null) {
      setState(() {
        _logoPath = pickedPath;
      });
    }
  }

  Future<void> _pickQrCodeImage() async {
    final pickedPath = await ImagePickerDialog.pickImage(
      context,
      title: 'Select Payment QR Code Image (ABA / PromptPay)',
    );
    if (pickedPath != null) {
      setState(() {
        _qrImagePath = pickedPath;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    AppSvgIcon(
                      AssetTheme.setting,
                      color: Color(0xFF0F172A),
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Store & App Settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Configure store profile info, display font size, and product grid template',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0D9488),
                        side: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _confirmLogout(context),
                      icon: const AppSvgIcon.sprite(
                        SpriteIcons.refresh,
                        size: 18,
                        color: Color(0xFF0D9488),
                      ),
                      label: const Text(
                        'Switch Role / Logout',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _isSaving ? null : () => _saveSettings(context),
                      icon: const AppSvgIcon(
                        AssetTheme.files,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Save Settings',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Settings Form (Constrained to 75% of screen width)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: 0.75,
                  child: Form(
                    key: _formKey,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 950;
                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildColumn1(),
                              const SizedBox(height: 20),
                              _buildColumn2(),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: _buildColumn1()),
                            const SizedBox(width: 20),
                            Expanded(flex: 5, child: _buildColumn2()),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumn1() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  AppSvgIcon(
                    AssetTheme.store,
                    color: Color(0xFF0F172A),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Store Profile & Identity',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Store Profile Picture / Logo Box
              Row(
                children: [
                  AppLogoWidget(
                    logoPath: _logoPath,
                    size: 64,
                    borderRadius: 14,
                    fallbackSvg: AssetTheme.store,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickStoreLogo,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                          icon: const AppSvgIcon(
                            AssetTheme.gallery,
                            size: 16,
                            color: Color(0xFF0F172A),
                          ),
                          label: Text(
                            _hasLogo
                                ? 'Change Store Logo'
                                : 'Upload Store Logo',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                        if (_hasLogo) ...[
                          const SizedBox(height: 2),
                          TextButton(
                            onPressed: () => setState(() => _logoPath = null),
                            style: TextButton.styleFrom(
                              foregroundColor: AppConfig.accentRose,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Remove Logo',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Store Name',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Store Address',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _currencyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Currency Symbol (\$, €, £, etc)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _taxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Default Tax Rate (%)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _footerCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Receipt Footer Message',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Thermal Receipt & Printer Settings Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  AppSvgIcon.sprite(
                    SpriteIcons.printer,
                    color: Color(0xFF0F172A),
                    size: 19,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Thermal Printer & Receipt Format',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Set paper size (58mm or 80mm), printer protocol (Epson ESC/POS), and dual-currency KHR rate',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              // Paper Roll Width
              const Text(
                'Paper Roll Width',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildPaperSizeOption(
                    title: '80 mm',
                    subtitle: 'Standard Roll (48 cols)',
                    is80: true,
                  ),
                  const SizedBox(width: 12),
                  _buildPaperSizeOption(
                    title: '58 mm',
                    subtitle: 'Compact Roll (32 cols)',
                    is80: false,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Printer Model / Profile
              const Text(
                'Printer Protocol / Brand Profile',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _printerProfile,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'epson',
                    child: Row(
                      children: [
                        Icon(Icons.print, size: 18, color: Color(0xFF0D9488)),
                        SizedBox(width: 8),
                        Text('Epson (TM-T88 / TM-Series ESC/POS)'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'default',
                    child: Row(
                      children: [
                        Icon(
                          Icons.print_outlined,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                        SizedBox(width: 8),
                        Text('Generic ESC/POS (Default)'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'XP-N160I',
                    child: Row(
                      children: [
                        Icon(
                          Icons.print_outlined,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                        SizedBox(width: 8),
                        Text('Xprinter (XP-N160I)'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Sunmi-V2',
                    child: Row(
                      children: [
                        Icon(
                          Icons.tablet_android,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                        SizedBox(width: 8),
                        Text('Sunmi (V2 / Android POS)'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'TSP600',
                    child: Row(
                      children: [
                        Icon(
                          Icons.print_outlined,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                        SizedBox(width: 8),
                        Text('Star Micronics (TSP600)'),
                      ],
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _printerProfile = val);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Machine Built-in / Windows Printer Auto-Detection
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Terminal Printer (CA H2 Built-in)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isScanningPrinters ? null : _scanPrinters,
                    icon: _isScanningPrinters
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const AppSvgIcon.sprite(SpriteIcons.refresh, size: 14, color: Color(0xFF0D9488)),
                    label: const Text('Rescan', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Live status banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _detectedPrinterName != null
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _detectedPrinterName != null
                        ? const Color(0xFFA7F3D0)
                        : const Color(0xFFFDE68A),
                  ),
                ),
                child: Row(
                  children: [
                    AppSvgIcon.sprite(
                      _detectedPrinterName != null
                          ? SpriteIcons.checkCircle
                          : SpriteIcons.info,
                      size: 18,
                      color: _detectedPrinterName != null
                          ? const Color(0xFF059669)
                          : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _detectedPrinterName != null
                                ? 'Active: $_detectedPrinterName'
                                : 'No Thermal Printer Found',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _detectedPrinterName != null
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF92400E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _detectedPrinterName != null
                                ? 'Auto-verified & ready for silent direct printing'
                                : 'Please install POS-80 / Thermal driver in Windows Settings',
                            style: TextStyle(
                              fontSize: 11,
                              color: _detectedPrinterName != null
                                  ? const Color(0xFF047857)
                                  : const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Printer dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedPrinterName.isEmpty
                    ? ''
                    : _selectedPrinterName,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Selected Device',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('⚡ Auto-Detect (CA H2 Built-in Recommended)'),
                  ),
                  ..._availablePrinters.map(
                    (p) => DropdownMenuItem(
                      value: p.name,
                      child: Text(
                        '${p.name}${p.isDefault ? " (Windows Default)" : ""}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedPrinterName = val);
                    _scanPrinters();
                  }
                },
              ),
              const SizedBox(height: 10),

              // Verify & Test Print Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isPrintingTest ? null : _testPrint,
                  icon: _isPrintingTest
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const AppSvgIcon.sprite(
                          SpriteIcons.printer,
                          size: 16,
                          color: Color(0xFF0D9488),
                        ),
                  label: Text(
                    _isPrintingTest
                        ? 'Printing Test Slip...'
                        : 'Verify & Print Test Slip',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0D9488),
                    side: const BorderSide(color: Color(0xFF0D9488)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => PrinterDiagnosticsDialog.show(context),
                  icon: const AppSvgIcon.sprite(
                    SpriteIcons.settings,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Test Every Device (Diagnostics Tool)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ),

              // SumatraPDF Silent Print Engine Status & Switch (Windows)
              if (Platform.isWindows) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _sumatraExecutablePath != null
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _sumatraExecutablePath != null
                          ? const Color(0xFFBBF7D0)
                          : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              AppSvgIcon.sprite(
                                SpriteIcons.bolt,
                                size: 18,
                                color: _sumatraExecutablePath != null
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFD97706),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'SumatraPDF Silent Print Engine',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _useSumatraPdf,
                            activeTrackColor: const Color(0xFF0D9488),
                            onChanged: (val) =>
                                setState(() => _useSumatraPdf = val),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _sumatraExecutablePath != null
                            ? '✅ Detected: $_sumatraExecutablePath (Eliminates print errors & prints silently)'
                            : '⚠️ SumatraPDF.exe not found in windows/bin/ or C:\\POS. Using system spooler fallback.',
                        style: TextStyle(
                          fontSize: 11,
                          color: _sumatraExecutablePath != null
                              ? const Color(0xFF15803D)
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // ── Thermal Receipt Layout: Logo & Global Margins (mm) ─────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Brand Logo Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.image_outlined, size: 18, color: Color(0xFF0D9488)),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Receipt Header Brand Logo',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  _hasLogo
                                      ? 'Custom store logo active'
                                      : 'Brand asset fallback logo active',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch(
                          value: _printLogoOnReceipt,
                          activeTrackColor: const Color(0xFF0D9488),
                          onChanged: (val) =>
                              setState(() => _printLogoOnReceipt = val),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 12),

                    // Global Margins Steppers & Presets
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.aspect_ratio_outlined,
                              size: 16,
                              color: Color(0xFF475569),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Global Print Margins (mm)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Prevents thermal edge clipping (Top, Bottom, Left, and Right margins)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Segmented preset container with colored background and spacing
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildPresetChip(
                                  'Flush (0mm)',
                                  () {
                                    setState(() {
                                      _printerMarginTop = 0.0;
                                      _printerMarginBottom = 1.0;
                                      _printerMarginLeft = 0.0;
                                      _printerMarginRight = 0.0;
                                    });
                                  },
                                  isSelected:
                                      _printerMarginTop == 0.0 &&
                                      _printerMarginLeft == 0.0,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: _buildPresetChip(
                                  'Balanced (2mm)',
                                  () {
                                    setState(() {
                                      _printerMarginTop = 2.0;
                                      _printerMarginBottom = 4.0;
                                      _printerMarginLeft = 2.0;
                                      _printerMarginRight = 2.0;
                                    });
                                  },
                                  isSelected:
                                      _printerMarginTop == 2.0 &&
                                      _printerMarginLeft == 2.0,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: _buildPresetChip(
                                  'Safe (4mm)',
                                  () {
                                    setState(() {
                                      _printerMarginTop = 4.0;
                                      _printerMarginBottom = 6.0;
                                      _printerMarginLeft = 3.5;
                                      _printerMarginRight = 3.5;
                                    });
                                  },
                                  isSelected:
                                      _printerMarginTop == 4.0 &&
                                      _printerMarginLeft == 3.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 4 Margin Steppers (Top, Bottom, Left, Right)
                    Row(
                      children: [
                        Expanded(
                          child: _buildMarginStepper(
                            label: 'Top Margin',
                            value: _printerMarginTop,
                            icon: Icons.vertical_align_top,
                            onChanged: (val) =>
                                setState(() => _printerMarginTop = val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMarginStepper(
                            label: 'Bottom Margin',
                            value: _printerMarginBottom,
                            icon: Icons.vertical_align_bottom,
                            onChanged: (val) =>
                                setState(() => _printerMarginBottom = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMarginStepper(
                            label: 'Left Margin',
                            value: _printerMarginLeft,
                            icon: Icons.format_indent_increase,
                            onChanged: (val) =>
                                setState(() => _printerMarginLeft = val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMarginStepper(
                            label: 'Right Margin',
                            value: _printerMarginRight,
                            icon: Icons.format_indent_decrease,
                            onChanged: (val) =>
                                setState(() => _printerMarginRight = val),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              // Dual Currency Exchange Rate
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _usdToKhrRateCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'USD to KHR Rate (Riel)',
                        hintText: '4000',
                        suffixText: 'KHR / \$1',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(v.trim()) == null) {
                          return 'Invalid rate';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Show KHR Total',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'Dual-currency display',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      value: _showKhrDualCurrency,
                      activeThumbColor: const Color(0xFF0D9488),
                      activeTrackColor: const Color(0xFF99F6E4),
                      onChanged: (v) =>
                          setState(() => _showKhrDualCurrency = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _autoPrintOnPayment
                            ? const Color(0xFFF0FDFA)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _autoPrintOnPayment
                              ? const Color(0xFF99F6E4)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: _autoPrintOnPayment
                                  ? const Color(0xFFCCFBF1)
                                  : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.print_outlined,
                              size: 18,
                              color: _autoPrintOnPayment
                                  ? const Color(0xFF0D9488)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Auto-print Slip',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'On payment complete',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _autoPrintOnPayment,
                            activeTrackColor: const Color(0xFF0D9488),
                            onChanged: (v) =>
                                setState(() => _autoPrintOnPayment = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _autoKickCashDrawer
                            ? const Color(0xFFF0FDFA)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _autoKickCashDrawer
                              ? const Color(0xFF99F6E4)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: _autoKickCashDrawer
                                  ? const Color(0xFFCCFBF1)
                                  : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.point_of_sale_rounded,
                              size: 18,
                              color: _autoKickCashDrawer
                                  ? const Color(0xFF0D9488)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Kick Cash Drawer',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Pulse on cash checkout',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _autoKickCashDrawer,
                            activeTrackColor: const Color(0xFF0D9488),
                            onChanged: (v) =>
                                setState(() => _autoKickCashDrawer = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColumn2() {
    return Column(
      children: [
        // Hardware Terminal & Display Profile Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.devices,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hardware Terminal & Display Profile',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Auto-scales UI for CA H2 Kiosk (21.5") or POS CA9 (15.6")',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Live Screen Resolution & Active Mode Badge
              Builder(
                builder: (ctx) {
                  final media = MediaQuery.of(context).size;
                  final isPortrait = media.height > media.width;
                  final activeIsKiosk = DeviceProfile.isKiosk(
                    context,
                    deviceProfile: _deviceProfile,
                  );
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          activeIsKiosk
                              ? Icons.stay_current_portrait
                              : Icons.desktop_windows,
                          size: 18,
                          color: const Color(0xFF0D9488),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Current Screen: ${media.width.round()} × ${media.height.round()} (${isPortrait ? "Portrait" : "Landscape"}) → Active UI: ${activeIsKiosk ? "CA H2 Kiosk (21.5\")" : "POS CA9 Desktop (15.6\")"}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Profile Selector Options
              _buildDeviceProfileOption(
                id: DeviceProfile.auto,
                title: 'Auto-Detect (Adaptive)',
                subtitle: 'Automatically switches layout based on screen orientation (Recommended for multi-machine setups)',
                icon: Icons.auto_awesome,
                badgeText: 'RECOMMENDED',
              ),
              const SizedBox(height: 8),
              _buildDeviceProfileOption(
                id: DeviceProfile.caH2Kiosk,
                title: 'CA H2 Kiosk Terminal',
                subtitle: '21.5" Portrait (1080×1920) • 640px wide cards, 60px touch buttons, large touch keypad',
                icon: Icons.stay_current_portrait,
                badgeText: '21.5" PORTRAIT',
              ),
              const SizedBox(height: 8),
              _buildDeviceProfileOption(
                id: DeviceProfile.ca9Desktop,
                title: 'Model POS CA9 Terminal',
                subtitle: '15.6" Landscape (1366×768) • Side-by-side catalog & cart, compact countertop layout',
                icon: Icons.tv,
                badgeText: '15.6" LANDSCAPE',
              ),

              // ── Dual-Screen / Duplicate Screen for Model POS CA9 (Hidden for CA H2 Kiosk)
              _buildDualScreenSection(),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // App Display Font Size Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  AppSvgIcon(
                    AssetTheme.setting,
                    color: Color(0xFF0F172A),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Display Font Size',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Adjust the global text size across all POS screens and tables',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),

              // Font scale selector pills
              Row(
                children: [
                  _buildFontSizeOption('Small', '90%', 0.90),
                  const SizedBox(width: 8),
                  _buildFontSizeOption('Normal', '100%', 1.00),
                  const SizedBox(width: 8),
                  _buildFontSizeOption('Large', '115%', 1.15),
                  const SizedBox(width: 8),
                  _buildFontSizeOption('Extra', '130%', 1.30),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Product Grid Template Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  AppSvgIcon(
                    AssetTheme.allCate,
                    color: Color(0xFF0F172A),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Product Grid Template & Card Size',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Select column template density for menu cards on the cashier screen',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),

              // 3x6, 4x6, 5x5 Template Choices
              Row(
                children: [
                  _buildTemplateOption(
                    templateKey: '3x6',
                    title: '3x6 Template',
                    subtitle: '3 Columns • Large Cards',
                    svgAsset: AssetTheme.allCate,
                  ),
                  const SizedBox(width: 10),
                  _buildTemplateOption(
                    templateKey: '4x6',
                    title: '4x6 Template',
                    subtitle: '4 Columns • Balanced',
                    svgAsset: AssetTheme.allCate,
                  ),
                  const SizedBox(width: 10),
                  _buildTemplateOption(
                    templateKey: '5x5',
                    title: '5x5 Template',
                    subtitle: '5 Columns • Compact',
                    svgAsset: AssetTheme.allCate,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // QR Payment Account Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  AppSvgIcon(
                    AssetTheme.searchQR,
                    color: Color(0xFF0F172A),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Static Payment QR Code (KHQR / PromptPay)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Upload your static merchant QR code (ABA KHQR, PromptPay, Wing) for customer checkout scans',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              // QR Code Image Preview Box & Controls
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _hasQrImage
                            ? const Color(0xFF0D9488)
                            : const Color(0xFFCBD5E1),
                        width: 1.5,
                      ),
                      boxShadow: [
                        if (_hasQrImage)
                          BoxShadow(
                            color: const Color(0xFF0D9488)
                                .withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _hasQrImage && File(_qrImagePath!).existsSync()
                        ? Image.file(File(_qrImagePath!), fit: BoxFit.contain)
                        : const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppSvgIcon(
                                  AssetTheme.searchQR,
                                  size: 30,
                                  color: Color(0xFF94A3B8),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'No QR',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickQrCodeImage,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                          icon: const AppSvgIcon(
                            AssetTheme.gallery,
                            size: 16,
                            color: Color(0xFF0F172A),
                          ),
                          label: Text(
                            _hasQrImage
                                ? 'Change QR Code Image'
                                : 'Upload QR Code Image',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_hasQrImage) ...[
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: () =>
                                setState(() => _qrImagePath = null),
                            style: TextButton.styleFrom(
                              foregroundColor: AppConfig.accentRose,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Remove QR Image',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        const Text(
                          'Used for KHQR & PromptPay scanning at checkout & CFD screen',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _qrPaymentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bank Payment QR Payload / KHQR String (Optional)',
                  hintText: 'e.g. 000201... (KHQR String) or merchant@aba',
                  helperText: 'Encoded onto printed receipts & checkout when static QR image is unset',
                  prefixIcon: Padding(
                    padding: EdgeInsets.all(12),
                    child: AppSvgIcon(
                      AssetTheme.wallet,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Employee Security & PIN Code Card (SQLite DB)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  AppSvgIcon(
                    AssetTheme.verify,
                    color: Color(0xFF0F172A),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Employee Security & Change PIN (SQLite)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Change master security PIN for Owner (Boss). Staff Cashier does not require a PIN for fast frontline access.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showPinChangeDialog(
                      context,
                      initialUserId: 'usr_owner',
                    ),
                    icon: const AppSvgIcon(
                      AssetTheme.verify,
                      size: 18,
                      color: Color(0xFF0D9488),
                    ),
                    label: const Text('Change Boss PIN'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _confirmLogout(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(
                      Icons.swap_horiz_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Switch Role / Logout',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Factory Database Reset Card (Danger Zone)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_forever_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Reset Database (Fresh Client Setup)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Permanently clears all sales transactions, order history, custom categories, products, register sessions, and restores initial factory defaults. Use this before selling or deploying to a new client.',
                style: TextStyle(fontSize: 12, color: Color(0xFF7F1D1D), height: 1.35),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _confirmResetDatabase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(
                  Icons.restore_from_trash_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text(
                  'Reset Database',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceProfileOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required String badgeText,
  }) {
    final isSelected = _deviceProfile == id;
    return InkWell(
      onTap: () {
        setState(() {
          _deviceProfile = id;
          if (id == DeviceProfile.caH2Kiosk) {
            _cfdEnabled = false;
          } else if (id == DeviceProfile.ca9Desktop) {
            _cfdEnabled = true;
          }
        });
        context.read<SettingsController>().setDeviceProfile(id);
        if (id == DeviceProfile.caH2Kiosk) {
          context.read<SettingsController>().toggleCfd(false);
        } else if (id == DeviceProfile.ca9Desktop) {
          context.read<SettingsController>().toggleCfd(true);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0D9488)
                : const Color(0xFFE2E8F0),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? const Color(0xFF0D9488)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF334155),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF0D9488).withValues(alpha: 0.15)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? const Color(0xFF0D9488)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected
                  ? const Color(0xFF0D9488)
                  : const Color(0xFF94A3B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Dual-Screen and Duplicate Screen options (Model POS CA9 vs CA H2 Kiosk)
  Widget _buildDualScreenSection() {
    final isKiosk = DeviceProfile.isKiosk(
      context,
      deviceProfile: _deviceProfile,
    );

    if (isKiosk) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 18,
              color: Color(0xFF64748B),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'CA H2 Kiosk is a 21.5" portrait self-service terminal with a single display. Secondary duplicate screen is disabled.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.screen_share_outlined,
                  size: 20,
                  color: Color(0xFF0D9488),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Model POS CA9 Dual-Screen Setup',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(width: 8),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFF0D9488),
                            borderRadius: BorderRadius.all(
                              Radius.circular(4),
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Text(
                              'DUAL DISPLAY',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      '15.6" Cashier Screen + Secondary Customer Facing Display (CFD)',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Switch toggle for Secondary Display
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Enable Customer-Facing Display (CFD)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            subtitle: const Text(
              'Mirror cart items, order total, and QR payment to 2nd screen in real time',
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF64748B),
              ),
            ),
            value: _cfdEnabled,
            activeThumbColor: const Color(0xFF0D9488),
            onChanged: (v) {
              setState(() => _cfdEnabled = v);
              context.read<SettingsController>().toggleCfd(v);
            },
          ),
          const Divider(height: 16),

          // Duplicate Screen Action Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Duplicate Screen to Customer',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      _cfdEnabled
                          ? 'Launch 2nd monitor window or preview customer screen'
                          : 'Enable CFD switch above to activate duplicate screen',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Preview in app modal
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _cfdEnabled
                    ? () => FloatingCustomerDisplayModal.show(context)
                    : null,
                icon: const Icon(Icons.preview_outlined, size: 16),
                label: const Text(
                  'Preview',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),

              // Launch 2nd Monitor Window
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                onPressed: _cfdEnabled
                    ? () async {
                        final launched =
                            await PresentationService().launchSecondaryWindow();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                launched
                                    ? 'Customer Display window opened on 2nd monitor!'
                                    : 'Customer Display is active',
                              ),
                              backgroundColor: const Color(0xFF0D9488),
                            ),
                          );
                        }
                      }
                    : null,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text(
                  'Open Duplicate Screen',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFontSizeOption(
    String label,
    String scaleLabel,
    double scaleValue,
  ) {
    final isSelected = (_fontSizeScale - scaleValue).abs() < 0.01;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _fontSizeScale = scaleValue),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF0D9488)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0D9488)
                  : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                scaleLabel,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.9)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateOption({
    required String templateKey,
    required String title,
    required String subtitle,
    required String svgAsset,
  }) {
    final isSelected = _gridTemplate == templateKey;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _gridTemplate = templateKey),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF0D9488)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0D9488)
                  : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSvgIcon(
                svgAsset,
                size: 24,
                color: isSelected ? Colors.white : const Color(0xFF0D9488),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.9)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPinChangeDialog(
    BuildContext context, {
    String initialUserId = 'usr_owner',
  }) async {
    final currentPinCtrl = TextEditingController();
    final recoveryPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();
    var selectedUserId = initialUserId;
    var useRecovery = false;
    var obscure = true;
    String? error;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final credentialCtrl = useRecovery
                ? recoveryPinCtrl
                : currentPinCtrl;
            final credentialLabel = useRecovery
                ? 'Main Boss recovery PIN'
                : 'Current PIN';

            Future<void> submit() async {
              final newPin = newPinCtrl.text.trim();
              final credential = credentialCtrl.text.trim();
              if (!RegExp(r'^\d{4}$').hasMatch(newPin)) {
                setDialogState(
                  () => error = 'New PIN must contain exactly 4 digits',
                );
                return;
              }
              if (newPin != confirmPinCtrl.text.trim()) {
                setDialogState(
                  () => error = 'New PIN and confirmation do not match',
                );
                return;
              }

              final authCtrl = context.read<AuthController>();
              final settingsCtrl = context.read<SettingsController>();
              final success = await authCtrl.changeUserPin(
                userId: selectedUserId,
                currentPin: credential,
                newPin: newPin,
                isAdminOverride: useRecovery,
              );

              if (!success) {
                setDialogState(
                  () => error = useRecovery
                      ? 'Invalid recovery PIN'
                      : 'Current PIN is incorrect',
                );
                return;
              }

              // Also sync admin pin if changing owner
              if (selectedUserId == 'usr_owner') {
                await settingsCtrl.updateAdminPin(newPin);
              }

              final roleName = selectedUserId == 'usr_owner'
                  ? 'Owner (Boss)'
                  : 'Staff Cashier';

              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'PIN updated and saved to SQLite database for $roleName',
                    ),
                    backgroundColor: const Color(0xFF0D9488),
                  ),
                );
              }
            }

            Widget pinField(String label, TextEditingController controller) {
              return TextField(
                controller: controller,
                obscureText: obscure,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: InputDecoration(
                  labelText: label,
                  counterText: '',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(12),
                    child: AppSvgIcon(
                      AssetTheme.pin,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  suffixIcon: IconButton(
                    tooltip: obscure ? 'Show PIN' : 'Hide PIN',
                    icon: AppSvgIcon(
                      obscure ? AssetTheme.eyeClose : AssetTheme.eyeOpen,
                      size: 18,
                      color: const Color(0xFF64748B),
                    ),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                  border: const OutlineInputBorder(),
                ),
              );
            }

            return AlertDialog(
              title: const Text('Change Boss Security PIN'),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('Enter Current PIN'),
                          icon: AppSvgIcon(
                            AssetTheme.verify,
                            size: 16,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Boss Recovery'),
                          icon: AppSvgIcon(
                            AssetTheme.info,
                            size: 16,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                      selected: {useRecovery},
                      onSelectionChanged: (selected) => setDialogState(() {
                        useRecovery = selected.first;
                        error = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    pinField(credentialLabel, credentialCtrl),
                    const SizedBox(height: 10),
                    pinField('New 4-Digit PIN', newPinCtrl),
                    const SizedBox(height: 10),
                    pinField('Confirm New PIN', confirmPinCtrl),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        error!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (useRecovery) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Recovery requires Main Boss authorization.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: submit,
                  child: const Text('Save to SQLite DB'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      currentPinCtrl.dispose();
      recoveryPinCtrl.dispose();
      newPinCtrl.dispose();
      confirmPinCtrl.dispose();
    }
  }

  Widget _buildPaperSizeOption({
    required String title,
    required String subtitle,
    required bool is80,
  }) {
    final isSelected = _isPaperSize80mm == is80;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _isPaperSize80mm = is80),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF0D9488)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0D9488)
                  : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.9)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarginStepper({
    required String label,
    required double value,
    required IconData icon,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: value > 0.0
                    ? () => onChanged((value - 0.5).clamp(0.0, 20.0))
                    : null,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.remove, size: 14, color: Color(0xFF0F172A)),
                ),
              ),
              Text(
                '${value.toStringAsFixed(1)} mm',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              InkWell(
                onTap: value < 20.0
                    ? () => onChanged((value + 0.5).clamp(0.0, 20.0))
                    : null,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.add, size: 14, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(
    String label,
    VoidCallback onTap, {
    bool isSelected = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color:
                isSelected ? const Color(0xFF0D9488) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Future<void> _saveSettings(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        final current = context.read<SettingsController>().settings;
        final cart = context.read<CartController>();
        final updated = current.copyWith(
          storeName: _nameCtrl.text.trim(),
          storeAddress: _addressCtrl.text.trim(),
          storePhone: _phoneCtrl.text.trim(),
          storeEmail: _emailCtrl.text.trim(),
          currencySymbol: _currencyCtrl.text.trim(),
          defaultTaxRate: double.tryParse(_taxCtrl.text) ?? 10.0,
          footerNote: _footerCtrl.text.trim(),
          logoPath: _logoPath,
          qrImagePath: _qrImagePath,
          clearLogoPath: _logoPath == null,
          clearQrImagePath: _qrImagePath == null,
          fontSizeScale: _fontSizeScale,
          gridTemplate: _gridTemplate,
          cfdEnabled: _cfdEnabled,
          qrPayloadTemplate: _qrPaymentCtrl.text.trim(),
          isPaperSize80mm: _isPaperSize80mm,
          printerProfile: _printerProfile,
          selectedPrinterName: _selectedPrinterName,
          deviceProfile: _deviceProfile,
          usdToKhrRate:
              double.tryParse(_usdToKhrRateCtrl.text.trim()) ?? 4000.0,
          showKhrDualCurrency: _showKhrDualCurrency,
          autoPrintOnPayment: _autoPrintOnPayment,
          autoKickCashDrawer: _autoKickCashDrawer,
          useSumatraPdf: _useSumatraPdf,
          printLogoOnReceipt: _printLogoOnReceipt,
          printerMarginTop: _printerMarginTop,
          printerMarginBottom: _printerMarginBottom,
          printerMarginLeft: _printerMarginLeft,
          printerMarginRight: _printerMarginRight,
        );

        await context.read<SettingsController>().updateSettings(updated);
        if (!mounted) return;

        cart.updateConfig(
          taxRate: updated.defaultTaxRate,
          currencySymbol: updated.currencySymbol,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  AppSvgIcon(AssetTheme.success, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Settings saved successfully!'),
                ],
              ),
              backgroundColor: Color(0xFF0D9488),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  void _confirmLogout(BuildContext context) {
    final auth = context.read<AuthController>();
    final currentRoleName = auth.currentUser.displayName;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.swap_horiz_rounded,
                color: Color(0xFF0D9488),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Switch Role / Logout',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current active session: $currentRoleName',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0D9488),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Would you like to logout and return to the login screen to switch operator role?',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              final authCtrl = context.read<AuthController>();
              authCtrl.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SplashScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.white),
            label: const Text(
              'Logout & Switch',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmResetDatabase() async {
    final cartCtrl = context.read<CartController>();
    final settingsCtrl = context.read<SettingsController>();
    final authCtrl = context.read<AuthController>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFDC2626),
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Reset Entire Database?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to completely erase all data in the database?',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This action will permanently delete:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text('• All completed and pending orders', style: TextStyle(fontSize: 11.5, color: Color(0xFF7F1D1D))),
                  Text('• All sales revenue and item sales reports', style: TextStyle(fontSize: 11.5, color: Color(0xFF7F1D1D))),
                  Text('• Cash drawer register sessions and logs', style: TextStyle(fontSize: 11.5, color: Color(0xFF7F1D1D))),
                  Text('• Custom products, categories & dining tables', style: TextStyle(fontSize: 11.5, color: Color(0xFF7F1D1D))),
                  Text('• Store configuration and custom PINs', style: TextStyle(fontSize: 11.5, color: Color(0xFF7F1D1D))),
                  SizedBox(height: 6),
                  Text(
                    'Default factory data and standard admin login will be restored.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '⚠️ This operation cannot be undone. Are you ready to proceed?',
              style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_forever_rounded, size: 18, color: Colors.white),
            label: const Text(
              'Yes, Reset Everything',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show progress modal
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: Color(0xFFDC2626)),
              SizedBox(width: 20),
              Text('Resetting database...', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );

    try {
      await DbHelper().resetDatabase();

      if (!mounted) return;

      // Reset in-memory cart
      cartCtrl.clearCart();

      // Reload settings from newly recreated database
      await settingsCtrl.loadSettings();

      // Logout active user session
      authCtrl.logout();

      // Close progress modal
      if (navigator.canPop()) {
        navigator.pop();
      }

      // Navigate smoothly back to SplashScreen
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (route) => false,
      );

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Database reset successfully! Fresh client setup ready.'),
            ],
          ),
          backgroundColor: Color(0xFF0D9488),
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (navigator.canPop()) {
        navigator.pop();
      }
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Database reset error: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }
}
