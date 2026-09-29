import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/pos_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../database/product_dao.dart';
import '../../models/product_model.dart';
import '../../core/product_image_helper.dart';
import '../../widgets/admin_pin_dialog.dart';
import '../../widgets/image_picker_dialog.dart';
import '../../widgets/stock_adjustment_dialog.dart';
import '../../widgets/stock_audit_logs_dialog.dart';
import '../../core/theme/asset_theme.dart';
import '../../widgets/app_svg_icon.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ProductDao _productDao = ProductDao();

  List<Product> _allProducts = [];
  List<Category> _categories = [];
  List<Subcategory> _subcategories = [];
  String _filterCategoryId = 'ALL';
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _categories = await _productDao.getAllCategories();
    _subcategories = await _productDao.getAllSubcategories();
    _allProducts = await _productDao.getAllProducts();
    setState(() => _isLoading = false);
  }

  List<Product> get _filteredProducts {
    return _allProducts.where((p) {
      final matchesCategory =
          _filterCategoryId == 'ALL' || p.categoryId == _filterCategoryId;
      final matchesQuery =
          _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (p.barcode?.contains(_searchQuery) ?? false);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final settingsCtrl = context.watch<SettingsController>();
    final posCtrl = context.read<PosController>();
    final currency = settingsCtrl.settings.currencySymbol;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Row(
                  children: [
                    AppSvgIcon(
                      AssetTheme.box,
                      color: Color(0xFF0F172A),
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product & SKU Catalog',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Manage menu items, photos, prices, barcodes and stock',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search items...',
                          prefixIcon: const Padding(
                            padding: EdgeInsets.all(10),
                            child: AppSvgIcon(
                              AssetTheme.search,
                              size: 18,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 0,
                          ),
                          fillColor: const Color(0xFFF1F5F9),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => StockAuditLogsDialog.show(context),
                  icon: const Icon(Icons.history_edu_rounded, size: 16, color: Color(0xFF0F172A)),
                  label: const Text(
                    'Audit Logs & Waste',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => _checkManagerAndShowAddEdit(null),
                  icon: const AppSvgIcon(
                    AssetTheme.plus,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Add Product',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Categories Filter Row
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
            color: const Color(0xFFF1F5F9),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildCategoryFilterChip('All Items', 'ALL'),
                ..._categories.map(
                  (c) => _buildCategoryFilterChip(c.name, c.id),
                ),
              ],
            ),
          ),

          // Products List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: ColorTheme.buttonPrimary,
                    ),
                  )
                : _filteredProducts.isEmpty
                ? const Center(
                    child: Text(
                      'No products found',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _filteredProducts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      final category = _categories.firstWhere(
                        (c) => c.id == product.categoryId,
                        orElse: () => Category(id: '', name: 'Uncategorized'),
                      );
                      final imgProvider = ProductImageHelper.resolveImageProvider(
                        imagePath: product.imagePath,
                        productName: product.name,
                        categoryId: product.categoryId,
                      );
                      final hasDesc =
                          product.description != null &&
                          product.description!.trim().isNotEmpty;

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            // Photo Thumbnail or Icon
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: ColorTheme.neutral100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: ColorTheme.neutral300,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image(
                                  image: imgProvider,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Image.asset(
                                    ProductImageHelper.getDefaultAssetFor(
                                      productName: product.name,
                                      categoryId: product.categoryId,
                                    ),
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Center(
                                      child: AppSvgIcon(
                                        AssetTheme.kitchen,
                                        color: ColorTheme.primary400,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Product Name, Subtitle & SKU
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: const TextStyle(
                                      color: ColorTheme.neutral800,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (hasDesc) ...[
                                    const SizedBox(height: 1),
                                    Text(
                                      product.description!,
                                      style: const TextStyle(
                                        color: ColorTheme.neutral600,
                                        fontSize: 11.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  Text(
                                    () {
                                      final subcat =
                                          product.subcategoryId != null
                                          ? _subcategories
                                                .where(
                                                  (s) =>
                                                      s.id ==
                                                      product.subcategoryId,
                                                )
                                                .firstOrNull
                                          : null;
                                      final catText = subcat != null
                                          ? '${category.name} › ${subcat.name}'
                                          : category.name;
                                      return 'SKU: ${product.barcode ?? "N/A"} • $catText';
                                    }(),
                                    style: const TextStyle(
                                      color: ColorTheme.neutral500,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Price & Cost
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$currency${product.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: ColorTheme.primary400,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Cost: $currency${product.cost.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: ColorTheme.neutral600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Stock On-Hand Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: product.stockQuantity <= 0
                                    ? const Color(0xFFFEE2E2)
                                    : (product.stockQuantity <= 5
                                        ? const Color(0xFFFEF3C7)
                                        : const Color(0xFFF0FDFA)),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: product.stockQuantity <= 0
                                      ? const Color(0xFFFECACA)
                                      : (product.stockQuantity <= 5
                                          ? const Color(0xFFFDE68A)
                                          : const Color(0xFF99F6E4)),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    product.stockQuantity <= 0
                                        ? Icons.remove_circle_outline_rounded
                                        : (product.stockQuantity <= 5
                                            ? Icons.warning_amber_rounded
                                            : Icons.inventory_2_outlined),
                                    size: 13,
                                    color: product.stockQuantity <= 0
                                        ? const Color(0xFFDC2626)
                                        : (product.stockQuantity <= 5
                                            ? const Color(0xFFD97706)
                                            : const Color(0xFF0F766E)),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    product.stockQuantity <= 0
                                        ? '0 on-hand'
                                        : '${product.stockQuantity} on-hand',
                                    style: TextStyle(
                                      color: product.stockQuantity <= 0
                                          ? const Color(0xFFDC2626)
                                          : (product.stockQuantity <= 5
                                              ? const Color(0xFFD97706)
                                              : const Color(0xFF0F766E)),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Stock Adjustment & Waste Logging Button
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.tune_rounded, size: 14, color: Color(0xFF0D9488)),
                              label: const Text(
                                'Stock & Waste',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D9488),
                                ),
                              ),
                              onPressed: () => StockAdjustmentDialog.show(
                                context,
                                product: product,
                                onSaved: _loadData,
                              ),
                            ),
                            const SizedBox(width: 4),

                            // Actions (Edit Photo & Info, Delete)
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Color(0xFF64748B),
                                size: 18,
                              ),
                              tooltip: 'Edit Item & Photo',
                              onPressed: () =>
                                  _checkManagerAndShowAddEdit(product),
                            ),
                            IconButton(
                              icon: const AppSvgIcon(
                                AssetTheme.bin,
                                color: AppConfig.accentRose,
                                size: 18,
                              ),
                              tooltip: 'Delete Item',
                              onPressed: () => _checkManagerAndDelete(
                                product,
                                posCtrl,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChip(String label, String id) {
    final isSelected = _filterCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _filterCategoryId = id),
        selectedColor: ColorTheme.buttonPrimary,
        backgroundColor: ColorTheme.cardBg,
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          color: isSelected ? Colors.white : ColorTheme.primary400,
        ),
        side: BorderSide(
          color: isSelected ? ColorTheme.buttonPrimary : ColorTheme.neutral300,
          width: 1.2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        showCheckmark: false,
      ),
    );
  }

  Future<void> _checkManagerAndShowAddEdit(Product? existing) async {
    final auth = context.read<AuthController>();
    if (!auth.isOwner && !auth.isAdminAuthenticated) {
      final verified = await AdminPinDialog.show(
        context,
        title: 'Manager Authorization',
        subtitle: existing == null
            ? 'Only managers can add new products and initial stock.'
            : 'Only managers can edit product prices, details, and stock.',
      );
      if (!verified || !mounted) return;
    }
    if (mounted) {
      _showAddEditProductDialog(context, existing);
    }
  }

  Future<void> _checkManagerAndDelete(
    Product product,
    PosController posCtrl,
  ) async {
    final auth = context.read<AuthController>();
    if (!auth.isOwner && !auth.isAdminAuthenticated) {
      final verified = await AdminPinDialog.show(
        context,
        title: 'Manager Authorization',
        subtitle: 'Only managers can delete items from the catalog.',
      );
      if (!verified || !mounted) return;
    }
    if (mounted) {
      _confirmDeleteProduct(context, product, posCtrl);
    }
  }

  void _showAddEditProductDialog(BuildContext context, Product? existing) {
    final posCtrl = context.read<PosController>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final priceCtrl = TextEditingController(
      text: existing != null ? existing.price.toString() : '',
    );
    final costCtrl = TextEditingController(
      text: existing != null ? existing.cost.toString() : '0.0',
    );
    final barcodeCtrl = TextEditingController(text: existing?.barcode ?? '');
    final stockCtrl = TextEditingController(
      text: existing != null ? '${existing.stockQuantity}' : '50',
    );
    String selectedCatId =
        existing?.categoryId ??
        (_categories.isNotEmpty ? _categories.first.id : '');
    String? selectedSubcatId = existing?.subcategoryId;
    bool inStock = existing?.inStock ?? true;
    String? localImagePath = existing?.imagePath;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final previewProvider = (localImagePath != null && localImagePath!.trim().isNotEmpty)
              ? ProductImageHelper.resolveImageProvider(
                  imagePath: localImagePath,
                  productName: nameCtrl.text.isNotEmpty ? nameCtrl.text : existing?.name,
                  categoryId: selectedCatId,
                )
              : null;

          InputDecoration dialogInputDeco(
            String label, {
            String? hint,
            String? helper,
          }) {
            return InputDecoration(
              labelText: label,
              hintText: hint,
              helperText: helper,
              labelStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w500,
              ),
              hintStyle: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF94A3B8),
              ),
              helperStyle: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF0D9488),
                  width: 1.5,
                ),
              ),
            );
          }

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 500,
              constraints: const BoxConstraints(maxHeight: 720),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          existing == null
                              ? 'Add New Product'
                              : 'Edit Product Details',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: const AppSvgIcon(
                            AssetTheme.close,
                            color: Color(0xFF64748B),
                            size: 18,
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Photo Upload & Preview Box
                    InkWell(
                      onTap: () async {
                        final pickedPath = await ImagePickerDialog.pickImage(
                          context,
                          title: existing == null
                              ? 'Add Product Photo'
                              : 'Change Product Photo',
                        );
                        if (pickedPath != null) {
                          setDialogState(() {
                            localImagePath = pickedPath;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFCBD5E1),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: previewProvider != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Image(
                                        image: previewProvider,
                                        fit: BoxFit.contain,
                                        alignment: Alignment.center,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Center(
                                                  child: AppSvgIcon(
                                                    AssetTheme.gallery,
                                                    color: Color(0xFF94A3B8),
                                                    size: 36,
                                                  ),
                                                ),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.topRight,
                                      child: Container(
                                        margin: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: const AppSvgIcon(
                                            AssetTheme.bin,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          tooltip: 'Remove photo',
                                          onPressed: () {
                                            setDialogState(() {
                                              localImagePath = null;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.55),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: const Text(
                                          'Tap to change photo',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AppSvgIcon(
                                    AssetTheme.gallery,
                                    size: 36,
                                    color: ColorTheme.primary400,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Click to Upload / Pick Product Photo',
                                    style: TextStyle(
                                      color: ColorTheme.neutral800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Select JPG/PNG image from assets or gallery',
                                    style: TextStyle(
                                      color: ColorTheme.neutral600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: nameCtrl,
                      decoration: dialogInputDeco('Item Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: dialogInputDeco(
                        'Subtitle / Description (Optional)',
                        hint: 'e.g. Double espresso with frothed milk',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: dialogInputDeco('Selling Price (\$)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: costCtrl,
                            keyboardType: TextInputType.number,
                            decoration: dialogInputDeco('Cost (\$)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: barcodeCtrl,
                      decoration: dialogInputDeco('Barcode / SKU'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: dialogInputDeco(
                        'On-Hand Stock Quantity',
                        hint: '50',
                        helper: 'Current units available in physical inventory',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCatId.isNotEmpty
                          ? selectedCatId
                          : null,
                      decoration: dialogInputDeco('Category'),
                      items: _categories.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedCatId = val;
                            // Clear subcategory if it does not belong to the newly selected category
                            if (selectedSubcatId != null &&
                                !_subcategories.any(
                                  (s) =>
                                      s.id == selectedSubcatId &&
                                      s.categoryId == val,
                                )) {
                              selectedSubcatId = null;
                            }
                          });
                        }
                      },
                    ),
                    () {
                      final catSubs = _subcategories
                          .where((s) => s.categoryId == selectedCatId)
                          .toList();
                      if (catSubs.isEmpty) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: DropdownButtonFormField<String?>(
                          initialValue:
                              (selectedSubcatId != null &&
                                  catSubs.any((s) => s.id == selectedSubcatId))
                              ? selectedSubcatId
                              : null,
                          decoration: dialogInputDeco(
                            'Subcategory (Optional)',
                            helper: 'Select a subcategory group within this category',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'None (General Category)',
                                style: TextStyle(color: Color(0xFF64748B)),
                              ),
                            ),
                            ...catSubs.map((s) {
                              return DropdownMenuItem<String?>(
                                value: s.id,
                                child: Text(s.name),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setDialogState(() => selectedSubcatId = val);
                          },
                        ),
                      );
                    }(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'In Stock Availability',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Switch(
                          value: inStock,
                          activeThumbColor: ColorTheme.buttonPrimary,
                          onChanged: (val) =>
                              setDialogState(() => inStock = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorTheme.buttonPrimary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              if (nameCtrl.text.trim().isEmpty) return;
                              final price =
                                  double.tryParse(priceCtrl.text) ?? 0.0;
                              final cost =
                                  double.tryParse(costCtrl.text) ?? 0.0;

                              final stockQty =
                                  int.tryParse(stockCtrl.text.trim()) ?? 50;

                              final product = Product(
                                id:
                                    existing?.id ??
                                    'prod_${DateTime.now().millisecondsSinceEpoch}',
                                categoryId: selectedCatId,
                                subcategoryId: selectedSubcatId,
                                name: nameCtrl.text.trim(),
                                description: descCtrl.text.trim().isEmpty
                                    ? null
                                    : descCtrl.text.trim(),
                                price: price,
                                cost: cost,
                                barcode: barcodeCtrl.text.trim().isEmpty
                                    ? null
                                    : barcodeCtrl.text.trim(),
                                imagePath: localImagePath,
                                inStock: inStock && stockQty > 0,
                                stockQuantity: stockQty,
                              );

                              try {
                                final auth = context.read<AuthController>();
                                if (existing == null) {
                                  await _productDao.insertProduct(product);
                                  await _productDao.adjustProductStock(
                                    productId: product.id,
                                    quantityChange: stockQty,
                                    reasonCode: 'vendor_delivery',
                                    notes: 'Initial inventory set upon product creation',
                                    userId: auth.currentUser.id,
                                    userName: auth.currentUser.displayName,
                                    userRole: auth.currentUser.role.name,
                                    absoluteCount: true,
                                  );
                                } else {
                                  await _productDao.updateProduct(product);
                                  if (existing.stockQuantity != stockQty) {
                                    await _productDao.adjustProductStock(
                                      productId: product.id,
                                      quantityChange: stockQty,
                                      reasonCode: 'recount',
                                      notes: 'Manual stock count update via Catalog Editor',
                                      userId: auth.currentUser.id,
                                      userName: auth.currentUser.displayName,
                                      userRole: auth.currentUser.role.name,
                                      absoluteCount: true,
                                    );
                                  }
                                }

                                await _loadData();
                                await posCtrl.loadProducts();
                                await posCtrl.loadCategories();
                                await posCtrl.broadcastMenuUpdate();

                                if (ctx.mounted) {
                                  Navigator.of(ctx).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle, color: Colors.white, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              existing == null
                                                  ? 'Created "${product.name}" in database & synced to CDS'
                                                  : 'Saved "${product.name}" in database & synced to CDS',
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: const Color(0xFF10B981),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text('Error saving product: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            child: Text(
                              existing == null ? 'Create Item' : 'Save Changes',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteProduct(
    BuildContext context,
    Product product,
    PosController posCtrl,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${product.name}?'),
        content: const Text(
          'Are you sure you want to permanently remove this product?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConfig.accentRose,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await _productDao.deleteProduct(product.id);
              await _loadData();
              posCtrl.loadProducts();
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
