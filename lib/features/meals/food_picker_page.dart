import 'package:flutter/material.dart';

import '../../core/calculators.dart';
import '../../core/formatters.dart';
import '../../core/models.dart';
import '../../data/app_database.dart';

class FoodPickerPage extends StatefulWidget {
  const FoodPickerPage({super.key});

  @override
  State<FoodPickerPage> createState() => _FoodPickerPageState();
}

class _FoodPickerPageState extends State<FoodPickerPage> {
  final _searchController = TextEditingController();
  late Future<List<Food>> _foodsFuture;

  @override
  void initState() {
    super.initState();
    _foodsFuture = AppDatabase.instance.searchFoods('');
    _searchController.addListener(_reload);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_reload)
      ..dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _foodsFuture = AppDatabase.instance.searchFoods(
        _searchController.text.trim(),
      );
    });
  }

  Future<void> _selectFood(Food food) async {
    final controller = TextEditingController(text: '100');
    Nutrients? preview = NutritionCalculator.calculate(
      weightG: 100,
      carbsPer100: food.carbsPer100,
      proteinPer100: food.proteinPer100,
      fatPer100: food.fatPer100,
    );
    String? errorText;

    final selectedItem = await showDialog<MealItem>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void updatePreview(String value) {
              final weight = double.tryParse(value.trim());
              setState(() {
                if (weight != null && weight > 0) {
                  errorText = null;
                  preview = NutritionCalculator.calculate(
                    weightG: weight,
                    carbsPer100: food.carbsPer100,
                    proteinPer100: food.proteinPer100,
                    fatPer100: food.fatPer100,
                  );
                } else {
                  errorText = '请输入大于 0 的重量';
                  preview = null;
                }
              });
            }

            return AlertDialog(
              title: Text('添加 ${food.name}'),
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
                    onChanged: updatePreview,
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
                  Text(
                    '碳水：${preview == null ? '-' : '${formatNumber(preview!.carbs)} g'}',
                  ),
                  Text(
                    '蛋白质：${preview == null ? '-' : '${formatNumber(preview!.protein)} g'}',
                  ),
                  Text(
                    '脂肪：${preview == null ? '-' : '${formatNumber(preview!.fat)} g'}',
                  ),
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
                      carbsPer100: food.carbsPer100,
                      proteinPer100: food.proteinPer100,
                      fatPer100: food.fatPer100,
                    );
                    Navigator.of(context).pop(
                      MealItem(
                        id: AppDatabase.newId(),
                        foodId: food.id,
                        foodNameSnapshot: food.name,
                        weightG: weight,
                        carbsPer100: food.carbsPer100,
                        proteinPer100: food.proteinPer100,
                        fatPer100: food.fatPer100,
                        carbsG: nutrients.carbs,
                        proteinG: nutrients.protein,
                        fatG: nutrients.fat,
                        sortOrder: 0,
                      ),
                    );
                  },
                  child: const Text('添加'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    if (selectedItem != null && mounted) {
      Navigator.of(context).pop(selectedItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加食物')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜索中文食物名称或别名',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (_searchController.text.trim().isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('未输入搜索词时，可直接从下方常用/示例食物中选择。'),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Food>>(
              future: _foodsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final foods = snapshot.data ?? const <Food>[];
                if (foods.isEmpty) {
                  return Center(
                    child: Text(
                      _searchController.text.trim().isEmpty
                          ? '暂无常用食物，请先到“食物库”新增。'
                          : '没有搜索结果，请尝试中文名称或别名。',
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: foods.length,
                  itemBuilder: (context, index) {
                    final food = foods[index];
                    return Card(
                      child: ListTile(
                        title: Text(food.name),
                        subtitle: Text(
                          '每100克：碳水 ${formatNumber(food.carbsPer100)}g · '
                          '蛋白质 ${formatNumber(food.proteinPer100)}g · '
                          '脂肪 ${formatNumber(food.fatPer100)}g',
                        ),
                        onTap: () => _selectFood(food),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
