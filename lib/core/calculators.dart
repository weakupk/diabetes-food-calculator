import 'models.dart';

class NutritionCalculator {
  const NutritionCalculator._();

  static Nutrients calculate({
    required double weightG,
    required double carbsPer100,
    required double proteinPer100,
    required double fatPer100,
  }) {
    if (weightG <= 0) {
      throw ArgumentError.value(weightG, 'weightG', '重量必须大于 0 克');
    }
    if (carbsPer100 < 0 || proteinPer100 < 0 || fatPer100 < 0) {
      throw ArgumentError('每100克营养值不能为负数');
    }

    final factor = weightG / 100;
    return Nutrients(
      carbs: carbsPer100 * factor,
      protein: proteinPer100 * factor,
      fat: fatPer100 * factor,
    );
  }

  static Nutrients sum(Iterable<Nutrients> items) {
    return items.fold(Nutrients.zero, (sum, item) => sum + item);
  }
}

class InsulinCalculator {
  const InsulinCalculator._();

  static const supportedRoundingIncrements = {0.0, 0.5, 1.0};

  static void validateProfile(InsulinProfile profile) {
    if (profile.carbRatio <= 0) {
      throw ArgumentError.value(
        profile.carbRatio,
        'carbRatio',
        '碳水系数必须大于 0',
      );
    }
    if (!supportedRoundingIncrements.contains(profile.roundingIncrement)) {
      throw ArgumentError.value(
        profile.roundingIncrement,
        'roundingIncrement',
        '舍入模式仅支持 0、0.5 或 1 U',
      );
    }
    if (!profile.proteinFatEnabled) {
      return;
    }

    switch (profile.formulaType) {
      case ProteinFatFormulaType.directWeighted:
        final proteinCoefficient = profile.proteinCoefficient ?? 0;
        final fatCoefficient = profile.fatCoefficient ?? 0;
        if (proteinCoefficient < 0 || fatCoefficient < 0) {
          throw ArgumentError.value(
            'protein=$proteinCoefficient,fat=$fatCoefficient',
            'directWeightedCoefficients',
            '直接加权系数不能为负数',
          );
        }
        if (proteinCoefficient == 0 && fatCoefficient == 0) {
          throw ArgumentError.value(
            'protein=$proteinCoefficient,fat=$fatCoefficient',
            'directWeightedCoefficients',
            '至少需要一个蛋白质/脂肪系数',
          );
        }
      case ProteinFatFormulaType.equivalentCarbs:
        final proteinCoefficient = profile.proteinCoefficient ?? 0;
        final fatCoefficient = profile.fatCoefficient ?? 0;
        if (proteinCoefficient < 0 || fatCoefficient < 0) {
          throw ArgumentError.value(
            'protein=$proteinCoefficient,fat=$fatCoefficient',
            'equivalentCarbCoefficients',
            '等效碳水系数不能为负数',
          );
        }
        if (proteinCoefficient == 0 && fatCoefficient == 0) {
          throw ArgumentError.value(
            'protein=$proteinCoefficient,fat=$fatCoefficient',
            'equivalentCarbCoefficients',
            '至少需要一个蛋白质/脂肪换算系数',
          );
        }
      case ProteinFatFormulaType.totalGrams:
        final ratio = profile.proteinCoefficient ?? 0;
        if (ratio <= 0) {
          throw ArgumentError.value(
            ratio,
            'proteinFatRatio',
            '蛋白质脂肪系数必须大于 0',
          );
        }
    }
  }

  static InsulinCalculationResult calculate({
    required Nutrients nutrients,
    required InsulinProfile profile,
  }) {
    validateProfile(profile);

    final carbUnits = nutrients.carbs / profile.carbRatio;
    double proteinFatUnits = 0;
    final explanation = <String>[
      '碳水部分 = ${_fmt(nutrients.carbs)} ÷ ${_fmt(profile.carbRatio)} = ${_fmt(carbUnits)} U',
    ];

    if (profile.proteinFatEnabled) {
      switch (profile.formulaType) {
        case ProteinFatFormulaType.directWeighted:
          final proteinCoefficient = profile.proteinCoefficient ?? 0;
          final fatCoefficient = profile.fatCoefficient ?? 0;
          proteinFatUnits =
              (nutrients.protein * proteinCoefficient) +
              (nutrients.fat * fatCoefficient);
          explanation.add(
            '蛋白质/脂肪部分 = ${_fmt(nutrients.protein)} × ${_fmt(proteinCoefficient)} + '
            '${_fmt(nutrients.fat)} × ${_fmt(fatCoefficient)} = ${_fmt(proteinFatUnits)} U',
          );
        case ProteinFatFormulaType.equivalentCarbs:
          final proteinCoefficient = profile.proteinCoefficient ?? 0;
          final fatCoefficient = profile.fatCoefficient ?? 0;
          final equivalentCarbs =
              (nutrients.protein * proteinCoefficient) +
              (nutrients.fat * fatCoefficient);
          proteinFatUnits = equivalentCarbs / profile.carbRatio;
          explanation.add(
            '蛋白质/脂肪等效碳水 = ${_fmt(nutrients.protein)} × ${_fmt(proteinCoefficient)} + '
            '${_fmt(nutrients.fat)} × ${_fmt(fatCoefficient)} = ${_fmt(equivalentCarbs)} g',
          );
          explanation.add(
            '蛋白质/脂肪部分 = ${_fmt(equivalentCarbs)} ÷ ${_fmt(profile.carbRatio)} = ${_fmt(proteinFatUnits)} U',
          );
        case ProteinFatFormulaType.totalGrams:
          final ratio = profile.proteinCoefficient ?? 0;
          final grams = nutrients.protein + nutrients.fat;
          proteinFatUnits = grams / ratio;
          explanation.add(
            '蛋白质/脂肪部分 = (${_fmt(nutrients.protein)} + ${_fmt(nutrients.fat)}) ÷ ${_fmt(ratio)} '
            '= ${_fmt(proteinFatUnits)} U',
          );
      }
    } else {
      explanation.add('蛋白质/脂肪部分已关闭');
    }

    final totalUnits = carbUnits + proteinFatUnits;
    final roundedTotalUnits = roundToIncrement(
      totalUnits,
      profile.roundingIncrement,
    );
    explanation.add(
      '合计 = ${_fmt(carbUnits)} + ${_fmt(proteinFatUnits)} = ${_fmt(totalUnits)} U',
    );
    if (profile.roundingIncrement == 0) {
      explanation.add('舍入模式：不舍入，结果保持 ${_fmt(roundedTotalUnits)} U');
    } else {
      explanation.add(
        '按 ${_fmt(profile.roundingIncrement)} U 舍入后 = ${_fmt(roundedTotalUnits)} U',
      );
    }

    return InsulinCalculationResult(
      carbUnits: carbUnits,
      proteinFatUnits: proteinFatUnits,
      totalUnits: totalUnits,
      roundedTotalUnits: roundedTotalUnits,
      explanation: explanation,
    );
  }

  static double roundToIncrement(double value, double increment) {
    if (!supportedRoundingIncrements.contains(increment)) {
      throw ArgumentError.value(increment, 'increment', '舍入模式仅支持 0、0.5 或 1 U');
    }
    if (increment == 0) {
      return value;
    }
    return (value / increment).round() * increment;
  }

  static String _fmt(double value) {
    final rounded = value.toStringAsFixed(2);
    return rounded
        .replaceFirst(RegExp(r'\.00$'), '')
        .replaceFirst(RegExp(r'(\.\d)0$'), r'$1');
  }
}
