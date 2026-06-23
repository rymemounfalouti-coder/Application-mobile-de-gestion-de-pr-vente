import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';

class CommercialObjective {
  CommercialObjective({
    required this.commercialId,
    this.orderTarget,
    this.revenueTarget,
  });

  final int commercialId;
  final int? orderTarget;
  final double? revenueTarget;

  bool get hasOrderTarget => orderTarget != null && orderTarget! > 0;
  bool get hasRevenueTarget => revenueTarget != null && revenueTarget! > 0;
  bool get isDefined => hasOrderTarget || hasRevenueTarget;

  factory CommercialObjective.fromMap(Map<String, Object?> map) {
    return CommercialObjective(
      commercialId: (map['commercial_id'] as num).toInt(),
      orderTarget: map['order_target'] == null
          ? null
          : (map['order_target'] as num).toInt(),
      revenueTarget: map['revenue_target'] == null
          ? null
          : (map['revenue_target'] as num).toDouble(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'commercial_id': commercialId,
      'order_target': orderTarget,
      'revenue_target': revenueTarget,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}

class CommercialObjectivesService {
  CommercialObjectivesService._();

  static final CommercialObjectivesService instance =
      CommercialObjectivesService._();

  Future<void> _ensureTable() async {
    final db = await DatabaseHelper.instance.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS commercial_objectives (
        commercial_id INTEGER PRIMARY KEY,
        order_target INTEGER,
        revenue_target REAL,
        updated_at TEXT
      )
    ''');
  }

  Future<CommercialObjective?> getObjective(int commercialId) async {
    await _ensureTable();
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'commercial_objectives',
      where: 'commercial_id = ?',
      whereArgs: [commercialId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CommercialObjective.fromMap(rows.first);
  }

  Future<void> saveObjective(CommercialObjective objective) async {
    await _ensureTable();
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'commercial_objectives',
      objective.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
