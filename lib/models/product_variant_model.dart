import 'dart:convert';

/// Represents an optional add-on with an additional price charge.
class ProductAddon {
  final String id;
  final String name;
  final double price;

  const ProductAddon({
    required this.id,
    required this.name,
    required this.price,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'price': price,
      };

  factory ProductAddon.fromMap(Map<String, dynamic> map) {
    return ProductAddon(
      id: map['id'] as String? ?? 'addon_${DateTime.now().microsecondsSinceEpoch}',
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  ProductAddon copyWith({
    String? id,
    String? name,
    double? price,
  }) {
    return ProductAddon(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
    );
  }
}

/// Represents a customizable option group (e.g. Size, Flavor, Temperature, Milk Type)
class ProductVariantGroup {
  final String id;
  final String name; // e.g., "Size", "Flavor", "Temperature", "Milk Type"
  final List<String> options; // e.g., ["Regular", "Large"] or ["Hot", "Iced"]
  final String? defaultOption;

  const ProductVariantGroup({
    required this.id,
    required this.name,
    required this.options,
    this.defaultOption,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'options': options,
        'default_option': defaultOption,
      };

  factory ProductVariantGroup.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'];
    List<String> parsedOptions = [];
    if (rawOptions is List) {
      parsedOptions = rawOptions
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (rawOptions is String) {
      parsedOptions = rawOptions
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return ProductVariantGroup(
      id: map['id'] as String? ?? 'grp_${DateTime.now().microsecondsSinceEpoch}',
      name: map['name'] as String? ?? '',
      options: parsedOptions,
      defaultOption: map['default_option'] as String?,
    );
  }

  ProductVariantGroup copyWith({
    String? id,
    String? name,
    List<String>? options,
    String? defaultOption,
  }) {
    return ProductVariantGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      options: options ?? this.options,
      defaultOption: defaultOption ?? this.defaultOption,
    );
  }
}

/// Configuration for product variants & customizable modifiers
class ProductVariantConfig {
  final bool isEnabled;
  final bool hasSugar;
  final bool hasIce;
  final bool hasSpicy;
  final List<ProductVariantGroup> customGroups;
  final List<ProductAddon> addons;

  const ProductVariantConfig({
    this.isEnabled = false,
    this.hasSugar = false,
    this.hasIce = false,
    this.hasSpicy = false,
    this.customGroups = const [],
    this.addons = const [],
  });

  bool get hasAnyOptions =>
      isEnabled &&
      (hasSugar ||
          hasIce ||
          hasSpicy ||
          customGroups.isNotEmpty ||
          addons.isNotEmpty);

  Map<String, dynamic> toMap() => {
        'is_enabled': isEnabled,
        'has_sugar': hasSugar,
        'has_ice': hasIce,
        'has_spicy': hasSpicy,
        'custom_groups': customGroups.map((g) => g.toMap()).toList(),
        'addons': addons.map((a) => a.toMap()).toList(),
      };

  String toJson() => jsonEncode(toMap());

  factory ProductVariantConfig.fromMap(Map<String, dynamic> map) {
    final addonsList = (map['addons'] as List?)
            ?.map((e) => ProductAddon.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        <ProductAddon>[];

    final customGroupsList = (map['custom_groups'] as List?)
            ?.map((e) => ProductVariantGroup.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        <ProductVariantGroup>[];

    final hasSugar = map['has_sugar'] as bool? ?? false;
    final hasIce = map['has_ice'] as bool? ?? false;
    final hasSpicy = map['has_spicy'] as bool? ?? false;

    final isEnabled = map.containsKey('is_enabled')
        ? (map['is_enabled'] as bool? ?? false)
        : (hasSugar || hasIce || hasSpicy || addonsList.isNotEmpty || customGroupsList.isNotEmpty);

    return ProductVariantConfig(
      isEnabled: isEnabled,
      hasSugar: hasSugar,
      hasIce: hasIce,
      hasSpicy: hasSpicy,
      customGroups: customGroupsList,
      addons: addonsList,
    );
  }

  factory ProductVariantConfig.fromJson(
    String? jsonStr, {
    required String categoryId,
    required String productName,
  }) {
    if (jsonStr != null && jsonStr.trim().isNotEmpty) {
      try {
        final map = jsonDecode(jsonStr);
        if (map is Map<String, dynamic>) {
          return ProductVariantConfig.fromMap(map);
        }
      } catch (_) {}
    }
    // Fall back to intelligent defaults based on product & category
    return ProductVariantConfig.defaultFor(
      categoryId: categoryId,
      productName: productName,
    );
  }

  /// Default presets for drinks, food, and standard products
  factory ProductVariantConfig.defaultFor({
    required String categoryId,
    required String productName,
  }) {
    final cat = categoryId.toLowerCase();
    final name = productName.toLowerCase();

    // Coffee & Beverages: Sugar, Ice, Size, Extra Shot
    final isDrink = cat.contains('coffee') ||
        cat.contains('drink') ||
        name.contains('espresso') ||
        name.contains('latte') ||
        name.contains('cappuccino') ||
        name.contains('matcha') ||
        name.contains('smoothie') ||
        name.contains('frappe') ||
        name.contains('tea') ||
        name.contains('lemonade');

    if (isDrink) {
      final isHotOnly = name.contains('hot') || name.contains('espresso');
      return ProductVariantConfig(
        isEnabled: true,
        hasSugar: true,
        hasIce: !isHotOnly,
        hasSpicy: false,
        customGroups: const [
          ProductVariantGroup(
            id: 'grp_size',
            name: 'Size',
            options: ['Regular', 'Large'],
            defaultOption: 'Regular',
          ),
        ],
        addons: const [
          ProductAddon(
            id: 'addon_extra_shot',
            name: 'Extra Espresso Shot',
            price: 0.50,
          ),
        ],
      );
    }

    // Burgers, Sandwiches, Mains: Spicy, Extra Cheese, Extra Size
    final isFood = cat.contains('burger') ||
        cat.contains('main') ||
        name.contains('burger') ||
        name.contains('chicken') ||
        name.contains('sandwich') ||
        name.contains('fries') ||
        name.contains('pasta') ||
        name.contains('bowl') ||
        name.contains('pad thai');

    if (isFood) {
      return const ProductVariantConfig(
        isEnabled: true,
        hasSugar: false,
        hasIce: false,
        hasSpicy: true,
        customGroups: [],
        addons: [
          ProductAddon(
            id: 'addon_extra_cheese',
            name: 'Extra Cheese',
            price: 0.50,
          ),
          ProductAddon(
            id: 'addon_extra_size',
            name: 'Extra Size / Upsize',
            price: 1.00,
          ),
        ],
      );
    }

    return const ProductVariantConfig(isEnabled: false);
  }

  ProductVariantConfig copyWith({
    bool? isEnabled,
    bool? hasSugar,
    bool? hasIce,
    bool? hasSpicy,
    List<ProductVariantGroup>? customGroups,
    List<ProductAddon>? addons,
  }) {
    return ProductVariantConfig(
      isEnabled: isEnabled ?? this.isEnabled,
      hasSugar: hasSugar ?? this.hasSugar,
      hasIce: hasIce ?? this.hasIce,
      hasSpicy: hasSpicy ?? this.hasSpicy,
      customGroups: customGroups ?? this.customGroups,
      addons: addons ?? this.addons,
    );
  }
}
