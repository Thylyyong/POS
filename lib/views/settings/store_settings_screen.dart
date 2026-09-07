import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/cart_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../widgets/app_logo_widget.dart';
import '../../widgets/image_picker_dialog.dart';
import '../../core/theme/asset_theme.dart';
import '../../widgets/app_svg_icon.dart';

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
  String? _logoPath;
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
    _logoPath = s.logoPath;
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
          ),

          // Settings Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Column 1: Store Profile & Thermal Printer Settings
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: _pickStoreLogo,
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(
                                                color: Color(0xFFCBD5E1),
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                              ),
                                            ),
                                          ),
                                          if (_hasLogo) ...[
                                            const SizedBox(height: 2),
                                            TextButton(
                                              onPressed: () => setState(
                                                () => _logoPath = null,
                                              ),
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    AppConfig.accentRose,
                                                padding: EdgeInsets.zero,
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              child: const Text(
                                                'Remove Logo',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                ),
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
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'Required'
                                      : null,
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
                                          labelText:
                                              'Currency Symbol (\$, €, £, etc)',
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
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
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
                                    Icon(
                                      Icons.print_outlined,
                                      color: Color(0xFF0F172A),
                                      size: 20,
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
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
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
                                          Icon(
                                            Icons.print,
                                            size: 18,
                                            color: Color(0xFF0D9488),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Epson (TM-T88 / TM-Series ESC/POS)',
                                          ),
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
                                // Dual Currency Exchange Rate
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        controller: _usdToKhrRateCtrl,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
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
                                          if (double.tryParse(v.trim()) ==
                                              null) {
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
                                        activeThumbColor: const Color(
                                          0xFF0D9488,
                                        ),
                                        activeTrackColor: const Color(
                                          0xFF99F6E4,
                                        ),
                                        onChanged: (v) => setState(
                                          () => _showKhrDualCurrency = v,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: CheckboxListTile(
                                        contentPadding: EdgeInsets.zero,
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        title: const Text(
                                          'Auto-print on payment',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        value: _autoPrintOnPayment,
                                        activeColor: const Color(0xFF0D9488),
                                        onChanged: (v) => setState(
                                          () => _autoPrintOnPayment = v ?? true,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: CheckboxListTile(
                                        contentPadding: EdgeInsets.zero,
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        title: const Text(
                                          'Kick cash drawer',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        value: _autoKickCashDrawer,
                                        activeColor: const Color(0xFF0D9488),
                                        onChanged: (v) => setState(
                                          () => _autoKickCashDrawer = v ?? true,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Column 2: Display Font Size, Product Grid Template & Options
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          // App Display Font Size Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
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
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Font scale selector pills
                                Row(
                                  children: [
                                    _buildFontSizeOption('Small', '90%', 0.90),
                                    const SizedBox(width: 8),
                                    _buildFontSizeOption(
                                      'Normal',
                                      '100%',
                                      1.00,
                                    ),
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
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
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
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
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
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
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
                                      'QR Payment Account',
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
                                  'Set the payment account or URL used for customer QR payments',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _qrPaymentCtrl,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Payment account or QR URL prefix',
                                    hintText:
                                        'https://pay.example.com/pos?order=',
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
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? 'QR payment account is required'
                                      : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Customer Screen (CFD) Toggle Card
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Secondary Customer Screen (CFD)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              subtitle: const Text(
                                'Enable dual-screen live order and QR mirroring',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              value: _cfdEnabled,
                              activeThumbColor: const Color(0xFF0D9488),
                              activeTrackColor: const Color(0xFF99F6E4),
                              onChanged: (v) => setState(() => _cfdEnabled = v),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Admin Security & PIN Code Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
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
                                      'Admin Security & PIN Code',
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
                                  'Change the master PIN required to access Dashboard, Analytics, and Admin controls',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _showPinChangeDialog(context),
                                  icon: const AppSvgIcon(
                                    AssetTheme.verify,
                                    size: 18,
                                    color: Color(0xFF0D9488),
                                  ),
                                  label: const Text(
                                    'Change or reset master PIN',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

  Future<void> _showPinChangeDialog(BuildContext context) async {
    final currentPinCtrl = TextEditingController();
    final recoveryPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();
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
                : 'Current master PIN';

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
              final settings = context.read<SettingsController>().settings;
              final validCredential = useRecovery
                  ? credential == AuthController.defaultUsers.first.pinCode
                  : settings.verifyAdminPin(credential);
              if (!validCredential) {
                setDialogState(
                  () => error = useRecovery
                      ? 'Invalid Main Boss recovery PIN'
                      : 'Current PIN is incorrect',
                );
                return;
              }
              await context.read<SettingsController>().updateAdminPin(newPin);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Master PIN changed securely'),
                    backgroundColor: Color(0xFF0D9488),
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
              title: const Text('Secure master PIN'),
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
                          label: Text('Change PIN'),
                          icon: AppSvgIcon(
                            AssetTheme.verify,
                            size: 16,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Forgot PIN'),
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
                    pinField('New PIN', newPinCtrl),
                    const SizedBox(height: 10),
                    pinField('Confirm new PIN', confirmPinCtrl),
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
                        'Recovery requires the Main Boss PIN and does not reveal the old PIN.',
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
                  child: const Text('Save new PIN'),
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
          fontSizeScale: _fontSizeScale,
          gridTemplate: _gridTemplate,
          cfdEnabled: _cfdEnabled,
          qrPayloadTemplate: _qrPaymentCtrl.text.trim(),
          isPaperSize80mm: _isPaperSize80mm,
          printerProfile: _printerProfile,
          usdToKhrRate:
              double.tryParse(_usdToKhrRateCtrl.text.trim()) ?? 4000.0,
          showKhrDualCurrency: _showKhrDualCurrency,
          autoPrintOnPayment: _autoPrintOnPayment,
          autoKickCashDrawer: _autoKickCashDrawer,
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
}
