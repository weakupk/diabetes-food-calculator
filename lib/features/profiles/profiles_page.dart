import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/models.dart';
import '../../data/app_database.dart';
import 'profile_form_page.dart';

class ProfilesPage extends StatefulWidget {
  const ProfilesPage({super.key});

  @override
  State<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends State<ProfilesPage> {
  late Future<List<InsulinProfile>> _profilesFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _profilesFuture = AppDatabase.instance.listInsulinProfiles();
    });
  }

  Future<void> _openForm([InsulinProfile? profile]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProfileFormPage(profile: profile)),
    );
    if (changed == true) {
      _reload();
    }
  }

  Future<void> _deleteProfile(InsulinProfile profile) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除胰岛素方案'),
            content: Text('确定删除“${profile.name}”吗？'),
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
    await AppDatabase.instance.deleteInsulinProfile(profile.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '仅用于记录和公式计算，不构成医疗建议；参数和实际剂量需由医生或糖尿病教育师确认。',
              ),
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<InsulinProfile>>(
            future: _profilesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final profiles = snapshot.data ?? const <InsulinProfile>[];
              if (profiles.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('暂无胰岛素方案。第一版默认不预填医学参数，请手动创建并确认。'),
                  ),
                );
              }
              return Column(
                children: profiles
                    .map((profile) {
                      return Card(
                        child: ListTile(
                          title: Text(profile.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '碳水系数：${formatNumber(profile.carbRatio)} g/U',
                              ),
                              Text('蛋白质/脂肪：${profile.formulaSummary}'),
                              Text(
                                '舍入模式：${profile.roundingIncrement == 0 ? '不舍入' : '${formatNumber(profile.roundingIncrement)} U'}',
                              ),
                              Text(profile.enabled ? '状态：启用' : '状态：停用'),
                            ],
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: '编辑',
                                onPressed: () => _openForm(profile),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: '删除',
                                onPressed: () => _deleteProfile(profile),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        label: const Text('新增方案'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
