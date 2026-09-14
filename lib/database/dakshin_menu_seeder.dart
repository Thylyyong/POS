import 'package:sqflite/sqflite.dart';

class DakshinMenuSeeder {
  // 1. Categories
  static const List<Map<String, dynamic>> categories = [
    {'id': 'cat_food', 'name': 'Food & Main Dishes', 'icon': 'food', 'color_hex': '0xFFF59E0B'},
    {'id': 'cat_drinks', 'name': 'Beverages & Chai', 'icon': 'drink', 'color_hex': '0xFF3B82F6'},
    {'id': 'cat_desserts', 'name': 'Indian Desserts', 'icon': 'dessert', 'color_hex': '0xFFEC4899'},
  ];

  // 2. 7 Subcategories
  static const List<Map<String, dynamic>> subcategories = [
    {'id': 'sub_starters', 'category_id': 'cat_food', 'name': 'Starters & Pakoras'},
    {'id': 'sub_tandoori', 'category_id': 'cat_food', 'name': 'Tandoori & Kebabs'},
    {'id': 'sub_dosa', 'category_id': 'cat_food', 'name': 'South Indian Dosas'},
    {'id': 'sub_biryani', 'category_id': 'cat_food', 'name': 'Biryani & Rice'},
    {'id': 'sub_curries', 'category_id': 'cat_food', 'name': 'Curries & Gravies'},
    {'id': 'sub_breads', 'category_id': 'cat_food', 'name': 'Naans & Roti'},
    {'id': 'sub_drinks_desserts', 'category_id': 'cat_drinks', 'name': 'Lassi, Chai & Sweets'},
  ];

