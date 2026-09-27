import 'dart:io';

import 'package:diabetes_food_calculator/core/calculators.dart';
import 'package:diabetes_food_calculator/core/models.dart';
import 'package:diabetes_food_calculator/data/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('meal history keeps food snapshot after food library changes', () async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    await database.ensureReady();

    const food = Food(
      id: 'custom-food',
      name: '自制面包',
      aliases: ['面包'],
      category: '主食',
      carbsPer100: 40,
      proteinPer100: 8,
      fatPer100: 2,
      isCustom: true,
    );
    await database.saveFood(food);

    final nutrients = NutritionCalculator.calculate(
      weightG: 150,
      carbsPer100: food.carbsPer100,
      proteinPer100: food.proteinPer100,
      fatPer100: food.fatPer100,
    );
    await database.saveMeal(
      mealId: 'meal-1',
      mealType: MealType.breakfast,
      name: '早餐',
      eatenAt: DateTime(2026, 1, 2, 8, 0),
      items: [
        MealItem(
          id: 'item-1',
          mealId: 'meal-1',
          foodId: food.id,
          foodNameSnapshot: food.name,
          weightG: 150,
          carbsPer100: food.carbsPer100,
          proteinPer100: food.proteinPer100,
          fatPer100: food.fatPer100,
          carbsG: nutrients.carbs,
          proteinG: nutrients.protein,
          fatG: nutrients.fat,
          sortOrder: 0,
        ),
      ],
    );

    await database.saveFood(
      const Food(
        id: 'custom-food',
        name: '自制面包',
        aliases: ['面包'],
        category: '主食',
        carbsPer100: 60,
        proteinPer100: 10,
        fatPer100: 5,
        isCustom: true,
      ),
    );

    final meals = await database.listMealRecords();
    final storedItem = meals.single.items.single;

    expect(storedItem.foodNameSnapshot, '自制面包');
    expect(storedItem.carbsPer100, 40);
    expect(storedItem.proteinPer100, 8);
    expect(storedItem.fatPer100, 2);
    expect(storedItem.carbsG, closeTo(60, 0.001));
    expect(storedItem.proteinG, closeTo(12, 0.001));
    expect(storedItem.fatG, closeTo(3, 0.001));

    await database.close();
  });

  test('reopened meal preserves item order after saving again', () async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    await database.ensureReady();

    await database.saveMeal(
      mealId: 'meal-2',
      mealType: MealType.lunch,
      name: '午餐',
      eatenAt: DateTime(2026, 1, 2, 12, 0),
      items: const [
        MealItem(
          id: 'item-rice',
          mealId: 'meal-2',
          foodId: 'rice',
          foodNameSnapshot: '米饭',
          weightG: 150,
          carbsPer100: 25.9,
          proteinPer100: 2.6,
          fatPer100: 0.3,
          carbsG: 38.85,
          proteinG: 3.9,
          fatG: 0.45,
          sortOrder: 0,
        ),
        MealItem(
          id: 'item-tomato',
          mealId: 'meal-2',
          foodId: 'tomato',
          foodNameSnapshot: '西红柿',
          weightG: 200,
          carbsPer100: 3.9,
          proteinPer100: 0.9,
          fatPer100: 0.2,
          carbsG: 7.8,
          proteinG: 1.8,
          fatG: 0.4,
          sortOrder: 1,
        ),
        MealItem(
          id: 'item-chicken',
          mealId: 'meal-2',
          foodId: 'chicken',
          foodNameSnapshot: '鸡胸肉',
          weightG: 120,
          carbsPer100: 0,
          proteinPer100: 24.6,
          fatPer100: 1.9,
          carbsG: 0,
          proteinG: 29.52,
          fatG: 2.28,
          sortOrder: 2,
        ),
      ],
    );

    final reopenedMeal = (await database.listMealRecords()).firstWhere(
      (meal) => meal.id == 'meal-2',
    );

    await database.saveMeal(
      mealId: reopenedMeal.id,
      mealType: reopenedMeal.mealType,
      name: reopenedMeal.name,
      eatenAt: reopenedMeal.eatenAt,
      items: reopenedMeal.items,
    );

    final savedAgain = (await database.listMealRecords()).firstWhere(
      (meal) => meal.id == 'meal-2',
    );

    expect(savedAgain.items.map((item) => item.foodNameSnapshot).toList(), [
      '米饭',
      '西红柿',
      '鸡胸肉',
    ]);

    await database.close();
  });

  test(
    'food search matches aliases even when whitespace is inserted',
    () async {
      final database = AppDatabase(databasePath: inMemoryDatabasePath);
      await database.ensureReady();

      final foods = await database.searchFoods('白 米 饭');

      expect(foods.any((food) => food.name == '米饭'), isTrue);

      await database.close();
    },
  );

  test(
    'database migration populates normalized aliases for legacy rows',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'dfc-migration-test',
      );
      final dbPath = p.join(tempDir.path, 'legacy.db');

      final legacyDb = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
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
            created_at TEXT NOT NULL
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
         await db.insert('insulin_profiles', {
           'id': 'legacy-profile',
           'name': '旧方案',
           'carb_ratio': 12.0,
           'protein_fat_enabled': 1,
           'formula_type': '合计克数',
           'protein_coefficient': 8.0,
           'fat_coefficient': null,
           'rounding_increment': 0.5,
           'enabled': 1,
           'created_at': '2026-01-01T00:00:00.000',
           'updated_at': '2026-01-01T00:00:00.000',
         });
         await db.insert('foods', {
           'id': 'legacy-rice',
           'name': '米饭',
           'normalized_name': '米饭',
            'aliases': '白米饭|熟米饭',
            'category': '谷薯类',
            'carbs_g_per_100': 25.9,
            'protein_g_per_100': 2.6,
            'fat_g_per_100': 0.3,
            'is_custom': 0,
            'created_at': '2026-01-01T00:00:00.000',
            'updated_at': '2026-01-01T00:00:00.000',
          });
        },
      );
      await legacyDb.close();

      final database = AppDatabase(databasePath: dbPath);
      await database.ensureReady();

      final foods = await database.searchFoods('白 米 饭');
      final profiles = await database.listInsulinProfiles();

      expect(foods.any((food) => food.id == 'legacy-rice'), isTrue);
      expect(profiles.single.totalDailyInsulin, 12);
      expect(profiles.single.carbRule, 1);
      expect(profiles.single.proteinFatBase, 4);
      expect(profiles.single.proteinFatFormula, '(protein + fat) / protein_coefficient');
      expect(profiles.single.cirFormula, InsulinProfile.defaultCirFormula);
      expect(profiles.single.isfFormula, InsulinProfile.defaultIsfFormula);

      await database.close();
      await tempDir.delete(recursive: true);
    },
  );

  test('sample foods are only initialized once for the same database', () async {
    final tempDir = await Directory.systemTemp.createTemp('dfc-seed-test');
    final dbPath = p.join(tempDir.path, 'seed.db');

    final firstDatabase = AppDatabase(databasePath: dbPath);
    await firstDatabase.ensureReady();
    final firstFoods = await firstDatabase.searchFoods('');
    await firstDatabase.close();

    final reopenedDatabase = AppDatabase(databasePath: dbPath);
    await reopenedDatabase.ensureReady();
    final reopenedFoods = await reopenedDatabase.searchFoods('');

    expect(firstFoods.length, 1);
    expect(firstFoods.map((food) => food.name).toSet(), {'米饭'});
    expect(reopenedFoods.length, firstFoods.length);
    expect(
      reopenedFoods.map((food) => food.name).toSet(),
      firstFoods.map((food) => food.name).toSet(),
    );

    await reopenedDatabase.close();
    await tempDir.delete(recursive: true);
  });

  test('concurrent ensureReady does not duplicate sample foods', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'dfc-concurrent-seed-test',
    );
    final dbPath = p.join(tempDir.path, 'seed.db');
    final database = AppDatabase(databasePath: dbPath);

    await Future.wait([database.ensureReady(), database.ensureReady()]);
    final foods = await database.searchFoods('');

    expect(foods.length, 1);
    expect(foods.map((food) => food.name).toSet(), {'米饭'});

    await database.close();
    await tempDir.delete(recursive: true);
  });
}
