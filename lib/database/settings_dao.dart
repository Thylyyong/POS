import 'package:sqflite/sqflite.dart';
import '../models/store_settings_model.dart';
import 'db_helper.dart';

class SettingsDao {
  final DbHelper _dbHelper = DbHelper();

  Future<StoreSettingsModel> getSettings() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('settings');

    final map = <String, String>{};
    for (var row in maps) {
      final key = row['key'] as String;
      final val = row['value'] as String? ?? '';
      map[key] = val;
    }

    if (map.isEmpty) {
      return const StoreSettingsModel();
    }

    return StoreSettingsModel.fromMap(map);
  }

  Future<void> saveSettings(StoreSettingsModel settings) async {
    final db = await _dbHelper.database;
    final map = settings.toMap();

    final batch = db.batch();
    for (var entry in map.entries) {
      batch.insert(
        'settings',
        {'key': entry.key, 'value': entry.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateSingleSetting(String key, String value) async {
    final db = await _dbHelper.database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
