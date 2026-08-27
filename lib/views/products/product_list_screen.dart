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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Row(
                  children: [
                    Icon(Icons.inventory_2, color: AppConfig.accentGreen, size: 26),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product & SKU Catalog',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Manage menu items, upload photos, prices, barcodes and stock',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: 280,
                  height: 42,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search items...',
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                      fillColor: const Color(0xFFF1F5F9),
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.accentGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showAddEditProductDialog(context, null),
                  
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
                ? const Center(child: CircularProgressIndicator(color: AppConfig.accentGreen))
                : _filteredProducts.isEmpty
                    ? const Center(
                        child: Text('No products found', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(24),
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
                            } else if (File(imgPath).existsSync()) {
                              imgProvider = FileImage(File(imgPath));
                            }
                          }

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
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: AppConfig.accentGreen.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    image: imgProvider != null
                                        ? DecorationImage(
                                            image: imgProvider,
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: imgProvider == null
                                      ? const Icon(Icons.fastfood, color: AppConfig.accentGreenDark, size: 24)
                                      : null,
                                ),
                                const SizedBox(width: 16),

                                // Product Name & SKU
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: const TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'SKU: ${product.barcode ?? "N/A"} • ${category.name}',
                                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
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
                                          color: AppConfig.accentGreenDark,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Cost: $currency${product.cost.toStringAsFixed(2)}',
                                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),

                                // Stock Status Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: product.inStock
                                        ? AppConfig.accentGreen.withValues(alpha: 0.12)
                                        : AppConfig.accentRose.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    product.inStock ? 'IN STOCK' : 'OUT OF STOCK',
                                    style: TextStyle(
                                      color: product.inStock ? AppConfig.accentGreenDark : AppConfig.accentRose,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

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
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _filterCategoryId = id),
        selectedColor: AppConfig.accentGreen.withValues(alpha: 0.18),
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppConfig.accentGreenDark : const Color(0xFF475569),
        ),
        side: BorderSide(color: isSelected ? AppConfig.accentGreen : const Color(0xFFCBD5E1)),
      ),
    );
  }

  void _showAddEditProductDialog(BuildContext context, Product? existing) {
    final posCtrl = context.read<PosController>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(text: existing != null ? existing.price.toString() : '');
    final costCtrl = TextEditingController(text: existing != null ? existing.cost.toString() : '0.0');
    final barcodeCtrl = TextEditingController(text: existing?.barcode ?? '');
    String selectedCatId = existing?.categoryId ?? (_categories.isNotEmpty ? _categories.first.id : '');
    bool inStock = existing?.inStock ?? true;
    String? localImagePath = existing?.imagePath;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 480,
              constraints: const BoxConstraints(maxHeight: 700),
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
                          existing == null ? 'Add New Product + Photo' : 'Edit Product & Photo',
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
                          image: (localImagePath != null &&
                                  localImagePath!.trim().isNotEmpty &&
                                  (localImagePath!.trim().startsWith('assets/') ||
                                      File(localImagePath!.trim()).existsSync()))
                              ? DecorationImage(
                                  image: localImagePath!.trim().startsWith('assets/')
                                      ? AssetImage(localImagePath!.trim()) as ImageProvider
                                      : FileImage(File(localImagePath!.trim())),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: (localImagePath != null &&
                                localImagePath!.trim().isNotEmpty &&
                                (localImagePath!.trim().startsWith('assets/') ||
                                    File(localImagePath!.trim()).existsSync()))
                            ? Align(
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
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, size: 36, color: AppConfig.accentGreenDark),
                                  SizedBox(height: 8),
                                  Text(
                                    'Click to Upload / Pick Product Photo',
                                    style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    'Select JPG/PNG image from your machine/gallery',
                                    style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
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
                        if (val != null) setDialogState(() => selectedCatId = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('In Stock Availability', style: TextStyle(fontWeight: FontWeight.bold)),
                        Switch(
                          value: inStock,
                          activeThumbColor: AppConfig.accentGreen,
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
                            style: ElevatedButton.styleFrom(backgroundColor: AppConfig.accentGreen, foregroundColor: Colors.white),
                            onPressed: () async {
                              if (nameCtrl.text.trim().isEmpty) return;
                              final price = double.tryParse(priceCtrl.text) ?? 0.0;
                              final cost = double.tryParse(costCtrl.text) ?? 0.0;

                              final product = Product(
                                id: existing?.id ?? 'prod_${DateTime.now().millisecondsSinceEpoch}',
                                categoryId: selectedCatId,
                                name: nameCtrl.text.trim(),
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
            ),
          );
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
