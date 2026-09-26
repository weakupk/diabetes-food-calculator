import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/models.dart';
import '../../data/app_database.dart';
import 'meal_editor_page.dart';

class MealsPage extends StatefulWidget {
  const MealsPage({super.key});

  @override
  State<MealsPage> createState() => _MealsPageState();
}

class _MealsPageState extends State<MealsPage> {
  late Future<List<MealRecord>> _mealsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _mealsFuture = AppDatabase.instance.listMealRecords();
    });
  }

  Future<void> _openEditor([MealRecord? meal]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MealEditorPage(existingMeal: meal)),
    );
    if (changed == true) {
      _reload();
    }
  }

  Future<void> _deleteMeal(MealRecord meal) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除餐次'),
            content: Text('确定删除“${meal.name}”吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    await AppDatabase.instance.deleteMeal(meal.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<MealRecord>>(
        future: _mealsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final meals = snapshot.data ?? const <MealRecord>[];
          final now = DateTime.now();
          final todayMeals = meals.where(
            (meal) =>
                meal.eatenAt.year == now.year &&
                meal.eatenAt.month == now.month &&
                meal.eatenAt.day == now.day,
          );
          final totalCarbs = todayMeals.fold<double>(
            0,
            (sum, meal) => sum + meal.totalCarbs,
          );
          final totalProtein = todayMeals.fold<double>(
            0,
            (sum, meal) => sum + meal.totalProtein,
          );
          final totalFat = todayMeals.fold<double>(
            0,
            (sum, meal) => sum + meal.totalFat,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '今日概览',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('总碳水：${formatNumber(totalCarbs)} g'),
                      Text('总蛋白质：${formatNumber(totalProtein)} g'),
                      Text('总脂肪：${formatNumber(totalFat)} g'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (meals.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('暂无餐次记录。请新建早餐、午餐、晚餐、加餐或自定义餐次。'),
                  ),
                )
              else
                ...meals.map(
                  (meal) => Card(
                    child: ExpansionTile(
                      title: Text(
                        '${meal.name} · ${formatDateTime(meal.eatenAt)}',
                      ),
                      subtitle: Text(
                        '合计：碳水 ${formatNumber(meal.totalCarbs)}g · '
                        '蛋白质 ${formatNumber(meal.totalProtein)}g · '
                        '脂肪 ${formatNumber(meal.totalFat)}g',
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        ...meal.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${item.foodNameSnapshot} · 重量 ${formatNumber(item.weightG)}g · '
                                '碳水 ${formatNumber(item.carbsG)}g · '
                                '蛋白质 ${formatNumber(item.proteinG)}g · '
                                '脂肪 ${formatNumber(item.fatG)}g',
                              ),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _openEditor(meal),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('编辑'),
                            ),
                            TextButton.icon(
                              onPressed: () => _deleteMeal(meal),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('删除'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        label: const Text('新建餐次'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
