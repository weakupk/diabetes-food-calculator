import 'package:flutter/foundation.dart';

enum MealType { breakfast, lunch, dinner, snack, custom }

enum ProteinFatFormulaType { directWeighted, equivalentCarbs, totalGrams }

MealType mealTypeFromValue(String value) {
  return MealType.values.firstWhere(
    (type) => type.value == value,
    orElse: () => MealType.custom,
  );
}

ProteinFatFormulaType proteinFatFormulaTypeFromValue(String value) {
  return ProteinFatFormulaType.values.firstWhere(
    (type) => type.value == value,
    orElse: () => ProteinFatFormulaType.directWeighted,
  );
}

extension MealTypeLabel on MealType {
  String get value {
    switch (this) {
      case MealType.breakfast:
        return '早餐';
      case MealType.lunch:
        return '午餐';
      case MealType.dinner:
        return '晚餐';
      case MealType.snack:
        return '加餐';
      case MealType.custom:
        return '自定义';
    }
  }
}

extension ProteinFatFormulaTypeLabel on ProteinFatFormulaType {
  String get value {
    switch (this) {
      case ProteinFatFormulaType.directWeighted:
        return '直接加权';
      case ProteinFatFormulaType.equivalentCarbs:
        return '等效碳水';
      case ProteinFatFormulaType.totalGrams:
        return '合计克数';
    }
  }

  String get description {
    switch (this) {
      case ProteinFatFormulaType.directWeighted:
        return '蛋白质克数×蛋白质系数 + 脂肪克数×脂肪系数';
      case ProteinFatFormulaType.equivalentCarbs:
        return '（蛋白质克数×蛋白质换算系数 + 脂肪克数×脂肪换算系数）÷ 碳水系数';
      case ProteinFatFormulaType.totalGrams:
        return '（蛋白质克数 + 脂肪克数）÷ 蛋白质脂肪系数';
    }
  }
}

@immutable
class Nutrients {
  const Nutrients({
    required this.carbs,
    required this.protein,
    required this.fat,
  });

  final double carbs;
  final double protein;
  final double fat;

  Nutrients operator +(Nutrients other) {
    return Nutrients(
      carbs: carbs + other.carbs,
      protein: protein + other.protein,
      fat: fat + other.fat,
    );
  }

  static const zero = Nutrients(carbs: 0, protein: 0, fat: 0);
}

@immutable
class Food {
  const Food({
    required this.id,
    required this.name,
    required this.aliases,
    required this.category,
    required this.carbsPer100,
    required this.proteinPer100,
    required this.fatPer100,
    required this.isCustom,
  });

  final String id;
  final String name;
  final List<String> aliases;
  final String category;
  final double carbsPer100;
  final double proteinPer100;
  final double fatPer100;
  final bool isCustom;

  String get aliasesText => aliases.join('、');
}

@immutable
class MealItem {
  const MealItem({
    required this.id,
    this.mealId,
    this.foodId,
    required this.foodNameSnapshot,
    required this.weightG,
    required this.carbsPer100,
    required this.proteinPer100,
    required this.fatPer100,
    required this.carbsG,
    required this.proteinG,
    required this.fatG,
    required this.sortOrder,
  });

  final String id;
  final String? mealId;
  final String? foodId;
  final String foodNameSnapshot;
  final double weightG;
  final double carbsPer100;
  final double proteinPer100;
  final double fatPer100;
  final double carbsG;
  final double proteinG;
  final double fatG;
  final int sortOrder;

  Nutrients get nutrients =>
      Nutrients(carbs: carbsG, protein: proteinG, fat: fatG);

  MealItem copyWith({
    String? id,
    String? mealId,
    String? foodId,
    String? foodNameSnapshot,
    double? weightG,
    double? carbsPer100,
    double? proteinPer100,
    double? fatPer100,
    double? carbsG,
    double? proteinG,
    double? fatG,
    int? sortOrder,
  }) {
    return MealItem(
      id: id ?? this.id,
      mealId: mealId ?? this.mealId,
      foodId: foodId ?? this.foodId,
      foodNameSnapshot: foodNameSnapshot ?? this.foodNameSnapshot,
      weightG: weightG ?? this.weightG,
      carbsPer100: carbsPer100 ?? this.carbsPer100,
      proteinPer100: proteinPer100 ?? this.proteinPer100,
      fatPer100: fatPer100 ?? this.fatPer100,
      carbsG: carbsG ?? this.carbsG,
      proteinG: proteinG ?? this.proteinG,
      fatG: fatG ?? this.fatG,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

@immutable
class MealRecord {
  const MealRecord({
    required this.id,
    required this.name,
    required this.mealType,
    required this.eatenAt,
    required this.totalCarbs,
    required this.totalProtein,
    required this.totalFat,
    required this.items,
  });

  final String id;
  final String name;
  final MealType mealType;
  final DateTime eatenAt;
  final double totalCarbs;
  final double totalProtein;
  final double totalFat;
  final List<MealItem> items;

  Nutrients get nutrients =>
      Nutrients(carbs: totalCarbs, protein: totalProtein, fat: totalFat);
}

@immutable
class InsulinProfile {
  const InsulinProfile({
    required this.id,
    required this.name,
    required this.carbRatio,
    required this.proteinFatEnabled,
    required this.formulaType,
    required this.proteinCoefficient,
    required this.fatCoefficient,
    required this.roundingIncrement,
    required this.enabled,
  });

  final String id;
  final String name;
  final double carbRatio;
  final bool proteinFatEnabled;
  final ProteinFatFormulaType formulaType;
  final double? proteinCoefficient;
  final double? fatCoefficient;
  final double roundingIncrement;
  final bool enabled;

  String get formulaSummary {
    if (!proteinFatEnabled) {
      return '仅计算碳水胰岛素';
    }
    return formulaType.description;
  }
}

@immutable
class InsulinCalculationResult {
  const InsulinCalculationResult({
    required this.carbUnits,
    required this.proteinFatUnits,
    required this.totalUnits,
    required this.roundedTotalUnits,
    required this.explanation,
  });

  final double carbUnits;
  final double proteinFatUnits;
  final double totalUnits;
  final double roundedTotalUnits;
  final List<String> explanation;
}
