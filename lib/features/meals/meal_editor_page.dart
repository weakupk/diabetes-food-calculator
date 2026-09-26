import 'package:flutter/material.dart';

import '../../core/calculators.dart';
import '../../core/formatters.dart';
import '../../core/models.dart';
import '../../data/app_database.dart';
import 'food_picker_page.dart';

class MealEditorPage extends StatefulWidget {
  const MealEditorPage({super.key, this.existingMeal});

  final MealRecord? existingMeal;

  @override
  State<MealEditorPage> createState() => _MealEditorPageState();
}

class _MealEditorPageState extends State<MealEditorPage> {
  final _customNameController = TextEditingController();
  MealType _mealType = MealType.breakfast;
  DateTime _eatenAt = DateTime.now();
  late List<MealItem> _items;
  late Future<List<InsulinProfile>> _profilesFuture;
  String? _selectedProfileId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final meal = widget.existingMeal;
    _items = meal?.items.toList(growable: true) ?? <MealItem>[];
    if (meal != null) {
      _mealType = meal.mealType;
      _eatenAt = meal.eatenAt;
      if (meal.mealType == MealType.custom) {
        _customNameController.text = meal.name;
      }
    }
    _profilesFuture = AppDatabase.instance.listInsulinProfiles();
  }

  @override
  void dispose() {
    _customNameController.dispose();
    super.dispose();
  }

  Nutrients get _totals =>
      NutritionCalculator.sum(_items.map((item) => item.nutrients));

  List<MealItem> _reindexItems(List<MealItem> items) {
    return items
        .asMap()
        .entries
        .map((entry) => entry.value.copyWith(sortOrder: entry.key))
        .toList(growable: false);
  }

  String _roundingLabel(double value) {
    return value == 0 ? '不舍入' : '${formatNumber(value)} U';
  }

  bool _isProfileValidForCalculation(InsulinProfile profile) {
    if (!profile.enabled ||
        profile.carbRatio <= 0 ||
        profile.roundingIncrement < 0) {
      return false;
    }
    if (!profile.proteinFatEnabled) {
      return true;
    }
    switch (profile.formulaType) {
      case ProteinFatFormulaType.directWeighted:
      case ProteinFatFormulaType.equivalentCarbs:
        final proteinCoefficient = profile.proteinCoefficient ?? 0;
        final fatCoefficient = profile.fatCoefficient ?? 0;
        return proteinCoefficient >= 0 &&
            fatCoefficient >= 0 &&
            (proteinCoefficient > 0 || fatCoefficient > 0);
      case ProteinFatFormulaType.totalGrams:
        return (profile.proteinCoefficient ?? 0) > 0;
    }
  }

  Future<void> _addFood() async {
    final item = await Navigator.of(
      context,
    ).push<MealItem>(
      MaterialPageRoute(builder: (_) => const FoodPickerPage()),
    );
    if (item == null) {
      return;
    }
    setState(() {
      _items = _reindexItems([..._items, item]);
    });
  }

  Future<void> _editWeight(int index) async {
    final item = _items[index];
    final controller = TextEditingController(text: formatNumber(item.weightG));
    Nutrients preview = item.nutrients;
    String? errorText;
    final updated = await showDialog<MealItem>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('编辑 ${item.foodNameSnapshot}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: '重量（克）'),
                    onChanged: (value) {
                      final weight = double.tryParse(value.trim());
                      if (weight == null || weight <= 0) {
                        setState(() {
                          errorText = '请输入大于 0 的重量';
                        });
                        return;
                      }
                      setState(() {
                        errorText = null;
                        preview = NutritionCalculator.calculate(
                          weightG: weight,
                          carbsPer100: item.carbsPer100,
                          proteinPer100: item.proteinPer100,
                          fatPer100: item.fatPer100,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (errorText != null) ...[
                    Text(
                      errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text('碳水：${formatNumber(preview.carbs)} g'),
                  Text('蛋白质：${formatNumber(preview.protein)} g'),
                  Text('脂肪：${formatNumber(preview.fat)} g'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final weight = double.tryParse(controller.text.trim());
                    if (weight == null || weight <= 0) {
                      setState(() {
                        errorText = '请输入大于 0 的重量';
                      });
                      return;
                    }
                    final nutrients = NutritionCalculator.calculate(
                      weightG: weight,
                      carbsPer100: item.carbsPer100,
                      proteinPer100: item.proteinPer100,
                      fatPer100: item.fatPer100,
                    );
                    Navigator.of(context).pop(
                      item.copyWith(
                        weightG: weight,
                        carbsG: nutrients.carbs,
                        proteinG: nutrients.protein,
                        fatG: nutrients.fat,
                      ),
                    );
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (updated == null) {
      return;
    }
    setState(() {
      _items[index] = updated;
    });
  }

  Future<void> _saveMeal() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先添加至少一种食物。')));
      return;
    }
    if (_mealType == MealType.custom &&
        _customNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入自定义餐次名称。')));
      return;
    }

    setState(() => _saving = true);
    try {
      await AppDatabase.instance.saveMeal(
        mealId: widget.existingMeal?.id,
        mealType: _mealType,
        name: _mealType == MealType.custom
            ? _customNameController.text.trim()
            : _mealType.value,
        eatenAt: _eatenAt,
        items: _items,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存餐次失败，请重试。')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _eatenAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('zh', 'CN'),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_eatenAt),
    );
    if (time == null) {
      return;
    }
    setState(() {
      _eatenAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final totals = _totals;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingMeal == null ? '新建餐次' : '编辑餐次'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveMeal,
            child: Text(_saving ? '保存中…' : '保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                '仅用于记录和公式计算，不构成医疗建议；参数和实际剂量需由医生或糖尿病教育师确认。',
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MealType>(
            initialValue: _mealType,
            decoration: const InputDecoration(labelText: '餐次类型'),
            items: MealType.values
                .map(
                  (type) =>
                      DropdownMenuItem(value: type, child: Text(type.value)),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) {
                setState(() => _mealType = value);
              }
            },
          ),
          if (_mealType == MealType.custom)
            TextField(
              controller: _customNameController,
              decoration: const InputDecoration(labelText: '自定义餐次名称'),
            ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('用餐时间'),
            subtitle: Text(formatDateTime(_eatenAt)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: _pickDateTime,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('本餐食物', style: Theme.of(context).textTheme.titleMedium),
              TextButton.icon(
                onPressed: _addFood,
                icon: const Icon(Icons.add),
                label: const Text('添加食物'),
              ),
            ],
          ),
          if (_items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('还没有添加食物。请先搜索米饭、鸡胸肉、西红柿等示例食物，或新增自定义食物。'),
              ),
            )
          else
            ..._items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Card(
                child: ListTile(
                  title: Text(item.foodNameSnapshot),
                  subtitle: Text(
                    '重量 ${formatNumber(item.weightG)}g · '
                    '碳水 ${formatNumber(item.carbsG)}g · '
                    '蛋白质 ${formatNumber(item.proteinG)}g · '
                    '脂肪 ${formatNumber(item.fatG)}g',
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: '编辑重量',
                        onPressed: () => _editWeight(index),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: '移除',
                        onPressed: () => setState(() {
                          final updatedItems = [..._items]..removeAt(index);
                          _items = _reindexItems(updatedItems);
                        }),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('本餐合计', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('总碳水：${formatNumber(totals.carbs)} g'),
                  Text('总蛋白质：${formatNumber(totals.protein)} g'),
                  Text('总脂肪：${formatNumber(totals.fat)} g'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<InsulinProfile>>(
            future: _profilesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              final profiles = (snapshot.data ?? const <InsulinProfile>[])
                  .where(_isProfileValidForCalculation)
                  .toList(growable: false);
              if (profiles.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '暂无可用的胰岛素方案。请先在“方案”页创建并确认有效参数（碳水系数需大于 0，舍入模式支持不舍入/0.5U/1U），再返回此页面核对计算结果。',
                    ),
                  ),
                );
              }
              final selected =
                  profiles
                      .where((profile) => profile.id == _selectedProfileId)
                      .isNotEmpty
                  ? profiles.firstWhere(
                      (profile) => profile.id == _selectedProfileId,
                    )
                  : profiles.first;
              InsulinCalculationResult? calculation;
              String? calculationError;
              try {
                calculation = InsulinCalculator.calculate(
                  nutrients: totals,
                  profile: selected,
                );
              } on ArgumentError catch (error) {
                final message = error.message;
                calculationError = message == null ? '当前方案参数无效' : '$message';
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InputDecorator(
                    decoration: const InputDecoration(labelText: '用于核对的胰岛素方案'),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selected.id,
                        isExpanded: true,
                        items: profiles
                            .map(
                              (profile) => DropdownMenuItem(
                                value: profile.id,
                                child: Text(profile.name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) =>
                            setState(() => _selectedProfileId = value),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      title: const Text('胰岛素拆分结果'),
                      subtitle: calculation == null
                          ? Text('当前方案无法计算：$calculationError')
                          : Text(
                              '碳水 ${formatNumber(calculation.carbUnits)} U · '
                              '蛋白质/脂肪 ${formatNumber(calculation.proteinFatUnits)} U · '
                              '合计 ${formatNumber(calculation.roundedTotalUnits)} U',
                            ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('方案名称：${selected.name}'),
                              Text(
                                '当前公式模式：${selected.proteinFatEnabled ? selected.formulaType.value : '仅碳水'}',
                              ),
                              Text(
                                '舍入模式：${_roundingLabel(selected.roundingIncrement)}',
                              ),
                              const SizedBox(height: 8),
                              if (calculationError != null)
                                Text(
                                  calculationError,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                )
                              else
                                ...calculation!.explanation.map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(item),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
