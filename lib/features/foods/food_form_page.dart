import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../data/app_database.dart';

class FoodFormPage extends StatefulWidget {
  const FoodFormPage({super.key, this.food});

  final Food? food;

  @override
  State<FoodFormPage> createState() => _FoodFormPageState();
}

class _FoodFormPageState extends State<FoodFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _aliasesController = TextEditingController();
  final _categoryController = TextEditingController();
  final _carbsController = TextEditingController();
  final _proteinController = TextEditingController();
  final _fatController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final food = widget.food;
    if (food != null) {
      _nameController.text = food.name;
      _aliasesController.text = food.aliases.join('、');
      _categoryController.text = food.category;
      _carbsController.text = food.carbsPer100.toString();
      _proteinController.text = food.proteinPer100.toString();
      _fatController.text = food.fatPer100.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aliasesController.dispose();
    _categoryController.dispose();
    _carbsController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    final food = Food(
      id: widget.food?.id ?? AppDatabase.newId(),
      name: _nameController.text.trim(),
      aliases: _aliasesController.text
          .split(RegExp(r'[、,，|]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      category: _categoryController.text.trim(),
      carbsPer100: double.parse(_carbsController.text.trim()),
      proteinPer100: double.parse(_proteinController.text.trim()),
      fatPer100: double.parse(_fatController.text.trim()),
      isCustom: true,
    );
    try {
      await AppDatabase.instance.saveFood(food);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存食物失败，请重试。')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.food == null ? '新增自定义食物' : '编辑自定义食物')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('提示：请按照食品标签或可靠食物成分数据填写。所有营养值均按每100克保存。'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '食物名称'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入食物名称' : null,
            ),
            TextFormField(
              controller: _aliasesController,
              decoration: const InputDecoration(labelText: '别名（用、或逗号分隔）'),
            ),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: '分类'),
            ),
            TextFormField(
              controller: _carbsController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '每100克碳水（克）'),
              validator: _validateNonNegative,
            ),
            TextFormField(
              controller: _proteinController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '每100克蛋白质（克）'),
              validator: _validateNonNegative,
            ),
            TextFormField(
              controller: _fatController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '每100克脂肪（克）'),
              validator: _validateNonNegative,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中…' : '保存食物'),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateNonNegative(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入数值';
    }
    final number = double.tryParse(value.trim());
    if (number == null) {
      return '请输入有效数字';
    }
    if (number < 0) {
      return '不能为负数';
    }
    return null;
  }
}
