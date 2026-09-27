import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/calculators.dart';
import '../core/models.dart';

class AppDatabase {
  AppDatabase({this.databasePath});

  static final AppDatabase instance = AppDatabase();
  static const _databaseName = 'diabetes_food_calculator.db';
  static const _databaseVersion = 3;

  final String? databasePath;
  Database? _database;

  Future<void> ensureReady() async {
    await database;
  }

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _open();
    return _database!;
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }

  Future<Database> _open() async {
    final path = databasePath ?? await _resolveDatabasePath();
    return openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
        await _seedSampleFoods(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE foods ADD COLUMN normalized_aliases TEXT NOT NULL DEFAULT \'\'',
          );
          final rows = await db.query('foods', columns: ['id', 'aliases']);
          for (final row in rows) {
            await db.update(
              'foods',
              {
                'normalized_aliases': _normalizeAliases(
                  row['aliases'] as String? ?? '',
                ),
              },
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE insulin_profiles ADD COLUMN total_daily_insulin REAL',
          );
          await db.execute(
            'ALTER TABLE insulin_profiles ADD COLUMN carb_rule REAL',
          );
          await db.execute(
            'ALTER TABLE insulin_profiles ADD COLUMN protein_fat_base REAL',
          );
          await db.execute(
            'ALTER TABLE insulin_profiles ADD COLUMN correction_standard REAL',
          );
          await db.execute(
            'ALTER TABLE insulin_profiles ADD COLUMN cir_formula TEXT NOT NULL DEFAULT \'${InsulinProfile.defaultCirFormula}\'',
          );
          await db.execute(
            'ALTER TABLE insulin_profiles ADD COLUMN carb_insulin_formula TEXT NOT NULL DEFAULT \'${InsulinProfile.defaultCarbInsulinFormula}\'',
          );
          await db.execute(
            'ALTER TABLE insulin_profiles ADD COLUMN protein_fat_formula TEXT NOT NULL DEFAULT \'${InsulinProfile.defaultProteinFatMassFormula}\'',
          );
          await db.execute(
            'ALTER TABLE insulin_profiles ADD COLUMN isf_formula TEXT NOT NULL DEFAULT \'${InsulinProfile.defaultIsfFormula}\'',
          );

          final profileRows = await db.query('insulin_profiles');
          for (final row in profileRows) {
            final carbRatio = (row['carb_ratio']! as num).toDouble();
            final formulaType = row['formula_type']! as String;
            final proteinCoefficient =
                (row['protein_coefficient'] as num?)?.toDouble();

            await db.update(
              'insulin_profiles',
              {
                'total_daily_insulin': null,
                'carb_rule': null,
                'protein_fat_base':
                    formulaType == '合计克数' && proteinCoefficient != null
                    ? proteinCoefficient
                    : null,
                'correction_standard': null,
                'cir_formula': 'carb_ratio',
                'carb_insulin_formula': InsulinProfile.defaultCarbInsulinFormula,
                'protein_fat_formula': _migratedProteinFatFormula(
                  formulaType: formulaType,
                ),
                'isf_formula': '1',
              },
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
        }
      },
    );
  }

  Future<String> _resolveDatabasePath() async {
    final directory = await getApplicationSupportDirectory();
    return p.join(directory.path, _databaseName);
  }

  Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE foods (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        normalized_name TEXT NOT NULL,
        aliases TEXT NOT NULL DEFAULT '',
        normalized_aliases TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL DEFAULT '',
        carbs_g_per_100 REAL NOT NULL,
        protein_g_per_100 REAL NOT NULL,
        fat_g_per_100 REAL NOT NULL,
        is_custom INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE meals (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        meal_type TEXT NOT NULL,
        eaten_at TEXT NOT NULL,
        total_carbs_g REAL NOT NULL,
        total_protein_g REAL NOT NULL,
        total_fat_g REAL NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE meal_items (
        id TEXT PRIMARY KEY,
        meal_id TEXT NOT NULL,
        food_id TEXT,
        food_name_snapshot TEXT NOT NULL,
        weight_g REAL NOT NULL,
        carbs_g_per_100 REAL NOT NULL,
        protein_g_per_100 REAL NOT NULL,
        fat_g_per_100 REAL NOT NULL,
        carbs_g REAL NOT NULL,
        protein_g REAL NOT NULL,
        fat_g REAL NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (meal_id) REFERENCES meals(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE insulin_profiles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        carb_ratio REAL NOT NULL,
        protein_fat_enabled INTEGER NOT NULL DEFAULT 0,
        formula_type TEXT NOT NULL,
        protein_coefficient REAL,
        fat_coefficient REAL,
        total_daily_insulin REAL,
        carb_rule REAL,
        protein_fat_base REAL,
        correction_standard REAL,
        cir_formula TEXT NOT NULL,
        carb_insulin_formula TEXT NOT NULL,
        protein_fat_formula TEXT NOT NULL,
        isf_formula TEXT NOT NULL,
        rounding_increment REAL NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _seedSampleFoods(DatabaseExecutor db) async {
    final now = DateTime.now().toIso8601String();
    final foods = [
      _sampleFood(
        name: '米饭',
        aliases: ['白米饭', '熟米饭'],
        category: '谷薯类',
        carbsPer100: 25.9,
        proteinPer100: 2.6,
        fatPer100: 0.3,
        now: now,
      ),
    ];

    for (final food in foods) {
      await db.insert('foods', food);
    }
  }

  Map<String, Object?> _sampleFood({
    required String name,
    required List<String> aliases,
    required String category,
    required double carbsPer100,
    required double proteinPer100,
    required double fatPer100,
    required String now,
  }) {
    return {
      'id': newId(),
      'name': name,
      'normalized_name': _normalizeText(name),
      'aliases': aliases.join('|'),
      'normalized_aliases': aliases.map(_normalizeText).join('|'),
      'category': category,
      'carbs_g_per_100': carbsPer100,
      'protein_g_per_100': proteinPer100,
      'fat_g_per_100': fatPer100,
      'is_custom': 0,
      'created_at': now,
      'updated_at': now,
    };
  }

  Future<List<Food>> searchFoods(String query) async {
    final db = await database;
    final wildcard = '%$query%';
    final normalized = '%${_normalizeText(query)}%';
    final prefix = '$query%';
    final normalizedPrefix = '${_normalizeText(query)}%';
    final rows = await db.rawQuery(
      '''
      SELECT *
      FROM foods
      WHERE ? = ''
         OR name LIKE ?
         OR normalized_name LIKE ?
         OR aliases LIKE ?
         OR normalized_aliases LIKE ?
      ORDER BY
        CASE
          WHEN name = ? THEN 0
          WHEN name LIKE ? THEN 1
          WHEN aliases LIKE ? OR normalized_aliases LIKE ? THEN 2
          ELSE 3
        END,
        is_custom DESC,
        name COLLATE NOCASE ASC
      LIMIT 100
      ''',
      [
        query,
        wildcard,
        normalized,
        wildcard,
        normalized,
        query,
        prefix,
        prefix,
        normalizedPrefix,
      ],
    );
    return rows.map(_foodFromMap).toList();
  }

  Future<void> saveFood(Food food) async {
    final db = await database;
    final existing = await db.query(
      'foods',
      where: 'id = ?',
      whereArgs: [food.id],
    );
    final now = DateTime.now().toIso8601String();
    final data = {
      'id': food.id,
      'name': food.name,
      'normalized_name': _normalizeText(food.name),
      'aliases': food.aliases.join('|'),
      'normalized_aliases': food.aliases.map(_normalizeText).join('|'),
      'category': food.category,
      'carbs_g_per_100': food.carbsPer100,
      'protein_g_per_100': food.proteinPer100,
      'fat_g_per_100': food.fatPer100,
      'is_custom': food.isCustom ? 1 : 0,
      'created_at': existing.isEmpty ? now : existing.first['created_at'],
      'updated_at': now,
    };
    await db.insert(
      'foods',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCustomFood(String id) async {
    final db = await database;
    await db.delete(
      'foods',
      where: 'id = ? AND is_custom = 1',
      whereArgs: [id],
    );
  }

  Future<List<MealRecord>> listMealRecords() async {
    final db = await database;
    final mealRows = await db.query('meals', orderBy: 'eaten_at DESC');
    if (mealRows.isEmpty) {
      return const [];
    }
    final mealIds = mealRows.map((row) => row['id']! as String).toList();
    final placeholders = List.filled(mealIds.length, '?').join(',');
    final itemRows = await db.query(
      'meal_items',
      where: 'meal_id IN ($placeholders)',
      whereArgs: mealIds,
      orderBy: 'meal_id ASC, sort_order ASC, created_at ASC',
    );
    final itemsByMealId = <String, List<Map<String, Object?>>>{};
    for (final row in itemRows) {
      final mealId = row['meal_id']! as String;
      itemsByMealId
          .putIfAbsent(mealId, () => <Map<String, Object?>>[])
          .add(row);
    }
    final result = <MealRecord>[];
    for (final mealRow in mealRows) {
      final mealId = mealRow['id']! as String;
      result.add(_mealFromMaps(mealRow, itemsByMealId[mealId] ?? const []));
    }
    return result;
  }

  Future<void> saveMeal({
    required String? mealId,
    required MealType mealType,
    required String name,
    required DateTime eatenAt,
    required List<MealItem> items,
  }) async {
    final db = await database;
    final id = mealId ?? newId();
    final now = DateTime.now().toIso8601String();
    final totals = NutritionCalculator.sum(items.map((item) => item.nutrients));

    await db.transaction((txn) async {
      final existing = await txn.query(
        'meals',
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.insert('meals', {
        'id': id,
        'name': name,
        'meal_type': mealType.value,
        'eaten_at': eatenAt.toIso8601String(),
        'total_carbs_g': totals.carbs,
        'total_protein_g': totals.protein,
        'total_fat_g': totals.fat,
        'created_at': existing.isEmpty ? now : existing.first['created_at'],
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('meal_items', where: 'meal_id = ?', whereArgs: [id]);
      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        await txn.insert('meal_items', {
          'id': item.id,
          'meal_id': id,
          'food_id': item.foodId,
          'food_name_snapshot': item.foodNameSnapshot,
          'weight_g': item.weightG,
          'carbs_g_per_100': item.carbsPer100,
          'protein_g_per_100': item.proteinPer100,
          'fat_g_per_100': item.fatPer100,
          'carbs_g': item.carbsG,
          'protein_g': item.proteinG,
          'fat_g': item.fatG,
          'sort_order': index,
          'created_at': now,
        });
      }
    });
  }

  Future<void> deleteMeal(String id) async {
    final db = await database;
    await db.delete('meals', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<InsulinProfile>> listInsulinProfiles() async {
    final db = await database;
    final rows = await db.query('insulin_profiles', orderBy: 'updated_at DESC');
    return rows.map(_insulinProfileFromMap).toList();
  }

  Future<void> saveInsulinProfile(InsulinProfile profile) async {
    final db = await database;
    final existing = await db.query(
      'insulin_profiles',
      where: 'id = ?',
      whereArgs: [profile.id],
    );
    final now = DateTime.now().toIso8601String();
    await db.insert('insulin_profiles', {
      'id': profile.id,
      'name': profile.name,
      'carb_ratio': profile.carbRatio,
      'protein_fat_enabled': profile.proteinFatEnabled ? 1 : 0,
      'formula_type': profile.formulaType.value,
      'protein_coefficient': profile.proteinCoefficient,
      'fat_coefficient': profile.fatCoefficient,
      'total_daily_insulin': profile.totalDailyInsulin,
      'carb_rule': profile.carbRule,
      'protein_fat_base': profile.proteinFatBase,
      'correction_standard': profile.correctionStandard,
      'cir_formula': profile.cirFormula,
      'carb_insulin_formula': profile.carbInsulinFormula,
      'protein_fat_formula': profile.proteinFatFormula,
      'isf_formula': profile.isfFormula,
      'rounding_increment': profile.roundingIncrement,
      'enabled': profile.enabled ? 1 : 0,
      'created_at': existing.isEmpty ? now : existing.first['created_at'],
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteInsulinProfile(String id) async {
    final db = await database;
    await db.delete('insulin_profiles', where: 'id = ?', whereArgs: [id]);
  }

  Food _foodFromMap(Map<String, Object?> row) {
    return Food(
      id: row['id']! as String,
      name: row['name']! as String,
      aliases: _splitAliases(row['aliases']! as String),
      category: row['category']! as String,
      carbsPer100: (row['carbs_g_per_100']! as num).toDouble(),
      proteinPer100: (row['protein_g_per_100']! as num).toDouble(),
      fatPer100: (row['fat_g_per_100']! as num).toDouble(),
      isCustom: (row['is_custom']! as int) == 1,
    );
  }

  MealRecord _mealFromMaps(
    Map<String, Object?> mealRow,
    List<Map<String, Object?>> itemRows,
  ) {
    return MealRecord(
      id: mealRow['id']! as String,
      name: mealRow['name']! as String,
      mealType: mealTypeFromValue(mealRow['meal_type']! as String),
      eatenAt: DateTime.parse(mealRow['eaten_at']! as String),
      totalCarbs: (mealRow['total_carbs_g']! as num).toDouble(),
      totalProtein: (mealRow['total_protein_g']! as num).toDouble(),
      totalFat: (mealRow['total_fat_g']! as num).toDouble(),
      items: itemRows
          .map((row) => _mealItemFromMap(row))
          .toList(growable: false),
    );
  }

  MealItem _mealItemFromMap(Map<String, Object?> row) {
    return MealItem(
      id: row['id']! as String,
      mealId: row['meal_id']! as String,
      foodId: row['food_id'] as String?,
      foodNameSnapshot: row['food_name_snapshot']! as String,
      weightG: (row['weight_g']! as num).toDouble(),
      carbsPer100: (row['carbs_g_per_100']! as num).toDouble(),
      proteinPer100: (row['protein_g_per_100']! as num).toDouble(),
      fatPer100: (row['fat_g_per_100']! as num).toDouble(),
      carbsG: (row['carbs_g']! as num).toDouble(),
      proteinG: (row['protein_g']! as num).toDouble(),
      fatG: (row['fat_g']! as num).toDouble(),
      sortOrder: (row['sort_order']! as num).toInt(),
    );
  }

  InsulinProfile _insulinProfileFromMap(Map<String, Object?> row) {
    return InsulinProfile(
      id: row['id']! as String,
      name: row['name']! as String,
      carbRatio: (row['carb_ratio']! as num).toDouble(),
      totalDailyInsulin: (row['total_daily_insulin'] as num?)?.toDouble(),
      carbRule: (row['carb_rule'] as num?)?.toDouble(),
      proteinFatBase: (row['protein_fat_base'] as num?)?.toDouble(),
      correctionStandard: (row['correction_standard'] as num?)?.toDouble(),
      proteinFatEnabled: (row['protein_fat_enabled']! as int) == 1,
      formulaType: proteinFatFormulaTypeFromValue(
        row['formula_type']! as String,
      ),
      proteinCoefficient: (row['protein_coefficient'] as num?)?.toDouble(),
      fatCoefficient: (row['fat_coefficient'] as num?)?.toDouble(),
      cirFormula:
          (row['cir_formula'] as String?) ?? InsulinProfile.defaultCirFormula,
      carbInsulinFormula:
          (row['carb_insulin_formula'] as String?) ??
          InsulinProfile.defaultCarbInsulinFormula,
      proteinFatFormula:
          (row['protein_fat_formula'] as String?) ??
          InsulinProfile.defaultProteinFatMassFormula,
      isfFormula:
          (row['isf_formula'] as String?) ?? InsulinProfile.defaultIsfFormula,
      roundingIncrement: (row['rounding_increment']! as num).toDouble(),
      enabled: (row['enabled']! as int) == 1,
    );
  }

  List<String> _splitAliases(String value) {
    if (value.trim().isEmpty) {
      return const [];
    }
    return value
        .split('|')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static String _normalizeText(String input) {
    return input.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }

  static String _normalizeAliases(String aliases) {
    return aliases
        .split('|')
        .map(_normalizeText)
        .where((alias) => alias.isNotEmpty)
        .join('|');
  }

  static String _migratedProteinFatFormula({
    required String formulaType,
  }) {
    switch (formulaType) {
      case '直接加权':
        return 'protein * protein_coefficient + fat * fat_coefficient';
      case '等效碳水':
        return '((protein * protein_coefficient) + (fat * fat_coefficient)) / carb_ratio';
      case '合计克数':
        return '(protein + fat) / protein_coefficient';
      default:
        return InsulinProfile.defaultProteinFatMassFormula;
    }
  }

  static String newId() {
    return '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
  }
}
