import 'package:flutter/material.dart';
import '../database/table_dao.dart';
import '../models/dining_table_model.dart';

class TableController extends ChangeNotifier {
  final TableDao _tableDao = TableDao();

  List<DiningTableModel> _tables = [];
  List<DiningTableModel> get tables => _tables;

  TableStatus? _filterStatus;
  TableStatus? get filterStatus => _filterStatus;

  TableType? _filterType;
  TableType? get filterType => _filterType;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  TableController() {
    loadTables();
  }

  int get totalCount => _tables.length;
  int get availableCount => _tables.where((t) => t.isAvailable).length;
  int get occupiedCount => _tables.where((t) => t.isOccupied).length;
  int get vipCount => _tables.where((t) => t.isVip).length;

  List<DiningTableModel> get filteredTables {
    return _tables.where((t) {
      if (_filterStatus != null && t.status != _filterStatus) return false;
      if (_filterType != null && t.type != _filterType) return false;
      return true;
    }).toList();
  }

  Future<void> loadTables() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _tables = await _tableDao.getTables();
    } catch (e) {
      _error = 'Failed to load tables: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilterStatus(TableStatus? status) {
    _filterStatus = status;
    notifyListeners();
  }

  void setFilterType(TableType? type) {
    _filterType = type;
    notifyListeners();
  }

  Future<bool> addTable({
    required String tableNumber,
    required String name,
    required int capacity,
    required TableType type,
  }) async {
    try {
      final newTable = DiningTableModel(
        id: 'tbl_${DateTime.now().millisecondsSinceEpoch}',
        tableNumber: tableNumber.trim(),
        name: name.trim(),
        capacity: capacity,
        type: type,
        status: TableStatus.available,
      );
      await _tableDao.insertTable(newTable);
      await loadTables();
      return true;
    } catch (e) {
      _error = 'Failed to add table: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTable(DiningTableModel table) async {
    try {
      await _tableDao.updateTable(table);
      await loadTables();
      return true;
    } catch (e) {
      _error = 'Failed to update table: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTable(String id) async {
    try {
      await _tableDao.deleteTable(id);
      await loadTables();
      return true;
    } catch (e) {
      _error = 'Failed to delete table: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> setTableStatus(String tableId, TableStatus status) async {
    try {
      await _tableDao.setTableStatus(tableId, status);
      await loadTables();
    } catch (e) {
      _error = 'Failed to update table status: $e';
      notifyListeners();
    }
  }

  Future<void> freeTable(String tableId) async {
    try {
      await _tableDao.freeTable(tableId);
      await loadTables();
    } catch (e) {
      _error = 'Failed to free table: $e';
      notifyListeners();
    }
  }
}
