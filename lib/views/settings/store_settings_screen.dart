import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_config.dart';
import '../../controllers/settings_controller.dart';
import '../../models/store_settings_model.dart';
import '../../services/presentation_service.dart';
import '../../widgets/app_logo_widget.dart';
import '../../widgets/image_picker_dialog.dart';
import '../customer_display/customer_main_view.dart';

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
  late TextEditingController _printerIpCtrl;
  late TextEditingController _qrTemplateCtrl;

  late bool _autoPrint;
  late bool _autoDrawer;
  late bool _cfdEnabled;
  late bool _is80mm;
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
    _printerIpCtrl = TextEditingController(text: s.printerIpOrAddress);
    _qrTemplateCtrl = TextEditingController(text: s.qrPayloadTemplate);

    _autoPrint = s.autoPrintOnPayment;
    _autoDrawer = s.autoKickCashDrawer;
    _cfdEnabled = s.cfdEnabled;
    _is80mm = s.isPaperSize80mm;
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
    _printerIpCtrl.dispose();
    _qrTemplateCtrl.dispose();
    super.dispose();
  }

  bool get _hasLogo =>
      _logoPath != null &&
      _logoPath!.trim().isNotEmpty &&
      (_logoPath!.trim().startsWith('assets/') || File(_logoPath!.trim()).existsSync());

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
                    Icon(Icons.settings, color: AppConfig.accentGreen, size: 26),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Store & Hardware Settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Configure store profile logo, thermal printer, tax, and dual-screen CFD',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.accentGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSaving ? null : () => _saveSettings(context),
                  icon: const Icon(Icons.save, size: 18),
                  label: Text(_isSaving ? 'Saving...' : 'Save Settings', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    // Column 1: Store Info, Logo & Financial
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Store Profile & Brand Logo',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 16),

                            // Store Profile Picture / Logo Box
                            Row(
                              children: [
                                AppLogoWidget(
                                  logoPath: _logoPath,
                                  size: 72,
                                  borderRadius: 16,
                                  fallbackIcon: Icons.storefront,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: _pickStoreLogo,
                                        icon: const Icon(Icons.photo_camera, size: 16),
                                        label: Text(_hasLogo ? 'Change Profile Logo' : 'Upload Store Logo'),
                                      ),
                                      if (_hasLogo) ...[
                                        const SizedBox(height: 4),
                                        TextButton(
                                          onPressed: () => setState(() => _logoPath = null),
                                          style: TextButton.styleFrom(foregroundColor: AppConfig.accentRose, padding: EdgeInsets.zero),
                                          child: const Text('Remove Logo', style: TextStyle(fontSize: 12)),
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
                              decoration: const InputDecoration(labelText: 'Store Name'),
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _addressCtrl,
                              decoration: const InputDecoration(labelText: 'Store Address'),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneCtrl,
                                    decoration: const InputDecoration(labelText: 'Phone'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _emailCtrl,
                                    decoration: const InputDecoration(labelText: 'Email'),
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
                                    decoration: const InputDecoration(labelText: 'Currency Symbol (\$, €, £, etc)'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _taxCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Default Tax Rate (%)'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _footerCtrl,
                              maxLines: 3,
                              decoration: const InputDecoration(labelText: 'Receipt Footer Message'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Column 2: Hardware Peripherals & Dual Screen
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Thermal Printer & Customer Display',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: const Text('Auto-Print Receipt on Checkout', style: TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: const Text('Sends ESC/POS print job immediately on payment completion', style: TextStyle(fontSize: 12)),
                              value: _autoPrint,
                              activeThumbColor: AppConfig.accentGreen,
                              onChanged: (v) => setState(() => _autoPrint = v),
                            ),
                            const Divider(),
                            SwitchListTile(
                              title: const Text('Auto-Kick Cash Drawer', style: TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: const Text('Sends pulse signal to open cash drawer on cash sales', style: TextStyle(fontSize: 12)),
                              value: _autoDrawer,
                              activeThumbColor: AppConfig.accentGreen,
                              onChanged: (v) => setState(() => _autoDrawer = v),
                            ),
                            const Divider(),
                            SwitchListTile(
                              title: const Text('Secondary Display (CFD)', style: TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: const Text('Enable Customer Facing Display mirroring via Android Presentation', style: TextStyle(fontSize: 12)),
                              value: _cfdEnabled,
                              activeThumbColor: AppConfig.accentCyan,
                              onChanged: (v) => setState(() => _cfdEnabled = v),
                            ),

                            // Dual-Screen Duplicate / Preview Button
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.screen_share, color: AppConfig.accentCyan, size: 24),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Customer Screen UI & Mirroring', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                        Text('Cast to dual-screen hardware or view customer screen UI', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppConfig.accentCyan,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () async {
                                      // 1. Trigger hardware cast
                                      await PresentationService().showCustomerDisplay();
                                      // 2. Open preview in app
                                      if (context.mounted) {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => const CustomerMainView()),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.open_in_new, size: 16),
                                    label: const Text('Duplicate Screen', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),

                            const Divider(),
                            TextFormField(
                              controller: _printerIpCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Network Printer IP (e.g. 192.168.1.100)',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _qrTemplateCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Dynamic QR Payment URL Template',
                              ),
                            ),
                          ],
                        ),
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

  Future<void> _saveSettings(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        final updated = StoreSettingsModel(
          storeName: _nameCtrl.text.trim(),
          storeAddress: _addressCtrl.text.trim(),
          storePhone: _phoneCtrl.text.trim(),
          storeEmail: _emailCtrl.text.trim(),
          currencySymbol: _currencyCtrl.text.trim(),
          defaultTaxRate: double.tryParse(_taxCtrl.text) ?? 10.0,
          footerNote: _footerCtrl.text.trim(),
          logoPath: _logoPath,
          autoPrintOnPayment: _autoPrint,
          autoKickCashDrawer: _autoDrawer,
          cfdEnabled: _cfdEnabled,
          isPaperSize80mm: _is80mm,
          printerIpOrAddress: _printerIpCtrl.text.trim(),
          qrPayloadTemplate: _qrTemplateCtrl.text.trim(),
        );

        await context.read<SettingsController>().updateSettings(updated);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings saved successfully!'),
              backgroundColor: AppConfig.accentGreen,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }
}
