import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import 'local_json_store.dart';

typedef ObjectivesStoreReader = Future<String?> Function(String name);
typedef ObjectivesStoreWriter =
    Future<void> Function(String name, String contents);

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
  CommercialObjectivesService._()
    : _useWebStorage = kIsWeb,
      _readStore = readLocalJson,
      _writeStore = writeLocalJson;

  @visibleForTesting
  CommercialObjectivesService.forWebTesting({
    required ObjectivesStoreReader readStore,
    required ObjectivesStoreWriter writeStore,
  }) : _useWebStorage = true,
       _readStore = readStore,
       _writeStore = writeStore;

  static final CommercialObjectivesService instance =
      CommercialObjectivesService._();

  static const String _webStoreName = 'commercial_objectives_v1.json';

  final bool _useWebStorage;
  final ObjectivesStoreReader _readStore;
  final ObjectivesStoreWriter _writeStore;
  Map<int, CommercialObjective>? _webObjectives;

  Map<int, CommercialObjective> _defaultWebObjectives() => {
    1: CommercialObjective(
      commercialId: 1,
      orderTarget: 14,
      revenueTarget: 95000,
    ),
    3: CommercialObjective(
      commercialId: 3,
      orderTarget: 11,
      revenueTarget: 82000,
    ),
    4: CommercialObjective(
      commercialId: 4,
      orderTarget: 9,
      revenueTarget: 76000,
    ),
  };

  Future<Map<int, CommercialObjective>> _loadWebObjectives() async {
    final cached = _webObjectives;
    if (cached != null) return cached;

    final stored = await _readStore(_webStoreName);
    if (stored == null) {
      final seeded = _defaultWebObjectives();
      await _writeWebObjectives(seeded);
      _webObjectives = seeded;
      return seeded;
    }

    final loaded = _decodeWebObjectives(stored);
    _webObjectives = loaded;
    return loaded;
  }

  Map<int, CommercialObjective> _decodeWebObjectives(String stored) {
    try {
      final decoded = jsonDecode(stored);
      final rawRows = decoded is Map ? decoded['objectives'] : decoded;
      if (rawRows is! List) return {};

      final objectives = <int, CommercialObjective>{};
      for (final rawRow in rawRows.whereType<Map>()) {
        try {
          final objective = CommercialObjective.fromMap(
            rawRow.cast<String, Object?>(),
          );
          if (objective.commercialId > 0) {
            objectives[objective.commercialId] = objective;
          }
        } on Object {
          // Keep every valid objective even if one row is malformed.
        }
      }
      return objectives;
    } on Object {
      // Corrupt browser storage must not break the manager dashboard. An
      // explicit future save will replace it with a valid document.
      return {};
    }
  }

  Future<void> _writeWebObjectives(Map<int, CommercialObjective> objectives) =>
      _writeStore(
        _webStoreName,
        jsonEncode({
          'version': 1,
          'objectives': objectives.values
              .map((value) => value.toMap())
              .toList(),
        }),
      );

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
    if (_useWebStorage) {
      final objectives = await _loadWebObjectives();
      return objectives[commercialId];
    }
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
    if (_useWebStorage) {
      final objectives = await _loadWebObjectives();
      final previous = objectives[objective.commercialId];
      objectives[objective.commercialId] = objective;
      try {
        await _writeWebObjectives(objectives);
      } catch (_) {
        if (previous == null) {
          objectives.remove(objective.commercialId);
        } else {
          objectives[objective.commercialId] = previous;
        }
        rethrow;
      }
      return;
    }
    await _ensureTable();
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'commercial_objectives',
      objective.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Assigns several objectives in one shot (same target to many commercials).
  /// Written as a single storage write so a bulk assignment can't half-apply,
  /// leaving some commercials with the objective and others without.
  Future<void> saveObjectives(Iterable<CommercialObjective> objectives) async {
    final pending = objectives.toList();
    if (pending.isEmpty) return;

    if (_useWebStorage) {
      final current = await _loadWebObjectives();
      final snapshot = Map<int, CommercialObjective>.from(current);
      for (final objective in pending) {
        current[objective.commercialId] = objective;
      }
      try {
        await _writeWebObjectives(current);
      } catch (_) {
        // Keep the in-memory cache matching what is actually stored.
        _webObjectives = snapshot;
        rethrow;
      }
      return;
    }

    await _ensureTable();
    final db = await DatabaseHelper.instance.database;
    final batch = db.batch();
    for (final objective in pending) {
      batch.insert(
        'commercial_objectives',
        objective.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
