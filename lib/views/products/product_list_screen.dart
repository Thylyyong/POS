import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_config.dart';
import '../../controllers/pos_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../database/product_dao.dart';
import '../../models/product_model.dart';
import '../../widgets/image_picker_dialog.dart';

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
      final matchesCategory = _filterCategoryId == 'ALL' || p.categoryId == _filterCategoryId;
      final matchesQuery = _searchQuery.isEmpty ||
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
                    Icon(Icons.inventory_2_outlined, color: Color(0xFF0F172A), size: 24),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product & SKU Catalog',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Manage menu items, photos, prices, barcodes and stock',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
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
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search items...',
                          prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          fillColor: const Color(0xFFF1F5F9),
                          filled: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: () => _showAddEditProductDialog(context, null),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.bold)),
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
                ..._categories.map((c) => _buildCategoryFilterChip(c.name, c.id)),
              ],
            ),
          ),

          // Products List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: ColorTheme.buttonPrimary))
                : _filteredProducts.isEmpty
                    ? const Center(
                        child: Text('No products found', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15)),
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
                          final imgPath = product.imagePath?.trim();
                          ImageProvider? imgProvider;
                          if (imgPath != null && imgPath.isNotEmpty) {
                            if (imgPath.startsWith('assets/')) {
                              imgProvider = AssetImage(imgPath);
                            } else {
                              imgProvider = FileImage(File(imgPath));
                            }
                          }
                          final hasDesc = product.description != null && product.description!.trim().isNotEmpty;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                // Photo Thumbnail or Icon
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: ColorTheme.neutral100,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: ColorTheme.neutral300),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: imgProvider != null
                                        ? Image(
                                             image: imgProvider,
                                             fit: BoxFit.cover,
                                             errorBuilder: (context, error, stackTrace) => const Icon(Icons.fastfood, color: ColorTheme.primary400, size: 24),
                                           )
                                        : const Icon(Icons.fastfood, color: ColorTheme.primary400, size: 24),
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
                                          style: const TextStyle(color: ColorTheme.neutral600, fontSize: 11.5),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      Text(
                                        () {
                                          final subcat = product.subcategoryId != null
                                              ? _subcategories.where((s) => s.id == product.subcategoryId).firstOrNull
                                              : null;
                                          final catText = subcat != null
                                              ? '${category.name} › ${subcat.name}'
                                              : category.name;
                                          return 'SKU: ${product.barcode ?? "N/A"} • $catText';
                                        }(),
                                        style: const TextStyle(color: ColorTheme.neutral500, fontSize: 11),
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
                                        style: const TextStyle(color: ColorTheme.neutral600, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),

                                // Stock Status Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: product.inStock
                                        ? ColorTheme.neutral100
                                        : ColorTheme.statusRedBg,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: product.inStock ? ColorTheme.neutral300 : ColorTheme.statusRed,
                                    ),
                                  ),
                                  child: Text(
                                    product.inStock ? 'IN STOCK' : 'OUT OF STOCK',
                                    style: TextStyle(
                                      color: product.inStock ? ColorTheme.primary400 : ColorTheme.statusRed,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Actions (Edit Photo & Info, Delete)
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF64748B), size: 18),
                                  tooltip: 'Edit Item & Photo',
                                  onPressed: () => _showAddEditProductDialog(context, product),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppConfig.accentRose, size: 18),
                                  tooltip: 'Delete Item',
                                  onPressed: () => _confirmDeleteProduct(context, product, posCtrl),
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

  void _showAddEditProductDialog(BuildContext context, Product? existing) {
    final posCtrl = context.read<PosController>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final priceCtrl = TextEditingController(text: existing != null ? existing.price.toString() : '');
    final costCtrl = TextEditingController(text: existing != null ? existing.cost.toString() : '0.0');
    final barcodeCtrl = TextEditingController(text: existing?.barcode ?? '');
    String selectedCatId = existing?.categoryId ?? (_categories.isNotEmpty ? _categories.first.id : '');
    String? selectedSubcatId = existing?.subcategoryId;
    bool inStock = existing?.inStock ?? true;
    String? localImagePath = existing?.imagePath;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final hasImg = localImagePath != null && localImagePath!.trim().isNotEmpty;
          ImageProvider? previewProvider;
          if (hasImg) {
            final path = localImagePath!.trim();
            if (path.startsWith('assets/')) {
              previewProvider = AssetImage(path);
            } else {
              previewProvider = FileImage(File(path));
            }
          }

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          existing == null ? 'Add New Product' : 'Edit Product Details',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFF64748B)),
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
                          title: existing == null ? 'Add Product Photo' : 'Change Product Photo',
                        );
                        if (pickedPath != null) {
                          setDialogState(() {
                            localImagePath = pickedPath;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 130,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                        ),
                        child: previewProvider != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image(
                                      image: previewProvider,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const Center(
                                        child: Icon(Icons.broken_image, color: Color(0xFF94A3B8), size: 36),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.topRight,
                                      child: Container(
                                        margin: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.delete_forever, color: Colors.white, size: 20),
                                          tooltip: 'Remove photo',
                                          onPressed: () {
                                            setDialogState(() {
                                              localImagePath = null;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, size: 36, color: ColorTheme.primary400),
                                  SizedBox(height: 8),
                                  Text(
                                    'Click to Upload / Pick Product Photo',
                                    style: TextStyle(color: ColorTheme.neutral800, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    'Select JPG/PNG image from assets or gallery',
                                    style: TextStyle(color: ColorTheme.neutral600, fontSize: 11),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Subtitle / Description (Optional)',
                        hintText: 'e.g. Double espresso with frothed milk',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Selling Price (\$)', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: costCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Cost (\$)', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: barcodeCtrl,
                      decoration: const InputDecoration(labelText: 'Barcode / SKU', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCatId.isNotEmpty ? selectedCatId : null,
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                      items: _categories.map((c) {
                        return DropdownMenuItem(value: c.id, child: Text(c.name));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedCatId = val;
                            // Clear subcategory if it does not belong to the newly selected category
                            if (selectedSubcatId != null &&
                                !_subcategories.any((s) => s.id == selectedSubcatId && s.categoryId == val)) {
                              selectedSubcatId = null;
                            }
                          });
                        }
                      },
                    ),
                    () {
                      final catSubs = _subcategories.where((s) => s.categoryId == selectedCatId).toList();
                      if (catSubs.isEmpty) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: DropdownButtonFormField<String?>(
                          initialValue: (selectedSubcatId != null && catSubs.any((s) => s.id == selectedSubcatId))
                              ? selectedSubcatId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Subcategory (Optional)',
                            border: OutlineInputBorder(),
                            helperText: 'Select a subcategory group within this category',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('None (General Category)', style: TextStyle(color: Color(0xFF64748B))),
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
                        const Text('In Stock Availability', style: TextStyle(fontWeight: FontWeight.bold)),
                        Switch(
                          value: inStock,
                          activeThumbColor: ColorTheme.buttonPrimary,
                          onChanged: (val) => setDialogState(() => inStock = val),
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
                            style: ElevatedButton.styleFrom(backgroundColor: ColorTheme.buttonPrimary, foregroundColor: Colors.white),
                            onPressed: () async {
                              if (nameCtrl.text.trim().isEmpty) return;
                              final price = double.tryParse(priceCtrl.text) ?? 0.0;
                              final cost = double.tryParse(costCtrl.text) ?? 0.0;

                              final product = Product(
                                id: existing?.id ?? 'prod_${DateTime.now().millisecondsSinceEpoch}',
                                categoryId: selectedCatId,
                                subcategoryId: selectedSubcatId,
                                name: nameCtrl.text.trim(),
                                description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                                price: price,
                                cost: cost,
                                barcode: barcodeCtrl.text.trim().isEmpty ? null : barcodeCtrl.text.trim(),
                                imagePath: localImagePath,
                                inStock: inStock,
                              );

                              if (existing == null) {
                                await _productDao.insertProduct(product);
                              } else {
                                await _productDao.updateProduct(product);
                              }

                              await _loadData();
                              posCtrl.loadProducts();
                              if (ctx.mounted) Navigator.of(ctx).pop();
                            },
                            child: Text(existing == null ? 'Create Item' : 'Save Changes'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ),);
        },
      ),
    );
  }

  void _confirmDeleteProduct(BuildContext context, Product product, PosController posCtrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${product.name}?'),
        content: const Text('Are you sure you want to permanently remove this product?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConfig.accentRose, foregroundColor: Colors.white),
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
