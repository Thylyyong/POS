class StoreSettingsModel {
  final String storeName;
  final String storeAddress;
  final String storePhone;
  final String storeEmail;
  final String currencySymbol;
  final double defaultTaxRate;
  final String footerNote;
  final String? logoPath;

  // Display & Template Layout Customizations
  final double fontSizeScale; // 0.9 (Small), 1.0 (Normal), 1.15 (Large), 1.30 (XL)
  final String gridTemplate; // '3x6' (Large Cards), '4x6' (Standard Grid), '5x5' (High Density)

  // System & Peripheral Settings
  final bool autoPrintOnPayment;
  final bool autoKickCashDrawer;
  final bool cfdEnabled;
  final bool isPaperSize80mm; // true for 80mm, false for 58mm
  final String printerIpOrAddress;
  final String qrPayloadTemplate;

  const StoreSettingsModel({
    this.storeName = 'Gourmet Bistro POS',
    this.storeAddress = '123 Boulevard St, Suite 100',
    this.storePhone = '+1 (555) 019-2834',
    this.storeEmail = 'contact@gourmetbistro.com',
    this.currencySymbol = '\$',
    this.defaultTaxRate = 10.0,
    this.footerNote = 'Thank you for dining with us!\nPlease visit again.',
    this.logoPath,
    this.fontSizeScale = 1.0,
    this.gridTemplate = '4x6',
    this.autoPrintOnPayment = true,
    this.autoKickCashDrawer = true,
    this.cfdEnabled = true,
    this.isPaperSize80mm = true,
    this.printerIpOrAddress = '192.168.1.100',
    this.qrPayloadTemplate = 'https://pay.restaurant.com/pos?order=',
  });

  Map<String, String> toMap() {
    return {
      'store_name': storeName,
      'store_address': storeAddress,
      'store_phone': storePhone,
      'store_email': storeEmail,
      'currency_symbol': currencySymbol,
      'default_tax_rate': defaultTaxRate.toString(),
      'footer_note': footerNote,
      'logo_path': logoPath ?? '',
      'font_size_scale': fontSizeScale.toString(),
      'grid_template': gridTemplate,
      'auto_print_on_payment': autoPrintOnPayment ? '1' : '0',
      'auto_kick_cash_drawer': autoKickCashDrawer ? '1' : '0',
      'cfd_enabled': cfdEnabled ? '1' : '0',
      'is_paper_size_80mm': isPaperSize80mm ? '1' : '0',
      'printer_ip_or_address': printerIpOrAddress,
      'qr_payload_template': qrPayloadTemplate,
    };
  }

  factory StoreSettingsModel.fromMap(Map<String, String> map) {
    return StoreSettingsModel(
      storeName: map['store_name'] ?? 'Gourmet Bistro POS',
      storeAddress: map['store_address'] ?? '123 Boulevard St, Suite 100',
      storePhone: map['store_phone'] ?? '+1 (555) 019-2834',
      storeEmail: map['store_email'] ?? 'contact@gourmetbistro.com',
      currencySymbol: map['currency_symbol'] ?? '\$',
      defaultTaxRate: double.tryParse(map['default_tax_rate'] ?? '10.0') ?? 10.0,
      footerNote: map['footer_note'] ?? 'Thank you for dining with us!\nPlease visit again.',
      logoPath: (map['logo_path']?.isNotEmpty ?? false) ? map['logo_path'] : null,
      fontSizeScale: double.tryParse(map['font_size_scale'] ?? '1.0') ?? 1.0,
      gridTemplate: map['grid_template'] ?? '4x6',
      autoPrintOnPayment: (map['auto_print_on_payment'] ?? '1') == '1',
      autoKickCashDrawer: (map['auto_kick_cash_drawer'] ?? '1') == '1',
      cfdEnabled: (map['cfd_enabled'] ?? '1') == '1',
      isPaperSize80mm: (map['is_paper_size_80mm'] ?? '1') == '1',
      printerIpOrAddress: map['printer_ip_or_address'] ?? '192.168.1.100',
      qrPayloadTemplate: map['qr_payload_template'] ?? 'https://pay.restaurant.com/pos?order=',
    );
  }

  StoreSettingsModel copyWith({
    String? storeName,
    String? storeAddress,
    String? storePhone,
    String? storeEmail,
    String? currencySymbol,
    double? defaultTaxRate,
    String? footerNote,
    String? logoPath,
    double? fontSizeScale,
    String? gridTemplate,
    bool? autoPrintOnPayment,
    bool? autoKickCashDrawer,
    bool? cfdEnabled,
    bool? isPaperSize80mm,
    String? printerIpOrAddress,
    String? qrPayloadTemplate,
  }) {
    return StoreSettingsModel(
      storeName: storeName ?? this.storeName,
      storeAddress: storeAddress ?? this.storeAddress,
      storePhone: storePhone ?? this.storePhone,
      storeEmail: storeEmail ?? this.storeEmail,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
      footerNote: footerNote ?? this.footerNote,
      logoPath: logoPath ?? this.logoPath,
      fontSizeScale: fontSizeScale ?? this.fontSizeScale,
      gridTemplate: gridTemplate ?? this.gridTemplate,
      autoPrintOnPayment: autoPrintOnPayment ?? this.autoPrintOnPayment,
      autoKickCashDrawer: autoKickCashDrawer ?? this.autoKickCashDrawer,
      cfdEnabled: cfdEnabled ?? this.cfdEnabled,
      isPaperSize80mm: isPaperSize80mm ?? this.isPaperSize80mm,
      printerIpOrAddress: printerIpOrAddress ?? this.printerIpOrAddress,
      qrPayloadTemplate: qrPayloadTemplate ?? this.qrPayloadTemplate,
    );
  }
}