  // 3. 96 Authentic Dakshin Indian Cuisine Dishes
  static const List<Map<String, dynamic>> dishes = [
      // ── Subcategory 1: Starters & Pakoras (14 items) ────────────────────────
      {'id': 'ind_01', 'sub': 'sub_starters', 'cat': 'cat_food', 'name': 'Crispy Vegetable Samosa (2 pcs)', 'price': 3.50, 'cost': 0.90},
      {'id': 'ind_02', 'sub': 'sub_starters', 'cat': 'cat_food', 'name': 'Paneer Pakora Fritters', 'price': 5.50, 'cost': 1.60},
      {'id': 'ind_03', 'sub': 'sub_starters', 'cat': 'cat_food', 'name': 'Golden Onion Bhaji', 'price': 4.50, 'cost': 1.10},
      {'id': 'ind_04', 'sub': 'sub_starters', 'cat': 'cat_food', 'name': 'Spicy Chicken 65', 'price': 7.50, 'cost': 2.20},
      {'id': 'ind_05', 'sub': 'sub_starters', 'cat': 'cat_food', 'name': 'Chicken Pepper Fry (Chettinad)', 'price': 8.00, 'cost': 2.40},
      {'id': 'ind_06', 'sub': 'sub_starters', 'cat': 'cat_food', 'name': 'Andhra Chilli Chicken', 'price': 7.95, 'cost': 2.30},
      {'id': 'ind_07', 'sub': 'sub_starters', 'cat': 'cat_food', 'name': 'Gobi Manchurian Dry', 'price': 5.95, 'cost': 1.50},
      {'id': 'ind_08', 'sub': 'sub_starters', 'cat': 'cat_food', 'name': 'Crispy Corn Salt & Pepper', 'price': 4.95, 'cost': 1.20},
      {'id': 'ind_09', 'sub': 'sub_starters', 'cat': 'cat_food', 'name': 'Medu Vada with Sambar (2 pcs)', 'price': 4.50, 'cost': 1.00},
      {'id': 'ind_10', 'sub': 'sub_starters', 'cat': 'cat_food', 'name': 'Steamed Idli Sambar (3 pcs)', 'price': 4.00, 'cost': 0.85},
      {'id': 'ind_11', 'sub': 'sub_starters', 'cat': 'cat_food', 'name': 'Ghee Podi Idli Bites', 'price': 4.75, 'cost': 1.15},
      {'id': 'ind_12', 'sub': 'sub_starters', 'cat': 'cat_food', 'name': 'Fish Amritsari Fry', 'price': 8.95, 'cost': 2.80},
      {'id': 'ind_13', 'sub': 'sub_starters', 'cat': 'cat_food', 'name': 'Prawn Koliwada Fritters', 'price': 9.50, 'cost': 3.10},
      {'id': 'ind_14', 'sub': 'sub_starters', 'cat': 'cat_food', 'name': 'Dahi Puri Chaat (6 pcs)', 'price': 4.95, 'cost': 1.25},

      // ── Subcategory 2: Tandoori & Kebabs (12 items) ──────────────────────────
      {'id': 'ind_15', 'sub': 'sub_tandoori', 'cat': 'cat_food', 'name': 'Tandoori Half Chicken', 'price': 9.50, 'cost': 3.00},
      {'id': 'ind_16', 'sub': 'sub_tandoori', 'cat': 'cat_food', 'name': 'Tandoori Whole Chicken', 'price': 16.50, 'cost': 5.20},
      {'id': 'ind_17', 'sub': 'sub_tandoori', 'cat': 'cat_food', 'name': 'Murgh Malai Kebab', 'price': 8.95, 'cost': 2.70},
      {'id': 'ind_18', 'sub': 'sub_tandoori', 'cat': 'cat_food', 'name': 'Tandoori Chicken Tikka', 'price': 8.50, 'cost': 2.50},
      {'id': 'ind_19', 'sub': 'sub_tandoori', 'cat': 'cat_food', 'name': 'Hariyali Mint Chicken Tikka', 'price': 8.75, 'cost': 2.60},
      {'id': 'ind_20', 'sub': 'sub_tandoori', 'cat': 'cat_food', 'name': 'Tandoori Paneer Tikka', 'price': 7.50, 'cost': 2.10},
      {'id': 'ind_21', 'sub': 'sub_tandoori', 'cat': 'cat_food', 'name': 'Hariyali Paneer Tikka', 'price': 7.75, 'cost': 2.20},
      {'id': 'ind_22', 'sub': 'sub_tandoori', 'cat': 'cat_food', 'name': 'Lamb Seekh Kebab (3 pcs)', 'price': 10.50, 'cost': 3.50},
      {'id': 'ind_23', 'sub': 'sub_tandoori', 'cat': 'cat_food', 'name': 'Chicken Seekh Kebab (3 pcs)', 'price': 8.95, 'cost': 2.80},
      {'id': 'ind_24', 'sub': 'sub_tandoori', 'cat': 'cat_food', 'name': 'Tandoori Prawns Jhinga', 'price': 12.50, 'cost': 4.20},
      {'id': 'ind_25', 'sub': 'sub_tandoori', 'cat': 'cat_food', 'name': 'Tandoori Fish Tikka', 'price': 10.95, 'cost': 3.60},
      {'id': 'ind_26', 'sub': 'sub_tandoori', 'cat': 'cat_food', 'name': 'Tandoori Mixed Grill Platter', 'price': 18.95, 'cost': 6.50},

      // ── Subcategory 3: South Indian Dosas & Crepes (14 items) ───────────────
      {'id': 'ind_27', 'sub': 'sub_dosa', 'cat': 'cat_food', 'name': 'Crispy Plain Dosa', 'price': 4.50, 'cost': 1.00},
      {'id': 'ind_28', 'sub': 'sub_dosa', 'cat': 'cat_food', 'name': 'Classic Masala Dosa', 'price': 5.50, 'cost': 1.30},
      {'id': 'ind_29', 'sub': 'sub_dosa', 'cat': 'cat_food', 'name': 'Mysore Masala Dosa', 'price': 6.25, 'cost': 1.50},
      {'id': 'ind_30', 'sub': 'sub_dosa', 'cat': 'cat_food', 'name': 'Ghee Roast Dosa', 'price': 5.95, 'cost': 1.40},
      {'id': 'ind_31', 'sub': 'sub_dosa', 'cat': 'cat_food', 'name': 'Ghee Masala Dosa', 'price': 6.50, 'cost': 1.60},
      {'id': 'ind_32', 'sub': 'sub_dosa', 'cat': 'cat_food', 'name': 'Cheese Masala Dosa', 'price': 6.95, 'cost': 1.80},
      {'id': 'ind_33', 'sub': 'sub_dosa', 'cat': 'cat_food', 'name': 'Onion Rava Dosa', 'price': 5.95, 'cost': 1.35},
      {'id': 'ind_34', 'sub': 'sub_dosa', 'cat': 'cat_food', 'name': 'Rava Masala Dosa', 'price': 6.50, 'cost': 1.55},
      {'id': 'ind_35', 'sub': 'sub_dosa', 'cat': 'cat_food', 'name': 'Paneer Bhurji Dosa', 'price': 7.25, 'cost': 1.95},
      {'id': 'ind_36', 'sub': 'sub_dosa', 'cat': 'cat_food', 'name': 'Chettinad Chicken Dosa', 'price': 7.95, 'cost': 2.30},
      {'id': 'ind_37', 'sub': 'sub_dosa', 'cat': 'cat_food', 'name': 'Mutton Sukka Dosa', 'price': 8.95, 'cost': 2.80},
      {'id': 'ind_38', 'sub': 'sub_dosa', 'cat': 'cat_food', 'name': 'Plain Onion Uttapam', 'price': 4.95, 'cost': 1.10},
      {'id': 'ind_39', 'sub': 'sub_dosa', 'cat': 'cat_food', 'name': 'Tomato Onion Chilli Uttapam', 'price': 5.50, 'cost': 1.25},
      {'id': 'ind_40', 'sub': 'sub_dosa', 'cat': 'cat_food', 'name': 'Cheese Chilli Uttapam', 'price': 6.25, 'cost': 1.50},

      // ── Subcategory 4: Biryani & Fragrant Rice (12 items) ───────────────────
      {'id': 'ind_41', 'sub': 'sub_biryani', 'cat': 'cat_food', 'name': 'Hyderabadi Chicken Dum Biryani', 'price': 9.50, 'cost': 2.90},
      {'id': 'ind_42', 'sub': 'sub_biryani', 'cat': 'cat_food', 'name': 'Special Boneless Chicken Biryani', 'price': 10.50, 'cost': 3.20},
      {'id': 'ind_43', 'sub': 'sub_biryani', 'cat': 'cat_food', 'name': 'Hyderabadi Mutton Dum Biryani', 'price': 12.50, 'cost': 4.20},
      {'id': 'ind_44', 'sub': 'sub_biryani', 'cat': 'cat_food', 'name': 'Chettinad Chicken Biryani', 'price': 9.95, 'cost': 3.10},
      {'id': 'ind_45', 'sub': 'sub_biryani', 'cat': 'cat_food', 'name': 'Malabar Prawn Biryani', 'price': 12.95, 'cost': 4.50},
      {'id': 'ind_46', 'sub': 'sub_biryani', 'cat': 'cat_food', 'name': 'Fresh Fish Biryani', 'price': 11.50, 'cost': 3.80},
      {'id': 'ind_47', 'sub': 'sub_biryani', 'cat': 'cat_food', 'name': 'Vegetable Dum Biryani', 'price': 7.50, 'cost': 2.00},
      {'id': 'ind_48', 'sub': 'sub_biryani', 'cat': 'cat_food', 'name': 'Paneer Tikka Biryani', 'price': 8.50, 'cost': 2.40},
      {'id': 'ind_49', 'sub': 'sub_biryani', 'cat': 'cat_food', 'name': 'Egg Dum Biryani', 'price': 7.95, 'cost': 2.10},
      {'id': 'ind_50', 'sub': 'sub_biryani', 'cat': 'cat_food', 'name': 'Fragrant Jeera Basmati Rice', 'price': 3.50, 'cost': 0.70},
      {'id': 'ind_51', 'sub': 'sub_biryani', 'cat': 'cat_food', 'name': 'Creamy Curd Rice (Thayir Sadam)', 'price': 4.50, 'cost': 0.95},
      {'id': 'ind_52', 'sub': 'sub_biryani', 'cat': 'cat_food', 'name': 'South Indian Sambar Rice', 'price': 4.95, 'cost': 1.10},

      // ── Subcategory 5: Rich Curries & Gravies (20 items) ─────────────────────
      {'id': 'ind_53', 'sub': 'sub_curries', 'cat': 'cat_food', 'name': 'Classic Butter Chicken (Murgh Makhani)', 'price': 9.95, 'cost': 3.20},
      {'id': 'ind_54', 'sub': 'sub_curries', 'cat': 'cat_food', 'name': 'Chicken Tikka Masala', 'price': 9.95, 'cost': 3.20},
      {'id': 'ind_55', 'sub': 'sub_curries', 'cat': 'cat_food', 'name': 'Chettinad Spicy Chicken Curry', 'price': 9.50, 'cost': 3.00},
      {'id': 'ind_56', 'sub': 'sub_curries', 'cat': 'cat_food', 'name': 'Chicken Korma Royale', 'price': 9.75, 'cost': 3.10},
      {'id': 'ind_57', 'sub': 'sub_curries', 'cat': 'cat_food', 'name': 'Fiery Chicken Vindaloo', 'price': 9.50, 'cost': 2.90},
      {'id': 'ind_58', 'sub': 'sub_curries', 'cat': 'cat_food', 'name': 'Kadai Chicken Wok Curry', 'price': 9.50, 'cost': 3.00},
      {'id': 'ind_59', 'sub': 'sub_curries', 'cat': 'cat_food', 'name': 'Kashmiri Mutton Rogan Josh', 'price': 12.50, 'cost': 4.40},
      {'id': 'ind_60', 'sub': 'sub_curries', 'cat': 'cat_food', 'name': 'Slow-Cooked Mutton Sukka', 'price': 12.95, 'cost': 4.50},
      {'id': 'ind_61', 'sub': 'sub_curries', 'cat': 'cat_food', 'name': 'Bhuna Gosht Lamb', 'price': 12.50, 'cost': 4.30},
      {'id': 'ind_62', 'sub': 'sub_curries', 'cat': 'cat_food', 'name': 'Goan Fish Curry with Coconut', 'price': 10.95, 'cost': 3.70},
      {'id': 'ind_63', 'sub': 'sub_curries', 'cat': 'cat_food', 'name': 'Malabar Prawn Curry', 'price': 12.50, 'cost': 4.20},
      {'id': 'ind_64', 'sub': 'sub_curries', 'cat': 'cat_food', 'name': 'Paneer Butter Masala', 'price': 8.50, 'cost': 2.50},
      {'id': 'ind_65', 'sub': 'sub_curries', 'cat': 'cat_food', 'name': 'Palak Paneer (Spinach Gravy)', 'price': 8.25, 'cost': 2.40},
      {'id': 'ind_66', 'sub': 'sub_curries', 'cat': 'cat_food', 'name': 'Kadai Paneer Bell Pepper', 'price': 8.50, 'cost': 2.50},
      {'id': 'ind_67', 'sub': 'sub_curries', 'cat': 'cat_food', 'name': 'Slow-Cooked Dal Makhani', 'price': 6.95, 'cost': 1.80},
      {'id': 'ind_68', 'sub': 'sub_curries', 'cat': 'cat_food', 'name': 'Yellow Dal Tadka Homestyle', 'price': 5.95, 'cost': 1.40},
      {'id': 'ind_69', 'sub': 'sub_curries', 'cat': 'cat_food', 'name': 'Pindi Chana Masala (Chickpeas)', 'price': 6.50, 'cost': 1.60},
      {'id': 'ind_70', 'sub': 'sub_curries', 'cat': 'cat_food', 'name': 'Aloo Gobi Adraki', 'price': 6.25, 'cost': 1.45},
      {'id': 'ind_71', 'sub': 'sub_curries', 'cat': 'cat_food', 'name': 'Baingan Bharta Smoked Eggplant', 'price': 6.75, 'cost': 1.60},
      {'id': 'ind_72', 'sub': 'sub_curries', 'cat': 'cat_food', 'name': 'Vegetable Kolhapuri Spicy', 'price': 6.95, 'cost': 1.70},

      // ── Subcategory 6: Naans & Tandoori Breads (12 items) ───────────────────
      {'id': 'ind_73', 'sub': 'sub_breads', 'cat': 'cat_food', 'name': 'Tandoori Roti (Plain)', 'price': 1.50, 'cost': 0.30},
      {'id': 'ind_74', 'sub': 'sub_breads', 'cat': 'cat_food', 'name': 'Butter Tandoori Roti', 'price': 1.95, 'cost': 0.45},
      {'id': 'ind_75', 'sub': 'sub_breads', 'cat': 'cat_food', 'name': 'Plain Naan Clay Oven', 'price': 2.00, 'cost': 0.40},
      {'id': 'ind_76', 'sub': 'sub_breads', 'cat': 'cat_food', 'name': 'Butter Naan', 'price': 2.50, 'cost': 0.55},
      {'id': 'ind_77', 'sub': 'sub_breads', 'cat': 'cat_food', 'name': 'Garlic Butter Naan', 'price': 2.95, 'cost': 0.65},
      {'id': 'ind_78', 'sub': 'sub_breads', 'cat': 'cat_food', 'name': 'Cheese Naan Stuffed', 'price': 3.50, 'cost': 0.90},
      {'id': 'ind_79', 'sub': 'sub_breads', 'cat': 'cat_food', 'name': 'Chilli Cheese Garlic Naan', 'price': 3.95, 'cost': 1.05},
      {'id': 'ind_80', 'sub': 'sub_breads', 'cat': 'cat_food', 'name': 'Kashmiri Sweet Peshawari Naan', 'price': 3.75, 'cost': 1.00},
      {'id': 'ind_81', 'sub': 'sub_breads', 'cat': 'cat_food', 'name': 'Layered Laccha Paratha', 'price': 2.75, 'cost': 0.65},
      {'id': 'ind_82', 'sub': 'sub_breads', 'cat': 'cat_food', 'name': 'Aloo Kulcha Stuffed Potato', 'price': 3.50, 'cost': 0.85},
      {'id': 'ind_83', 'sub': 'sub_breads', 'cat': 'cat_food', 'name': 'Paneer Kulcha Stuffed', 'price': 3.95, 'cost': 1.05},
      {'id': 'ind_84', 'sub': 'sub_breads', 'cat': 'cat_food', 'name': 'Kerala Malabar Parotta (2 pcs)', 'price': 3.25, 'cost': 0.80},

      // ── Subcategory 7: Lassi, Chai & Sweets (12 items) ──────────────────────
      {'id': 'ind_85', 'sub': 'sub_drinks_desserts', 'cat': 'cat_drinks', 'name': 'Alphonso Mango Lassi', 'price': 3.50, 'cost': 0.90},
      {'id': 'ind_86', 'sub': 'sub_drinks_desserts', 'cat': 'cat_drinks', 'name': 'Sweet Cardamom Lassi', 'price': 2.95, 'cost': 0.70},
      {'id': 'ind_87', 'sub': 'sub_drinks_desserts', 'cat': 'cat_drinks', 'name': 'Salted Cumin Buttermilk (Chaas)', 'price': 2.50, 'cost': 0.55},
      {'id': 'ind_88', 'sub': 'sub_drinks_desserts', 'cat': 'cat_drinks', 'name': 'Masala Chai Karak Tea', 'price': 2.25, 'cost': 0.45},
      {'id': 'ind_89', 'sub': 'sub_drinks_desserts', 'cat': 'cat_drinks', 'name': 'South Indian Filter Coffee', 'price': 2.50, 'cost': 0.50},
      {'id': 'ind_90', 'sub': 'sub_drinks_desserts', 'cat': 'cat_drinks', 'name': 'Fresh Nimbu Soda (Sweet & Salt)', 'price': 2.50, 'cost': 0.50},
      {'id': 'ind_91', 'sub': 'sub_drinks_desserts', 'cat': 'cat_desserts', 'name': 'Warm Gulab Jamun (2 pcs)', 'price': 3.50, 'cost': 0.80},
      {'id': 'ind_92', 'sub': 'sub_drinks_desserts', 'cat': 'cat_desserts', 'name': 'Kesar Rasmalai Saffron (2 pcs)', 'price': 4.25, 'cost': 1.10},
      {'id': 'ind_93', 'sub': 'sub_drinks_desserts', 'cat': 'cat_desserts', 'name': 'Gajar Ka Halwa Warm Carrot Pudding', 'price': 3.95, 'cost': 0.95},
      {'id': 'ind_94', 'sub': 'sub_drinks_desserts', 'cat': 'cat_desserts', 'name': 'Traditional Kulfi Falooda Sundae', 'price': 4.50, 'cost': 1.20},
      {'id': 'ind_95', 'sub': 'sub_drinks_desserts', 'cat': 'cat_desserts', 'name': 'Rice Kheer with Pistachios', 'price': 3.50, 'cost': 0.80},
      {'id': 'ind_96', 'sub': 'sub_drinks_desserts', 'cat': 'cat_desserts', 'name': 'Moong Dal Halwa Ghee Pudding', 'price': 4.00, 'cost': 1.05},
    ];

  static Future<int> seedDakshinMenu(Database db) async {
    final now = DateTime.now().toIso8601String();

    for (final c in categories) {
      final map = Map<String, dynamic>.from(c);
      map['created_at'] = now;
      await db.insert('categories', map, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    for (final s in subcategories) {
      final map = Map<String, dynamic>.from(s);
      map['created_at'] = now;
      await db.insert('subcategories', map, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    int inserted = 0;
    for (var d in dishes) {
      await db.insert(
        'products',
        {
          'id': d['id'] as String,
          'category_id': d['cat'] as String,
          'subcategory_id': d['sub'] as String,
          'name': d['name'] as String,
          'price': (d['price'] as num).toDouble(),
          'cost': (d['cost'] as num).toDouble(),
          'barcode': 'IND${(d['id'] as String).replaceAll('ind_', '')}',
          'color_hex': '0xFFF59E0B',
          'in_stock': 1,
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      inserted++;
    }

    return inserted;
  }
}
