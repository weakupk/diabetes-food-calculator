import 'package:flutter/material.dart';

import '../../core/calculators.dart';
import '../../core/formula_engine.dart';
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
  final _totalDailyInsulinController = TextEditingController();
  final _carbRuleController = TextEditingController();
  final _proteinFatBaseController = TextEditingController();
  final _proteinCoefficientController = TextEditingController();
  final _fatCoefficientController = TextEditingController();
  final _correctionStandardController = TextEditingController();
  final _cirFormulaController = TextEditingController();
  final _carbInsulinFormulaController = TextEditingController();
  final _proteinFatFormulaController = TextEditingController();
  final _isfFormulaController = TextEditingController();
  final _roundingIncrementController = TextEditingController();
  bool _enabled = true;
  bool _proteinFatEnabled = true;
  bool _confirmedByDoctor = false;
  ProteinFatFormulaType _formulaType = ProteinFatFormulaType.massBased;
  String _customProteinFatFormula = InsulinProfile.defaultProteinFatMassFormula;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    if (profile != null) {
      _nameController.text = profile.name;
      _totalDailyInsulinController.text =
          profile.totalDailyInsulin?.toString() ?? '';
      _carbRuleController.text = profile.carbRule?.toString() ?? '';
      _proteinFatBaseController.text = profile.proteinFatBase?.toString() ?? '';
      _proteinCoefficientController.text =
          profile.proteinCoefficient?.toString() ?? '';
      _fatCoefficientController.text = profile.fatCoefficient?.toString() ?? '';
      _correctionStandardController.text =
          profile.correctionStandard?.toString() ?? '';
      _cirFormulaController.text = profile.cirFormula;
      _carbInsulinFormulaController.text = profile.carbInsulinFormula;
      _proteinFatFormulaController.text = profile.proteinFatFormula;
      _customProteinFatFormula = profile.proteinFatFormula;
      _isfFormulaController.text = profile.isfFormula;
      _roundingIncrementController.text = profile.roundingIncrement.toString();
      _enabled = profile.enabled;
      _proteinFatEnabled = profile.proteinFatEnabled;
      _formulaType = profile.formulaType;
      _confirmedByDoctor = true;
    } else {
      _cirFormulaController.text = InsulinProfile.defaultCirFormula;
      _carbInsulinFormulaController.text =
          InsulinProfile.defaultCarbInsulinFormula;
      _proteinFatFormulaController.text =
          InsulinProfile.defaultProteinFatMassFormula;
      _customProteinFatFormula = _proteinFatFormulaController.text;
      _isfFormulaController.text = InsulinProfile.defaultIsfFormula;
      _roundingIncrementController.text = '0';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _totalDailyInsulinController.dispose();
    _carbRuleController.dispose();
    _proteinFatBaseController.dispose();
    _proteinCoefficientController.dispose();
    _fatCoefficientController.dispose();
    _correctionStandardController.dispose();
    _cirFormulaController.dispose();
    _carbInsulinFormulaController.dispose();
    _proteinFatFormulaController.dispose();
    _isfFormulaController.dispose();
    _roundingIncrementController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_confirmedByDoctor) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先确认参数来自医生或既定治疗方案。')));
      return;
    }

    setState(() => _saving = true);
    try {
      final profile = _buildProfile();
      InsulinCalculator.validateProfile(profile);
      await AppDatabase.instance.saveInsulinProfile(profile);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on FormulaEvaluationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on ArgumentError catch (error) {
      if (mounted) {
        final message = error.message?.toString() ?? '保存方案失败，请检查输入';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
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

  InsulinProfile _buildProfile() {
    final totalDailyInsulin = double.parse(
      _totalDailyInsulinController.text.trim(),
    );
    final carbRule = double.parse(_carbRuleController.text.trim());
    final proteinFatBase = _parseOptional(_proteinFatBaseController.text);
    final correctionStandard = double.parse(
      _correctionStandardController.text.trim(),
    );
    final cir = FormulaEvaluator.evaluate(_cirFormulaController.text.trim(), {
      'total_daily_insulin': totalDailyInsulin,
      'carb_rule': carbRule,
      'protein_fat_base': proteinFatBase ?? 1,
      'correction_standard': correctionStandard,
      'carbs': 1,
      'protein': 1,
      'fat': 1,
      'cir': 1,
      'carb_ratio': 1,
    });

    return InsulinProfile(
      id: widget.profile?.id ?? AppDatabase.newId(),
      name: _nameController.text.trim(),
      carbRatio: cir,
      totalDailyInsulin: totalDailyInsulin,
      carbRule: carbRule,
      proteinFatBase: proteinFatBase,
      correctionStandard: correctionStandard,
      proteinFatEnabled: _proteinFatEnabled,
      formulaType: _formulaType,
      proteinCoefficient: _parseOptional(_proteinCoefficientController.text),
      fatCoefficient: _parseOptional(_fatCoefficientController.text),
      cirFormula: _cirFormulaController.text.trim(),
      carbInsulinFormula: _carbInsulinFormulaController.text.trim(),
      proteinFatFormula: _proteinFatFormulaController.text.trim(),
      isfFormula: _isfFormulaController.text.trim(),
      roundingIncrement: double.parse(_roundingIncrementController.text.trim()),
      enabled: _enabled,
    );
  }

  double? _parseOptional(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return double.parse(trimmed);
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
              controller: _totalDailyInsulinController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '全天胰岛素量'),
              validator: (value) => _validatePositiveNumber(value, label: '全天胰岛素量'),
            ),
            TextFormField(
              controller: _carbRuleController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '基准法则',
                helperText: '例如 500 法则中的 500。',
              ),
              validator: (value) => _validatePositiveNumber(value, label: '基准法则'),
            ),
            TextFormField(
              controller: _correctionStandardController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '纠正标准',
                helperText: '用于 ISF = 纠正标准 / 全天胰岛素量 / 18',
              ),
              validator: (value) => _validatePositiveNumber(value, label: '纠正标准'),
            ),
            TextFormField(
              controller: _roundingIncrementController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '舍入模式（仅支持 0、0.5、1 U）',
                helperText: '填 0 表示不舍入，填 0.5 或 1 表示按对应刻度舍入。',
              ),
              validator: _validateRoundingIncrement,
            ),
            const SizedBox(height: 12),
            const Text(
              '可用变量：carbs、protein、fat、cir、total_daily_insulin、carb_rule、protein_fat_base、correction_standard；兼容旧公式时还可使用 protein_coefficient、fat_coefficient',
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _cirFormulaController,
              decoration: const InputDecoration(
                labelText: 'CIR 公式',
                helperText: '默认：total_daily_insulin / carb_rule',
              ),
              validator: (value) => _validateFormula(
                value,
                label: 'CIR 公式',
                includeProteinFatBase: true,
              ),
            ),
            TextFormField(
              controller: _carbInsulinFormulaController,
              decoration: const InputDecoration(
                labelText: '碳水胰岛素公式',
                helperText: '默认：carbs / cir',
              ),
              validator: (value) => _validateFormula(
                value,
                label: '碳水胰岛素公式',
                includeProteinFatBase: true,
              ),
            ),
            SwitchListTile(
              value: _proteinFatEnabled,
              onChanged: (value) => setState(() => _proteinFatEnabled = value),
              title: const Text('启用蛋白质/脂肪计算'),
            ),
            if (_proteinFatEnabled) ...[
              DropdownButtonFormField<ProteinFatFormulaType>(
                initialValue: _formulaType,
                decoration: const InputDecoration(labelText: '蛋白质/脂肪公式模式'),
                items: ProteinFatFormulaType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.value),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    if (_formulaType == ProteinFatFormulaType.custom) {
                      _customProteinFatFormula = _proteinFatFormulaController.text;
                    }
                    _formulaType = value;
                    if (value == ProteinFatFormulaType.massBased) {
                      _proteinFatFormulaController.text =
                          InsulinProfile.defaultProteinFatMassFormula;
                    } else if (value == ProteinFatFormulaType.fpu) {
                      _proteinFatFormulaController.text =
                          InsulinProfile.defaultProteinFatFpuFormula;
                    } else {
                      _proteinFatFormulaController.text =
                          _customProteinFatFormula.trim().isEmpty
                          ? InsulinProfile.defaultProteinFatMassFormula
                          : _customProteinFatFormula;
                    }
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(_formulaType.description),
              const SizedBox(height: 8),
              TextFormField(
                controller: _proteinFatBaseController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '蛋白质/脂肪基准',
                  helperText: '质量法默认会使用 protein_fat_base，自定义公式也可使用。',
                ),
                validator: _validateProteinFatBase,
              ),
              TextFormField(
                controller: _proteinFatFormulaController,
                decoration: InputDecoration(
                  labelText: _formulaType == ProteinFatFormulaType.fpu
                      ? '蛋白质/脂肪公式（FPU法）'
                      : '蛋白质/脂肪公式',
                  helperText: _formulaType == ProteinFatFormulaType.fpu
                      ? '默认：((protein * 4) + (fat * 9)) / 100'
                      : '默认：(protein + fat) / 2 / protein_fat_base',
                ),
                validator: (value) => _validateFormula(
                  value,
                  label: '蛋白质/脂肪公式',
                  includeProteinFatBase: true,
                ),
              ),
              if (_formulaType == ProteinFatFormulaType.custom) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _proteinCoefficientController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'protein_coefficient（自定义可选）',
                    helperText: '仅当自定义公式引用 protein_coefficient 时需要填写。',
                  ),
                  validator: (value) => _validateOptionalCoefficient(
                    value,
                    variableName: 'protein_coefficient',
                    label: 'protein_coefficient',
                  ),
                ),
                TextFormField(
                  controller: _fatCoefficientController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'fat_coefficient（自定义可选）',
                    helperText: '仅当自定义公式引用 fat_coefficient 时需要填写。',
                  ),
                  validator: (value) => _validateOptionalCoefficient(
                    value,
                    variableName: 'fat_coefficient',
                    label: 'fat_coefficient',
                  ),
                ),
              ],
              if (_formulaType == ProteinFatFormulaType.fpu)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('100千卡=1U=1FPU'),
                ),
            ],
            const SizedBox(height: 8),
            TextFormField(
              controller: _isfFormulaController,
              decoration: const InputDecoration(
                labelText: 'ISF 公式',
                helperText: '默认：correction_standard / total_daily_insulin / 18',
              ),
              validator: (value) => _validateFormula(
                value,
                label: 'ISF 公式',
                includeProteinFatBase: true,
              ),
            ),
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

  String? _validatePositiveNumber(String? value, {required String label}) {
    if (value == null || value.trim().isEmpty) {
      return '请输入$label';
    }
    final number = double.tryParse(value.trim());
    if (number == null || number <= 0) {
      return '$label必须大于 0';
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

  String? _validateProteinFatBase(String? value) {
    if (!_proteinFatEnabled) {
      return null;
    }
    var usesProteinFatBase = false;
    if (_proteinFatFormulaController.text.trim().isNotEmpty) {
      try {
        usesProteinFatBase = FormulaEvaluator.variableNames(
          _proteinFatFormulaController.text,
        ).contains('protein_fat_base');
      } on FormulaEvaluationException {
        usesProteinFatBase = true;
      }
    }
    if (!usesProteinFatBase) {
      return null;
    }
    return _validatePositiveNumber(value, label: '蛋白质/脂肪基准');
  }

  String? _validateFormula(
    String? value, {
    required String label,
    required bool includeProteinFatBase,
  }) {
    if (value == null || value.trim().isEmpty) {
      return '请输入$label';
    }
    try {
      final variables = <String, double>{
        'carbs': 1,
        'protein': 1,
        'fat': 1,
        'cir': 1,
        'carb_ratio': 1,
        if (widget.profile?.proteinCoefficient != null)
          'protein_coefficient': widget.profile!.proteinCoefficient!,
        if (widget.profile?.fatCoefficient != null)
          'fat_coefficient': widget.profile!.fatCoefficient!,
        'total_daily_insulin':
            double.tryParse(_totalDailyInsulinController.text.trim()) ?? 1,
        'carb_rule': double.tryParse(_carbRuleController.text.trim()) ?? 1,
        'correction_standard':
            double.tryParse(_correctionStandardController.text.trim()) ?? 1,
      };
      if (includeProteinFatBase) {
        variables['protein_fat_base'] =
            double.tryParse(_proteinFatBaseController.text.trim()) ?? 1;
      }
      final proteinCoefficient =
          double.tryParse(_proteinCoefficientController.text.trim());
      if (proteinCoefficient != null) {
        variables['protein_coefficient'] = proteinCoefficient;
      }
      final fatCoefficient = double.tryParse(_fatCoefficientController.text.trim());
      if (fatCoefficient != null) {
        variables['fat_coefficient'] = fatCoefficient;
      }
      FormulaEvaluator.evaluate(value.trim(), variables);
      return null;
    } on FormulaEvaluationException catch (error) {
      return error.message;
    }
  }

  String? _validateOptionalCoefficient(
    String? value, {
    required String variableName,
    required String label,
  }) {
    if (!_proteinFatEnabled || _formulaType != ProteinFatFormulaType.custom) {
      return null;
    }
    var usesVariable = false;
    if (_proteinFatFormulaController.text.trim().isNotEmpty) {
      try {
        usesVariable = FormulaEvaluator.variableNames(
          _proteinFatFormulaController.text,
        ).contains(variableName);
      } on FormulaEvaluationException {
        usesVariable = true;
      }
    }
    if (!usesVariable) {
      return null;
    }
    if (value == null || value.trim().isEmpty) {
      return '请输入$label';
    }
    final number = double.tryParse(value.trim());
    if (number == null) {
      return '请输入有效数字';
    }
    return null;
  }
}
