import 'package:flutter/material.dart';

import '../data/templates_repository.dart';
import '../domain/models.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final _repo = TemplatesRepository();
  List<TemplateFolder> _folders = [];
  List<MealTemplate> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final folders = await _repo.getFolders();
    final templates = await _repo.getTemplates();
    if (!mounted) return;
    setState(() {
      _folders = folders;
      _templates = templates;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plantillas'),
        actions: [IconButton(onPressed: () => Navigator.pushNamed(context, '/nutrition/template_editor').then((_) => _load()), icon: const Icon(Icons.add))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Carpetas', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _folders
                      .map(
                        (folder) => Chip(
                          label: Text(folder.name),
                          avatar: const Icon(Icons.folder_open, size: 16),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                Text('Todas', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_templates.isEmpty)
                  const ListTile(title: Text('No hay plantillas todavía'))
                else
                  ..._templates.map(
                    (item) => ListTile(
                      title: Text(item.name),
                      subtitle: Text('${item.effectiveTotals.kcal.round()} kcal · ${item.effectiveItems.length} alimentos'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await _repo.delete(item.id);
                          await _load();
                        },
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
