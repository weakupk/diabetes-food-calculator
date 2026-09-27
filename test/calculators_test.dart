import 'package:diabetes_food_calculator/core/calculators.dart';
import 'package:diabetes_food_calculator/core/formatters.dart';
import 'package:diabetes_food_calculator/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatNumber', () {
    test('keeps decimal points instead of replacing them with dollar signs', () {
      expect(formatNumber(25.1), '25.1');
      expect(formatNumber(2.1), '2.1');
      expect(formatNumber(25.12), '25.12');
    });
  });

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

    test('mass-based formula should split carb and protein/fat insulin', () {
      const profile = InsulinProfile(
        id: '1',
        name: 'mass',
        carbRatio: 0.08,
        totalDailyInsulin: 40,
        carbRule: 500,
        proteinFatBase: 10,
        correctionStandard: 180,
        proteinFatEnabled: true,
        formulaType: ProteinFatFormulaType.massBased,
        proteinCoefficient: null,
        fatCoefficient: null,
        cirFormula: 'total_daily_insulin / carb_rule',
        carbInsulinFormula: 'carbs / cir',
        proteinFatFormula: '(protein + fat) / 2 / protein_fat_base',
        isfFormula: 'correction_standard / total_daily_insulin / 18',
        roundingIncrement: 0.5,
        enabled: true,
      );

      final result = InsulinCalculator.calculate(
        nutrients: nutrients,
        profile: profile,
      );

      expect(result.carbUnits, closeTo(583.125, 0.001));
      expect(result.proteinFatUnits, closeTo(1.9175, 0.001));
      expect(result.roundedTotalUnits, closeTo(585, 0.001));
      expect(result.explanation.first, contains('CIR = 40 ÷ 500 = 0.08'));
    });

    test('fpu formula should work and keep explanation note', () {
      const profile = InsulinProfile(
        id: '2',
        name: 'fpu',
        carbRatio: 0.08,
        totalDailyInsulin: 40,
        carbRule: 500,
        proteinFatBase: null,
        correctionStandard: 180,
        proteinFatEnabled: true,
        formulaType: ProteinFatFormulaType.fpu,
        proteinCoefficient: null,
        fatCoefficient: null,
        cirFormula: 'total_daily_insulin / carb_rule',
        carbInsulinFormula: 'carbs / cir',
        proteinFatFormula: '((protein * 4) + (fat * 9)) / 100',
        isfFormula: 'correction_standard / total_daily_insulin / 18',
        roundingIncrement: 0.5,
        enabled: true,
      );

      final result = InsulinCalculator.calculate(
        nutrients: nutrients,
        profile: profile,
      );

      expect(
        result.proteinFatUnits,
        closeTo(((35.22 * 4) + (3.13 * 9)) / 100, 0.001),
      );
      expect(result.explanation, contains('100千卡=1U=1FPU'));
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
        carbRatio: 0.08,
        totalDailyInsulin: 40,
        carbRule: 500,
        proteinFatBase: 10,
        correctionStandard: 180,
        proteinFatEnabled: true,
        formulaType: ProteinFatFormulaType.massBased,
        proteinCoefficient: null,
        fatCoefficient: null,
        cirFormula: 'total_daily_insulin / carb_rule',
        carbInsulinFormula: 'carbs / cir',
        proteinFatFormula: '(protein + fat) / 2 / protein_fat_base',
        isfFormula: 'correction_standard / total_daily_insulin / 18',
        roundingIncrement: 0,
        enabled: true,
      );

      final result = InsulinCalculator.calculate(
        nutrients: nutrients,
        profile: profile,
      );

      expect(result.roundedTotalUnits, closeTo(result.totalUnits, 0.0001));
      expect(result.explanation.last, contains('舍入模式：不舍入'));
    });

    test('invalid formulas should throw readable argument errors', () {
      const invalidDivision = InsulinProfile(
        id: 'invalid-division',
        name: 'invalid division',
        carbRatio: 1,
        totalDailyInsulin: 40,
        carbRule: 0,
        proteinFatBase: 10,
        correctionStandard: 180,
        proteinFatEnabled: false,
        formulaType: ProteinFatFormulaType.massBased,
        proteinCoefficient: null,
        fatCoefficient: null,
        cirFormula: 'total_daily_insulin / carb_rule',
        carbInsulinFormula: 'carbs / cir',
        proteinFatFormula: '(protein + fat) / 2 / protein_fat_base',
        isfFormula: 'correction_standard / total_daily_insulin / 18',
        roundingIncrement: 0.5,
        enabled: true,
      );

      expect(
        () => InsulinCalculator.calculate(
          nutrients: nutrients,
          profile: invalidDivision,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message.toString(),
            'message',
            contains('除数不能为 0'),
          ),
        ),
      );

      const invalidRounding = InsulinProfile(
        id: 'invalid-rounding',
        name: 'invalid rounding',
        carbRatio: 1,
        totalDailyInsulin: 40,
        carbRule: 500,
        proteinFatBase: 10,
        correctionStandard: 180,
        proteinFatEnabled: false,
        formulaType: ProteinFatFormulaType.massBased,
        proteinCoefficient: null,
        fatCoefficient: null,
        cirFormula: 'total_daily_insulin / carb_rule',
        carbInsulinFormula: 'carbs / cir',
        proteinFatFormula: '(protein + fat) / 2 / protein_fat_base',
        isfFormula: 'correction_standard / total_daily_insulin / 18',
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
