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
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final posCtrl = context.read<PosController>();

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
                    Icon(Icons.category, color: AppConfig.accentGreen, size: 26),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category & Menu Hierarchy',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Organize food & beverage categories',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.accentGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showAddCategoryDialog(context, posCtrl),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Categories Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppConfig.accentGreen))
                : _categories.isEmpty
                    ? const Center(
                        child: Text('No categories configured', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(24),
                        itemCount: _categories.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          final subs = _subcategories.where((s) => s.categoryId == category.id).toList();

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppConfig.accentGreen.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.restaurant_menu, color: AppConfig.accentGreenDark, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        category.name,
                                        style: const TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _showAddSubcategoryDialog(context, category.id),
                                      icon: const Icon(Icons.add, size: 16, color: AppConfig.accentCyan),
                                      label: const Text('Add Subcategory', style: TextStyle(color: AppConfig.accentCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                if (subs.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: subs.map((s) {
                                      return Chip(
                                        label: Text(s.name, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                                        backgroundColor: const Color(0xFFF1F5F9),
                                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                                      );
                                    }).toList(),
                                  ),
                                ],
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

  void _showAddCategoryDialog(BuildContext context, PosController posCtrl) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Menu Category'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Category Name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConfig.accentGreen, foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final cat = Category(
                id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
                name: nameCtrl.text.trim(),
              );
              await _productDao.insertCategory(cat);
              await _loadData();
              posCtrl.loadCategories();
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAddSubcategoryDialog(BuildContext context, String categoryId) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Subcategory'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Subcategory Name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConfig.accentCyan, foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final sub = Subcategory(
                id: 'sub_${DateTime.now().millisecondsSinceEpoch}',
                categoryId: categoryId,
                name: nameCtrl.text.trim(),
              );
              await _productDao.insertSubcategory(sub);
              await _loadData();
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
