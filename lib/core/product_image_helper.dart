import 'dart:io';
import 'package:flutter/material.dart';

/// Centralized helper for robust product image loading and automatic fallback.
/// Ensures all product cards and cart tiles display rich food and drink images
/// even when image_path in the database is null, empty, or unresolvable.
class ProductImageHelper {
  /// Resolves an [ImageProvider] for a product or cart item with intelligent fallbacks.
  static ImageProvider resolveImageProvider({
    String? imagePath,
    String? productName,
    String? categoryId,
  }) {
    final cleanPath = imagePath?.trim();
    if (cleanPath != null && cleanPath.isNotEmpty && cleanPath != 'null') {
      if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
        return NetworkImage(cleanPath);
      }
      if (cleanPath.startsWith('assets/') || cleanPath.startsWith('lib/assets/')) {
        return AssetImage(cleanPath);
      }
      final fileUri = cleanPath.startsWith('file://')
          ? Uri.parse(cleanPath).toFilePath()
          : cleanPath;
      final file = File(fileUri);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }

    // Intelligent fallback to bundled high-res food/drink asset
    return AssetImage(
      getDefaultAssetFor(productName: productName, categoryId: categoryId),
    );
  }

  /// Maps a product name or category ID to the best bundled food/drink image asset.
  static String getDefaultAssetFor({String? productName, String? categoryId}) {
    final name = (productName ?? '').toLowerCase();
    final cat = (categoryId ?? '').toLowerCase();

    // 1. Drinks / Coffee
    if (cat.contains('coffee') ||
        name.contains('espresso') ||
        name.contains('americano') ||
        name.contains('latte') ||
        name.contains('cappuccino') ||
        name.contains('matcha') ||
        name.contains('coffee')) {
      return 'assets/images/coffee_latte.png';
    }

    // 2. Smoothies
    if (name.contains('mango') || name.contains('smoothie')) {
      return 'assets/images/mango_smoothie.png';
    }

    // 3. Frappes / Acai / Berries
    if (name.contains('berry') ||
        name.contains('acai') ||
        name.contains('frappe')) {
      return 'assets/images/berry_frappe.png';
    }

    // 4. Lemonades & Refreshers
    if (cat.contains('drink') ||
        name.contains('lemonade') ||
        name.contains('sparkling') ||
        name.contains('shake') ||
        name.contains('tea') ||
        name.contains('juice')) {
      return 'assets/images/beverage_lemonade.png';
    }

    // 5. Burgers, Sandwiches, Fries, Onion Rings
    if (cat.contains('burger') ||
        name.contains('burger') ||
        name.contains('sandwich') ||
        name.contains('club') ||
        name.contains('fries') ||
        name.contains('onion ring') ||
        name.contains('chicken')) {
      return 'assets/images/burger_fastfood.png';
    }

    // 6. Salmon Teriyaki Bowl
    if (name.contains('salmon') || name.contains('teriyaki')) {
      return 'assets/images/salmon_teriyaki.png';
    }

    // 7. Asian & Western Mains (Pad Thai, Carbonara, Pasta, Rice)
    if (cat.contains('mains') ||
        name.contains('thai') ||
        name.contains('carbonara') ||
        name.contains('pasta') ||
        name.contains('noodle') ||
        name.contains('rice')) {
      return 'assets/images/asian_mains.png';
    }

    // 8. Pastries, Desserts, Cakes
    if (cat.contains('dessert') ||
        cat.contains('pastr') ||
        name.contains('croissant') ||
        name.contains('cheesecake') ||
        name.contains('tiramisu') ||
        name.contains('cake') ||
        name.contains('pancake') ||
        name.contains('bread')) {
      return 'assets/images/pastry_dessert.png';
    }

    // Default general asset
    return 'assets/images/pastry_dessert.png';
  }
}
