import 'product_variant_model.dart';

class Category {
  final String id;
  final String name;
  final String? icon;
  final String? colorHex;
  final DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    this.icon,
    this.colorHex,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color_hex': colorHex,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String?,
      colorHex: map['color_hex'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Category copyWith({
    String? id,
    String? name,
    String? icon,
    String? colorHex,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class Subcategory {
  final String id;
  final String categoryId;
  final String name;
  final DateTime createdAt;

  Subcategory({
    required this.id,
    required this.categoryId,
    required this.name,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Subcategory.fromMap(Map<String, dynamic> map) {
    return Subcategory(
      id: map['id'] as String,
      categoryId: map['category_id'] as String,
      name: map['name'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Subcategory copyWith({
    String? id,
    String? categoryId,
    String? name,
    DateTime? createdAt,
  }) {
    return Subcategory(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class Product {
  final String id;
  final String categoryId;
  final String? subcategoryId;
  final String name;
  final String? description;
  final double price;
  final double cost;
  final String? barcode;
  final String? imagePath;
  final bool inStock;
  final int stockQuantity;
  final String? colorHex;
  final String? modifiersJson;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.categoryId,
    this.subcategoryId,
    required this.name,
    this.description,
    required this.price,
    this.cost = 0.0,
    this.barcode,
    this.imagePath,
    this.inStock = true,
    this.stockQuantity = 50,
    this.colorHex,
    this.modifiersJson,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  ProductVariantConfig get variantConfig => ProductVariantConfig.fromJson(
        modifiersJson,
        categoryId: categoryId,
        productName: name,
      );

  bool get hasVariants => variantConfig.hasAnyOptions;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'name': name,
      'description': description,
      'price': price,
      'cost': cost,
      'barcode': barcode,
      'image_path': imagePath,
      'in_stock': (inStock && stockQuantity > 0) ? 1 : 0,
      'stock_quantity': stockQuantity,
      'color_hex': colorHex,
      'modifiers_json': modifiersJson,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    final qty = (map['stock_quantity'] as num?)?.toInt() ?? 50;
    final stockFlag = (map['in_stock'] as int? ?? 1) == 1;
    return Product(
      id: map['id'] as String,
      categoryId: map['category_id'] as String,
      subcategoryId: map['subcategory_id'] as String?,
      name: map['name'] as String,
      description: map['description'] as String?,
      price: (map['price'] as num).toDouble(),
      cost: (map['cost'] as num?)?.toDouble() ?? 0.0,
      barcode: map['barcode'] as String?,
      imagePath: map['image_path'] as String?,
      inStock: stockFlag && qty > 0,
      stockQuantity: qty,
      colorHex: map['color_hex'] as String?,
      modifiersJson: map['modifiers_json'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Product copyWith({
    String? id,
    String? categoryId,
    String? subcategoryId,
    String? name,
    String? description,
    double? price,
    double? cost,
    String? barcode,
    String? imagePath,
    bool? inStock,
    int? stockQuantity,
    String? colorHex,
    String? modifiersJson,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      barcode: barcode ?? this.barcode,
      imagePath: imagePath ?? this.imagePath,
      inStock: inStock ?? this.inStock,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      colorHex: colorHex ?? this.colorHex,
      modifiersJson: modifiersJson ?? this.modifiersJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
