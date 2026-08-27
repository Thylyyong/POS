enum TableStatus {
  available,
  occupied,
  billRequested;

  String get displayName {
    switch (this) {
      case TableStatus.available:
        return 'AVAILABLE';
      case TableStatus.occupied:
        return 'OCCUPIED';
      case TableStatus.billRequested:
        return 'BILL DUE';
    }
  }

  static TableStatus fromString(String val) {
    switch (val.toUpperCase()) {
      case 'OCCUPIED':
        return TableStatus.occupied;
      case 'BILL_REQUESTED':
      case 'BILL DUE':
      case 'BILLDUE':
        return TableStatus.billRequested;
      case 'AVAILABLE':
      default:
        return TableStatus.available;
    }
  }
}

enum TableType {
  standard,
  vipRoom,
  outdoor,
  bar;

  String get displayName {
    switch (this) {
      case TableType.standard:
        return 'Standard Table';
      case TableType.vipRoom:
        return 'VIP Room';
      case TableType.outdoor:
        return 'Patio / Outdoor';
      case TableType.bar:
        return 'Bar Counter';
    }
  }

  static TableType fromString(String val) {
    switch (val.toUpperCase()) {
      case 'VIP_ROOM':
      case 'VIPROOM':
      case 'VIP':
        return TableType.vipRoom;
      case 'OUTDOOR':
      case 'PATIO':
        return TableType.outdoor;
      case 'BAR':
        return TableType.bar;
      case 'STANDARD':
      default:
        return TableType.standard;
    }
  }
}

class DiningTableModel {
  final String id;
  final String tableNumber;
  final String name;
  final int capacity;
  final TableStatus status;
  final TableType type;
  final String? currentOrderId;
  final String? customerName;
  final double? orderTotal;
  final DateTime createdAt;

  DiningTableModel({
    required this.id,
    required this.tableNumber,
    required this.name,
    this.capacity = 4,
    this.status = TableStatus.available,
    this.type = TableType.standard,
    this.currentOrderId,
    this.customerName,
    this.orderTotal,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isAvailable => status == TableStatus.available;
  bool get isOccupied => status == TableStatus.occupied;
  bool get isVip => type == TableType.vipRoom;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'table_number': tableNumber,
      'name': name,
      'capacity': capacity,
      'status': status.displayName,
      'type': type.name.toUpperCase(),
      'current_order_id': currentOrderId,
      'customer_name': customerName,
      'order_total': orderTotal,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory DiningTableModel.fromMap(Map<String, dynamic> map) {
    return DiningTableModel(
      id: map['id'] as String,
      tableNumber: map['table_number'] as String? ?? 'T01',
      name: map['name'] as String? ?? 'Table',
      capacity: map['capacity'] as int? ?? 4,
      status: TableStatus.fromString(map['status'] as String? ?? 'AVAILABLE'),
      type: TableType.fromString(map['type'] as String? ?? 'STANDARD'),
      currentOrderId: map['current_order_id'] as String?,
      customerName: map['customer_name'] as String?,
      orderTotal: (map['order_total'] as num?)?.toDouble(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  DiningTableModel copyWith({
    String? id,
    String? tableNumber,
    String? name,
    int? capacity,
    TableStatus? status,
    TableType? type,
    String? currentOrderId,
    String? customerName,
    double? orderTotal,
    DateTime? createdAt,
  }) {
    return DiningTableModel(
      id: id ?? this.id,
      tableNumber: tableNumber ?? this.tableNumber,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      type: type ?? this.type,
      currentOrderId: currentOrderId ?? this.currentOrderId,
      customerName: customerName ?? this.customerName,
      orderTotal: orderTotal ?? this.orderTotal,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
