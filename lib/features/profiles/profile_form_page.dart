import 'package:flutter/material.dart';

import '../../core/calculators.dart';
import '../../core/models.dart';
import '../../data/app_database.dart';

class ProfileFormPage extends StatefulWidget {
  const ProfileFormPage({super.key, this.profile});

  final InsulinProfile? profile;

  @override
  State<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends State<ProfileFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _carbRatioController = TextEditingController();
  final _proteinCoefficientController = TextEditingController();
  final _fatCoefficientController = TextEditingController();
  final _roundingIncrementController = TextEditingController();
  bool _enabled = true;
  bool _proteinFatEnabled = false;
  bool _confirmedByDoctor = false;
  ProteinFatFormulaType _formulaType = ProteinFatFormulaType.directWeighted;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    if (profile != null) {
      _nameController.text = profile.name;
      _carbRatioController.text = profile.carbRatio.toString();
      _proteinCoefficientController.text =
          profile.proteinCoefficient?.toString() ?? '';
      _fatCoefficientController.text = profile.fatCoefficient?.toString() ?? '';
      _roundingIncrementController.text = profile.roundingIncrement.toString();
      _enabled = profile.enabled;
      _proteinFatEnabled = profile.proteinFatEnabled;
      _formulaType = profile.formulaType;
      _confirmedByDoctor = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _carbRatioController.dispose();
    _proteinCoefficientController.dispose();
    _fatCoefficientController.dispose();
    _roundingIncrementController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_hasValidProteinFatConfiguration()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('直接加权或等效碳水公式至少需要一个大于 0 的相关系数。')),
      );
      return;
    }
    if (!_confirmedByDoctor) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先确认参数来自医生或既定治疗方案。')));
      return;
    }

    setState(() => _saving = true);
    final proteinCoefficientText = _proteinCoefficientController.text.trim();
    final fatCoefficientText = _fatCoefficientController.text.trim();
    if (_proteinFatEnabled && proteinCoefficientText.isEmpty) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写蛋白质相关系数；未使用请填 0。')));
      return;
    }
    if (_proteinFatEnabled &&
        _formulaType != ProteinFatFormulaType.totalGrams &&
        fatCoefficientText.isEmpty) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写脂肪相关系数；未使用请填 0。')));
      return;
    }
    final profile = InsulinProfile(
      id: widget.profile?.id ?? AppDatabase.newId(),
      name: _nameController.text.trim(),
      carbRatio: double.parse(_carbRatioController.text.trim()),
      proteinFatEnabled: _proteinFatEnabled,
      formulaType: _formulaType,
      proteinCoefficient: !_proteinFatEnabled
         ? null
         : double.parse(proteinCoefficientText),
      fatCoefficient:
         !_proteinFatEnabled || _formulaType == ProteinFatFormulaType.totalGrams
         ? null
         : double.parse(fatCoefficientText),
      roundingIncrement: double.parse(_roundingIncrementController.text.trim()),
      enabled: _enabled,
    );
    try {
      await AppDatabase.instance.saveInsulinProfile(profile);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存方案失败，请重试。')));
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
      appBar: AppBar(
        title: Text(widget.profile == null ? '新增胰岛素方案' : '编辑胰岛素方案'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
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
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '方案名称'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入方案名称' : null,
            ),
            SwitchListTile(
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
              title: const Text('启用此方案'),
            ),
            TextFormField(
              controller: _carbRatioController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '碳水系数（多少克碳水对应 1U）'),
              validator: _validateCarbRatio,
            ),
            TextFormField(
              controller: _roundingIncrementController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '舍入模式（仅支持 0、0.5、1 U）',
                helperText: '填 0 表示不舍入，填 0.5 或 1 表示按对应刻度舍入。',
              ),
              validator: _validateRoundingIncrement,
            ),
            SwitchListTile(
              value: _proteinFatEnabled,
              onChanged: (value) => setState(() => _proteinFatEnabled = value),
              title: const Text('启用蛋白质/脂肪计算'),
            ),
            if (_proteinFatEnabled) ...[
              DropdownButtonFormField<ProteinFatFormulaType>(
                initialValue: _formulaType,
                decoration: const InputDecoration(labelText: '蛋白质/脂肪公式类型'),
                items: ProteinFatFormulaType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.value),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _formulaType = value);
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(_formulaType.description),
              const SizedBox(height: 8),
              TextFormField(
                controller: _proteinCoefficientController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _formulaType == ProteinFatFormulaType.totalGrams
                      ? '蛋白质脂肪系数'
                      : '蛋白质相关系数',
                  helperText: _formulaType == ProteinFatFormulaType.totalGrams
                      ? null
                      : '未使用该项时请填写 0。',
                ),
                validator: _validateFormulaPrimary,
              ),
              if (_formulaType != ProteinFatFormulaType.totalGrams)
                TextFormField(
                  controller: _fatCoefficientController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        _formulaType == ProteinFatFormulaType.equivalentCarbs
                        ? '脂肪换算系数'
                        : '脂肪相关系数',
                    helperText: '未使用该项时请填写 0。',
                  ),
                  validator: _validateFormulaSecondary,
                ),
            ],
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmedByDoctor,
              onChanged: (value) =>
                  setState(() => _confirmedByDoctor = value ?? false),
              title: const Text('我确认以上参数来自医生或既定治疗方案'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中…' : '保存方案'),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateCarbRatio(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入数值';
    }
    final number = double.tryParse(value.trim());
    if (number == null || number <= 0) {
      return '请输入大于 0 的数字';
    }
    return null;
  }

  String? _validateRoundingIncrement(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入数值';
    }
    final number = double.tryParse(value.trim());
    if (number == null) {
      return '请输入有效数字';
    }
    if (!InsulinCalculator.supportedRoundingIncrements.contains(number)) {
      return '仅支持 0、0.5 或 1';
    }
    return null;
  }

  String? _validateFormulaPrimary(String? value) {
    if (!_proteinFatEnabled) {
      return null;
    }
    if (value == null || value.trim().isEmpty) {
      return '请输入系数';
    }
    final number = double.tryParse(value.trim());
    if (number == null) {
      return '请输入有效数字';
    }
    if (_formulaType == ProteinFatFormulaType.totalGrams && number <= 0) {
      return '请输入大于 0 的数字';
    }
    if (_formulaType != ProteinFatFormulaType.totalGrams && number < 0) {
      return '不能为负数';
    }
    return null;
  }

  String? _validateFormulaSecondary(String? value) {
    if (!_proteinFatEnabled ||
        _formulaType == ProteinFatFormulaType.totalGrams) {
      return null;
    }
    if (value == null || value.trim().isEmpty) {
      return '请输入系数';
    }
    final number = double.tryParse(value.trim());
    if (number == null || number < 0) {
      return '请输入大于等于 0 的数字';
    }
    return null;
  }

  bool _hasValidProteinFatConfiguration() {
    if (!_proteinFatEnabled) {
      return true;
    }
    if (_formulaType == ProteinFatFormulaType.totalGrams) {
      return true;
    }
    final primary =
        double.tryParse(_proteinCoefficientController.text.trim()) ?? 0;
    final secondary =
        double.tryParse(_fatCoefficientController.text.trim()) ?? 0;
    return primary > 0 || secondary > 0;
  }
}
