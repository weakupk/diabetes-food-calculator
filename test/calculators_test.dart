import 'package:diabetes_food_calculator/core/calculators.dart';
import 'package:diabetes_food_calculator/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NutritionCalculator', () {
    test('150g rice should calculate all three nutrients', () {
      final result = NutritionCalculator.calculate(
        weightG: 150,
        carbsPer100: 25.9,
        proteinPer100: 2.6,
        fatPer100: 0.3,
      );

      expect(result.carbs, closeTo(38.85, 0.001));
      expect(result.protein, closeTo(3.9, 0.001));
      expect(result.fat, closeTo(0.45, 0.001));
    });

    test('sum should aggregate multiple foods', () {
      final total = NutritionCalculator.sum([
        const Nutrients(carbs: 38.85, protein: 3.9, fat: 0.45),
        const Nutrients(carbs: 7.8, protein: 1.8, fat: 0.4),
        const Nutrients(carbs: 0, protein: 29.52, fat: 2.28),
      ]);

      expect(total.carbs, closeTo(46.65, 0.001));
      expect(total.protein, closeTo(35.22, 0.001));
      expect(total.fat, closeTo(3.13, 0.001));
    });

    test('invalid weight should throw', () {
      expect(
        () => NutritionCalculator.calculate(
          weightG: 0,
          carbsPer100: 1,
          proteinPer100: 1,
          fatPer100: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => NutritionCalculator.calculate(
          weightG: -10,
          carbsPer100: 1,
          proteinPer100: 1,
          fatPer100: 1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('InsulinCalculator', () {
    const nutrients = Nutrients(carbs: 46.65, protein: 35.22, fat: 3.13);

    test(
      'direct weighted formula should split carb and protein/fat insulin',
      () {
        const profile = InsulinProfile(
          id: '1',
          name: 'direct',
          carbRatio: 10,
          proteinFatEnabled: true,
          formulaType: ProteinFatFormulaType.directWeighted,
          proteinCoefficient: 0.1,
          fatCoefficient: 0.05,
          roundingIncrement: 0.5,
          enabled: true,
        );

        final result = InsulinCalculator.calculate(
          nutrients: nutrients,
          profile: profile,
        );

        expect(result.carbUnits, closeTo(4.665, 0.001));
        expect(result.proteinFatUnits, closeTo(3.6785, 0.001));
        expect(result.roundedTotalUnits, closeTo(8.5, 0.001));
      },
    );

    test('equivalent carbs formula should work', () {
      const profile = InsulinProfile(
        id: '2',
        name: 'equivalent',
        carbRatio: 12,
        proteinFatEnabled: true,
        formulaType: ProteinFatFormulaType.equivalentCarbs,
        proteinCoefficient: 0.5,
        fatCoefficient: 0.2,
        roundingIncrement: 0.5,
        enabled: true,
      );

      final result = InsulinCalculator.calculate(
        nutrients: nutrients,
        profile: profile,
      );

      expect(result.carbUnits, closeTo(3.8875, 0.001));
      expect(result.proteinFatUnits, closeTo(1.519333, 0.001));
      expect(result.roundedTotalUnits, closeTo(5.5, 0.001));
    });

    test('total grams formula should work', () {
      const profile = InsulinProfile(
        id: '3',
        name: 'grams',
        carbRatio: 10,
        proteinFatEnabled: true,
        formulaType: ProteinFatFormulaType.totalGrams,
        proteinCoefficient: 20,
        fatCoefficient: null,
        roundingIncrement: 1,
        enabled: true,
      );

      final result = InsulinCalculator.calculate(
        nutrients: nutrients,
        profile: profile,
      );

      expect(result.proteinFatUnits, closeTo((35.22 + 3.13) / 20, 0.001));
      expect(result.roundedTotalUnits, equals(7));
    });

    test('rounding increment should round to nearest step', () {
      expect(InsulinCalculator.roundToIncrement(6, 0), 6);
      expect(InsulinCalculator.roundToIncrement(5.26, 0), 5.26);
      expect(InsulinCalculator.roundToIncrement(-1.25, 0), -1.25);
      expect(InsulinCalculator.roundToIncrement(5.24, 0.5), 5.0);
      expect(InsulinCalculator.roundToIncrement(5.26, 0.5), 5.5);
      expect(InsulinCalculator.roundToIncrement(5.6, 1), 6.0);
    });

    test('no rounding mode should keep raw total units', () {
      const profile = InsulinProfile(
        id: 'no-rounding',
        name: 'no rounding',
        carbRatio: 10,
        proteinFatEnabled: true,
        formulaType: ProteinFatFormulaType.directWeighted,
        proteinCoefficient: 0.1,
        fatCoefficient: 0.05,
        roundingIncrement: 0,
        enabled: true,
      );

      final result = InsulinCalculator.calculate(
        nutrients: nutrients,
        profile: profile,
      );

      expect(result.roundedTotalUnits, closeTo(result.totalUnits, 0.0001));
      expect(
        result.explanation.last,
        contains('舍入模式：不舍入'),
      );
    });

    test('invalid coefficients should throw', () {
      const invalidCarbRatio = InsulinProfile(
        id: '4',
        name: 'invalid carb',
        carbRatio: 0,
        proteinFatEnabled: false,
        formulaType: ProteinFatFormulaType.directWeighted,
        proteinCoefficient: null,
        fatCoefficient: null,
        roundingIncrement: 0.5,
        enabled: true,
      );
      expect(
        () => InsulinCalculator.calculate(
          nutrients: nutrients,
          profile: invalidCarbRatio,
        ),
        throwsArgumentError,
      );

      const invalidPfRatio = InsulinProfile(
        id: '5',
        name: 'invalid pf',
        carbRatio: 10,
        proteinFatEnabled: true,
        formulaType: ProteinFatFormulaType.totalGrams,
        proteinCoefficient: 0,
        fatCoefficient: null,
        roundingIncrement: 0.5,
        enabled: true,
      );
      expect(
        () => InsulinCalculator.calculate(
          nutrients: nutrients,
          profile: invalidPfRatio,
        ),
        throwsArgumentError,
      );

      const invalidRounding = InsulinProfile(
        id: '6',
        name: 'invalid rounding',
        carbRatio: 10,
        proteinFatEnabled: false,
        formulaType: ProteinFatFormulaType.directWeighted,
        proteinCoefficient: null,
        fatCoefficient: null,
        roundingIncrement: -0.5,
        enabled: true,
      );
      expect(
        () => InsulinCalculator.calculate(
          nutrients: nutrients,
          profile: invalidRounding,
        ),
        throwsArgumentError,
      );
      expect(
        () => InsulinCalculator.roundToIncrement(5.2, 0.3),
        throwsArgumentError,
      );
    });
  });
}
