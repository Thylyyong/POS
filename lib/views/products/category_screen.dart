import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_config.dart';
import '../../controllers/pos_controller.dart';
import '../../database/product_dao.dart';
import '../../models/product_model.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final ProductDao _productDao = ProductDao();
  List<Category> _categories = [];
  List<Subcategory> _subcategories = [];
  List<Product> _products = [];
  bool _isLoading = true;
  String _searchQuery = '';

  // Track which category IDs are expanded (default: all expanded for convenience)
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final cats = await _productDao.getAllCategories();
    final subs = await _productDao.getAllSubcategories();
    final prods = await _productDao.getAllProducts();

    setState(() {
      _categories = cats;
      _subcategories = subs;
      _products = prods;
      // Expand all by default on first load
      if (_expandedIds.isEmpty) {
        _expandedIds.addAll(cats.map((c) => c.id));
      }
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final posCtrl = context.read<PosController>();

    final filteredCategories = _categories.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final catMatch = c.name.toLowerCase().contains(q);
      final subMatch = _subcategories
          .where((s) => s.categoryId == c.id)
          .any((s) => s.name.toLowerCase().contains(q));
      return catMatch || subMatch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ── Modern Header Bar ───────────────────────────────────────────
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
                    Icon(Icons.restaurant_menu_outlined, color: Color(0xFF0F172A), size: 24),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Menu & Categories',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Organize catalog menu categories and subcategories',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),

                // Search Bar
                SizedBox(
                  width: 260,
                  height: 38,
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Search categories...',
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      fillColor: const Color(0xFFF1F5F9),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Add Category Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () => _showCategoryDialog(context, posCtrl, null),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),

          // ── Category List / Cards View ──────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
                : filteredCategories.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.menu_book_outlined, size: 48, color: Color(0xFFCBD5E1)),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isEmpty ? 'No menu categories created yet' : 'No categories match "$_searchQuery"',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () => _showCategoryDialog(context, posCtrl, null),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Create Category'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: filteredCategories.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final category = filteredCategories[index];
                          final subs = _subcategories
                              .where((s) => s.categoryId == category.id)
                              .toList();
                          final prodCount = _products
                              .where((p) => p.categoryId == category.id)
                              .length;
                          final isExpanded = _expandedIds.contains(category.id);

                          return _ModernCategoryCard(
                            category: category,
                            subcategories: subs,
                            productCount: prodCount,
                            isExpanded: isExpanded,
                            onToggle: () {
                              setState(() {
                                if (isExpanded) {
                                  _expandedIds.remove(category.id);
                                } else {
                                  _expandedIds.add(category.id);
                                }
                              });
                            },
                            onEditCategory: () => _showCategoryDialog(context, posCtrl, category),
                            onDeleteCategory: () => _confirmDeleteCategory(context, category, posCtrl),
                            onAddSubcategory: () => _showSubcategoryDialog(context, category.id, null),
                            onEditSubcategory: (sub) => _showSubcategoryDialog(context, category.id, sub),
                            onDeleteSubcategory: (sub) => _confirmDeleteSubcategory(context, sub),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────

  void _showCategoryDialog(BuildContext context, PosController posCtrl, Category? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          existing == null ? 'New Category' : 'Edit Category',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        content: SizedBox(
          width: 380,
          child: TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Category Name',
              hintText: 'e.g. Coffee & Tea, Burgers, Desserts',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              if (existing == null) {
                await _productDao.insertCategory(Category(
                  id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                ));
              } else {
                await _productDao.updateCategory(Category(
                  id: existing.id,
                  name: name,
                  icon: existing.icon,
                ));
              }

              await _loadData();
              posCtrl.loadCategories();
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(existing == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(BuildContext context, Category category, PosController posCtrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Category?', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        content: Text(
          'Are you sure you want to delete "${category.name}"? All subcategories associated with it will also be deleted.',
          style: const TextStyle(color: Color(0xFF475569), fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConfig.accentRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              await _productDao.deleteCategory(category.id);
              await _loadData();
              posCtrl.loadCategories();
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSubcategoryDialog(BuildContext context, String categoryId, Subcategory? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          existing == null ? 'New Subcategory' : 'Edit Subcategory',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        content: SizedBox(
          width: 380,
          child: TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Subcategory Name',
              hintText: 'e.g. Hot Coffee, Iced Tea, Gourmet',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              if (existing == null) {
                await _productDao.insertSubcategory(Subcategory(
                  id: 'sub_${DateTime.now().millisecondsSinceEpoch}',
                  categoryId: categoryId,
                  name: name,
                ));
              } else {
                await _productDao.updateSubcategory(Subcategory(
                  id: existing.id,
                  categoryId: existing.categoryId,
                  name: name,
                ));
              }

              await _loadData();
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(existing == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSubcategory(BuildContext context, Subcategory sub) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Subcategory?', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        content: Text(
          'Delete subcategory "${sub.name}"?',
          style: const TextStyle(color: Color(0xFF475569), fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConfig.accentRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              await _productDao.deleteSubcategory(sub.id);
              await _loadData();
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Modern Category Card with Expandable Subcategories & Action Chips
// ============================================================================
class _ModernCategoryCard extends StatelessWidget {
  final Category category;
  final List<Subcategory> subcategories;
  final int productCount;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onEditCategory;
  final VoidCallback onDeleteCategory;
  final VoidCallback onAddSubcategory;
  final ValueChanged<Subcategory> onEditSubcategory;
  final ValueChanged<Subcategory> onDeleteSubcategory;

  const _ModernCategoryCard({
    required this.category,
    required this.subcategories,
    required this.productCount,
    required this.isExpanded,
    required this.onToggle,
    required this.onEditCategory,
    required this.onDeleteCategory,
    required this.onAddSubcategory,
    required this.onEditSubcategory,
    required this.onDeleteSubcategory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded ? const Color(0xFF0F172A).withValues(alpha: 0.25) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Category Main Header Row ──────────────────────────────────
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(14),
              bottom: isExpanded ? Radius.zero : const Radius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  // Icon Avatar / Badge
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      category.name.isNotEmpty ? category.name[0].toUpperCase() : 'C',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Category Title & Summary Chips
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              '${subcategories.length} subcategories',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                            const Text(' • ', style: TextStyle(color: Color(0xFFCBD5E1))),
                            Text(
                              '$productCount items',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Quick Action Buttons
                  OutlinedButton.icon(
                    onPressed: onAddSubcategory,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Add Subcategory', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                    tooltip: 'Edit Category Name',
                    onPressed: onEditCategory,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF94A3B8)),
                    tooltip: 'Delete Category',
                    onPressed: onDeleteCategory,
                  ),
                  const SizedBox(width: 4),

                  // Expand / Collapse Chevron
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 180),
                    turns: isExpanded ? 0.5 : 0.0,
                    child: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B), size: 20),
                  ),
                ],
              ),
            ),
          ),

          // ── Expandable Subcategories Flow ───────────────────────────────
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAFA),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: subcategories.isEmpty
                  ? Row(
                      children: [
                        const Text(
                          'No subcategories yet.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(width: 10),
                        InkWell(
                          onTap: onAddSubcategory,
                          child: const Text(
                            '+ Add now',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                          ),
                        ),
                      ],
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...subcategories.map((sub) {
                          return Container(
                            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  sub.name,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => onEditSubcategory(sub),
                                  borderRadius: BorderRadius.circular(4),
                                  child: const Padding(
                                    padding: EdgeInsets.all(2),
                                    child: Icon(Icons.edit, size: 13, color: Color(0xFF64748B)),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                InkWell(
                                  onTap: () => onDeleteSubcategory(sub),
                                  borderRadius: BorderRadius.circular(4),
                                  child: const Padding(
                                    padding: EdgeInsets.all(2),
                                    child: Icon(Icons.close, size: 13, color: Color(0xFF94A3B8)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        InkWell(
                          onTap: onAddSubcategory,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 14, color: Color(0xFF0F172A)),
                                SizedBox(width: 4),
                                Text(
                                  'Add Subcategory',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
