import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/models.dart';
import '../../data/app_database.dart';
import 'food_form_page.dart';

class FoodsPage extends StatefulWidget {
  const FoodsPage({super.key});

  @override
  State<FoodsPage> createState() => _FoodsPageState();
}

class _FoodsPageState extends State<FoodsPage> {
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

  Future<void> _openFoodForm([Food? food]) async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => FoodFormPage(food: food)));
    if (changed == true) {
      _reload();
    }
  }

  Future<void> _deleteFood(Food food) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除自定义食物'),
            content: Text('确定删除“${food.name}”吗？历史餐次中的快照不会受影响。'),
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
    await AppDatabase.instance.deleteCustomFood(food.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜索食物名称或别名，例如：米饭、番茄',
                border: OutlineInputBorder(),
              ),
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
                  return const Center(child: Text('没有找到食物，请新增自定义食物。'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                  itemCount: foods.length,
                  itemBuilder: (context, index) {
                    final food = foods[index];
                    return Card(
                      child: ListTile(
                        title: Text(food.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (food.aliases.isNotEmpty)
                              Text('别名：${food.aliasesText}'),
                            Text(
                              '每100克：碳水 ${formatNumber(food.carbsPer100)}g · '
                              '蛋白质 ${formatNumber(food.proteinPer100)}g · '
                              '脂肪 ${formatNumber(food.fatPer100)}g',
                            ),
                            if (food.category.isNotEmpty)
                              Text('分类：${food.category}'),
                          ],
                        ),
                        trailing: food.isCustom
                            ? Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: '编辑',
                                    onPressed: () => _openFoodForm(food),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: '删除',
                                    onPressed: () => _deleteFood(food),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              )
                            : const Chip(label: Text('示例')),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openFoodForm(),
        label: const Text('新增食物'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
