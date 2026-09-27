import 'formula_engine.dart';
import 'formatters.dart';
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

  static final Set<double> supportedRoundingIncrements = {0.0, 0.5, 1.0};

  static void validateProfile(InsulinProfile profile) {
    if (!supportedRoundingIncrements.contains(profile.roundingIncrement)) {
      throw ArgumentError.value(
        profile.roundingIncrement,
        'roundingIncrement',
        '舍入模式仅支持 0、0.5 或 1 U',
      );
    }
    final baseVariables = _baseVariables(profile)
      ..addAll({'carbs': 1, 'protein': 1, 'fat': 1});
    final cir = _evaluateFormula(
      formula: profile.cirFormula,
      variables: baseVariables,
      fieldName: 'cirFormula',
      label: 'CIR 公式',
    );
    if (cir <= 0) {
      throw ArgumentError.value(cir, 'cirFormula', 'CIR 计算结果必须大于 0');
    }
    baseVariables['cir'] = cir;
    baseVariables['carb_ratio'] = cir;

    _evaluateFormula(
      formula: profile.carbInsulinFormula,
      variables: baseVariables,
      fieldName: 'carbInsulinFormula',
      label: '碳水胰岛素公式',
    );

    if (profile.proteinFatEnabled) {
      _evaluateFormula(
        formula: profile.proteinFatFormula,
        variables: baseVariables,
        fieldName: 'proteinFatFormula',
        label: '蛋白质/脂肪公式',
      );
    }

    final isf = _evaluateFormula(
      formula: profile.isfFormula,
      variables: baseVariables,
      fieldName: 'isfFormula',
      label: 'ISF 公式',
    );
    if (isf <= 0) {
      throw ArgumentError.value(isf, 'isfFormula', 'ISF 计算结果必须大于 0');
    }
  }

  static InsulinCalculationResult calculate({
    required Nutrients nutrients,
    required InsulinProfile profile,
  }) {
    validateProfile(profile);

    final variables = _baseVariables(profile)
      ..addAll({
        'carbs': nutrients.carbs,
        'protein': nutrients.protein,
        'fat': nutrients.fat,
      });
    final cir = _evaluateFormula(
      formula: profile.cirFormula,
      variables: variables,
      fieldName: 'cirFormula',
      label: 'CIR 公式',
    );
    variables['cir'] = cir;
    variables['carb_ratio'] = cir;
    final carbUnits = _evaluateFormula(
      formula: profile.carbInsulinFormula,
      variables: variables,
      fieldName: 'carbInsulinFormula',
      label: '碳水胰岛素公式',
    );
    double proteinFatUnits = 0;
    final explanation = <String>[
      'CIR = ${FormulaEvaluator.explain(profile.cirFormula, variables, formatter: _fmt)} = ${_fmt(cir)} g/U',
      '碳水部分 = ${FormulaEvaluator.explain(profile.carbInsulinFormula, variables, formatter: _fmt)} = ${_fmt(carbUnits)} U',
    ];

    if (profile.proteinFatEnabled) {
      proteinFatUnits = _evaluateFormula(
        formula: profile.proteinFatFormula,
        variables: variables,
        fieldName: 'proteinFatFormula',
        label: '蛋白质/脂肪公式',
      );
      explanation.add(
        '${_proteinFatLabel(profile.formulaType)} = ${FormulaEvaluator.explain(profile.proteinFatFormula, variables, formatter: _fmt)} = ${_fmt(proteinFatUnits)} U',
      );
      if (profile.formulaType == ProteinFatFormulaType.fpu) {
        explanation.add('100千卡=1U=1FPU');
      }
    } else {
      explanation.add('蛋白质/脂肪部分已关闭');
    }

    final isf = _evaluateFormula(
      formula: profile.isfFormula,
      variables: variables,
      fieldName: 'isfFormula',
      label: 'ISF 公式',
    );
    explanation.add(
      'ISF = ${FormulaEvaluator.explain(profile.isfFormula, variables, formatter: _fmt)} = ${_fmt(isf)}',
    );

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
    return formatNumber(value);
  }

  static String _proteinFatLabel(ProteinFatFormulaType type) {
    switch (type) {
      case ProteinFatFormulaType.massBased:
        return '蛋白质/脂肪部分（质量法）';
      case ProteinFatFormulaType.fpu:
        return '蛋白质/脂肪部分（FPU法）';
      case ProteinFatFormulaType.custom:
        return '蛋白质/脂肪部分（自定义）';
    }
  }

  static Map<String, double> _baseVariables(InsulinProfile profile) {
    return {
      'carb_ratio': profile.carbRatio,
      if (profile.totalDailyInsulin != null)
        'total_daily_insulin': profile.totalDailyInsulin!,
      if (profile.carbRule != null) 'carb_rule': profile.carbRule!,
      if (profile.proteinFatBase != null)
        'protein_fat_base': profile.proteinFatBase!,
      if (profile.correctionStandard != null)
        'correction_standard': profile.correctionStandard!,
      if (profile.proteinCoefficient != null)
        'protein_coefficient': profile.proteinCoefficient!,
      if (profile.fatCoefficient != null) 'fat_coefficient': profile.fatCoefficient!,
    };
  }

  static double _evaluateFormula({
    required String formula,
    required Map<String, double> variables,
    required String fieldName,
    required String label,
  }) {
    try {
      return FormulaEvaluator.evaluate(formula, variables);
    } on FormulaEvaluationException catch (error) {
      throw ArgumentError.value(formula, fieldName, '$label：${error.message}');
    }
  }
}
