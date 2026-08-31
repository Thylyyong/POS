import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_config.dart';
import '../../controllers/settings_controller.dart';
import '../../widgets/app_logo_widget.dart';
import '../../widgets/image_picker_dialog.dart';

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

  late double _fontSizeScale;
  late String _gridTemplate;
  late bool _cfdEnabled;
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

    _fontSizeScale = s.fontSizeScale;
    _gridTemplate = s.gridTemplate;
    _cfdEnabled = s.cfdEnabled;
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
                    Icon(Icons.settings_outlined, color: Color(0xFF0F172A), size: 24),
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
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSaving ? null : () => _saveSettings(context),
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text(_isSaving ? 'Saving...' : 'Save Settings',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    // Column 1: Store Profile & Information
                    Expanded(
                      flex: 5,
                      child: Container(
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
                                Icon(Icons.storefront_outlined, color: Color(0xFF0F172A), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Store Profile & Identity',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
                                  fallbackIcon: Icons.storefront,
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
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        ),
                                        icon: const Icon(Icons.photo_camera_outlined, size: 16),
                                        label: Text(_hasLogo ? 'Change Store Logo' : 'Upload Store Logo',
                                            style: const TextStyle(fontSize: 12.5)),
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
                                          child: const Text('Remove Logo', style: TextStyle(fontSize: 11.5)),
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
                                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _addressCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Store Address',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ],
                        ),
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
                                    Icon(Icons.format_size, color: Color(0xFF0F172A), size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Display Font Size',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
                                    Icon(Icons.grid_view_rounded, color: Color(0xFF0F172A), size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Product Grid Template & Card Size',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
                                      icon: Icons.view_comfortable,
                                    ),
                                    const SizedBox(width: 10),
                                    _buildTemplateOption(
                                      templateKey: '4x6',
                                      title: '4x6 Template',
                                      subtitle: '4 Columns • Balanced',
                                      icon: Icons.grid_view,
                                    ),
                                    const SizedBox(width: 10),
                                    _buildTemplateOption(
                                      templateKey: '5x5',
                                      title: '5x5 Template',
                                      subtitle: '5 Columns • Compact',
                                      icon: Icons.view_compact,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Customer Screen (CFD) Toggle Card
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Secondary Customer Screen (CFD)',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              subtitle: const Text('Enable dual-screen live order and QR mirroring',
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                              value: _cfdEnabled,
                              activeThumbColor: const Color(0xFF0F172A),
                              onChanged: (v) => setState(() => _cfdEnabled = v),
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

  Widget _buildFontSizeOption(String label, String scaleLabel, double scaleValue) {
    final isSelected = (_fontSizeScale - scaleValue).abs() < 0.01;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _fontSizeScale = scaleValue),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
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
                  color: isSelected ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
    required IconData icon,
  }) {
    final isSelected = _gridTemplate == templateKey;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _gridTemplate = templateKey),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected ? Colors.white : const Color(0xFF0F172A),
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
                  color: isSelected ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
        );

        await context.read<SettingsController>().updateSettings(updated);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Settings saved successfully!'),
                ],
              ),
              backgroundColor: Color(0xFF0F172A),
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
