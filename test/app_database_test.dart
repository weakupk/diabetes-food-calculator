import 'package:diabetes_food_calculator/core/calculators.dart';
import 'package:diabetes_food_calculator/core/models.dart';
import 'package:diabetes_food_calculator/data/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
