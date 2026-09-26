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
  static const _databaseVersion = 1;

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
      onCreate: (db, version) async {
        await _createSchema(db);
        await _seedSampleFoods(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 1) {
          await _createSchema(db);
          await _seedSampleFoods(db);
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
      _sampleFood(
        name: '鸡胸肉',
        aliases: ['鸡脯肉'],
        category: '肉蛋类',
        carbsPer100: 0,
        proteinPer100: 24.6,
        fatPer100: 1.9,
        now: now,
      ),
      _sampleFood(
        name: '西红柿',
        aliases: ['番茄'],
        category: '蔬菜类',
        carbsPer100: 3.9,
        proteinPer100: 0.9,
        fatPer100: 0.2,
        now: now,
      ),
      _sampleFood(
        name: '鸡蛋',
        aliases: ['全蛋'],
        category: '肉蛋类',
        carbsPer100: 1.1,
        proteinPer100: 13.3,
        fatPer100: 8.8,
        now: now,
      ),
      _sampleFood(
        name: '苹果',
        aliases: ['红富士'],
        category: '水果类',
        carbsPer100: 13.7,
        proteinPer100: 0.3,
        fatPer100: 0.2,
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
    final rows = await db.rawQuery(
      '''
      SELECT *
      FROM foods
      WHERE ? = ''
         OR name LIKE ?
         OR normalized_name LIKE ?
         OR aliases LIKE ?
      ORDER BY
        CASE
          WHEN name = ? THEN 0
          WHEN name LIKE ? THEN 1
          WHEN aliases LIKE ? THEN 2
          ELSE 3
        END,
        is_custom DESC,
        name COLLATE NOCASE ASC
      LIMIT 100
      ''',
      [query, wildcard, normalized, wildcard, query, '$query%', '$query%'],
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
    final result = <MealRecord>[];
    for (final mealRow in mealRows) {
      final itemRows = await db.query(
        'meal_items',
        where: 'meal_id = ?',
        whereArgs: [mealRow['id']],
        orderBy: 'sort_order ASC, created_at ASC',
      );
      result.add(_mealFromMaps(mealRow, itemRows));
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
    await db.transaction((txn) async {
      await txn.delete('meal_items', where: 'meal_id = ?', whereArgs: [id]);
      await txn.delete('meals', where: 'id = ?', whereArgs: [id]);
    });
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
      proteinFatEnabled: (row['protein_fat_enabled']! as int) == 1,
      formulaType: proteinFatFormulaTypeFromValue(
        row['formula_type']! as String,
      ),
      proteinCoefficient: (row['protein_coefficient'] as num?)?.toDouble(),
      fatCoefficient: (row['fat_coefficient'] as num?)?.toDouble(),
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

  static String newId() {
    return '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
  }
}
