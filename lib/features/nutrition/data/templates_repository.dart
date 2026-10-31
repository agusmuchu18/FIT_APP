import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import '../../../core/data/account_storage_scope.dart';
import 'nutrition_writes.dart';

class TemplatesRepository {
  TemplatesRepository({SharedPreferences? prefs, String? scope})
    : _scope = scope ?? AccountStorageScope.current,
      _prefs = prefs == null ? null : ScopedPreferences(prefs, scope: scope);
  final String _scope;
  String get storageScope => _scope;

  static const _foldersKey = 'nutrition.template_folders.v1';
  static const _templatesKey = 'nutrition.templates.v1';

  ScopedPreferences? _prefs;

  Future<ScopedPreferences> get _instance async =>
      _prefs ??= await ScopedPreferences.getInstance(scope: _scope);

  Future<List<TemplateFolder>> getFolders() async {
    final prefs = await _instance;
    final raw = prefs.getString(_foldersKey);
    if (raw == null || raw.isEmpty) {
      final defaults = _defaultFolders;
      return defaults;
    }
    final decoded = (jsonDecode(raw) as List<dynamic>)
        .map((item) => TemplateFolder.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    decoded.sort((a, b) => a.order.compareTo(b.order));
    return decoded;
  }

  Future<List<MealTemplate>> getTemplates() async {
    final prefs = await _instance;
    final raw = prefs.getString(_templatesKey);
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((item) => MealTemplate.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> add(MealTemplate template, {bool onlyIfMissing = false}) =>
      NutritionWrites.run('templates:$_scope', () async {
        final templates = await getTemplates();
        final old = templates
            .where((item) => item.id == template.id)
            .firstOrNull;
        if (onlyIfMissing && old != null) {
          if (nutritionDataEqual(old.toJson(), template.toJson())) return;
          throw StateError('La receta ya existe con otros datos.');
        }
        templates.removeWhere((item) => item.id == template.id);
        templates.insert(0, template);
        await _saveTemplates(templates);
      });

  Future<void> update(MealTemplate template) => add(template);

  Future<void> delete(String id) =>
      NutritionWrites.run('templates:$_scope', () async {
        final templates = await getTemplates();
        templates.removeWhere((item) => item.id == id);
        await _saveTemplates(templates);
      });

  Future<void> moveToFolder(String templateId, String? folderId) =>
      NutritionWrites.run('templates:$_scope', () async {
        final templates = await getTemplates();
        final index = templates.indexWhere((item) => item.id == templateId);
        if (index < 0) return;
        templates[index] = templates[index].copyWith(
          folderId: folderId,
          clearFolderId: folderId == null,
        );
        await _saveTemplates(templates);
      });

  Future<void> toggleFavorite(String templateId) =>
      NutritionWrites.run('templates:$_scope', () async {
        final templates = await getTemplates();
        final index = templates.indexWhere((item) => item.id == templateId);
        if (index < 0) return;
        final current = templates[index];
        templates[index] = current.copyWith(isFavorite: !current.isFavorite);
        await _saveTemplates(templates);
      });

  Future<void> addFolder(TemplateFolder folder, {bool onlyIfMissing = false}) =>
      NutritionWrites.run('templates:$_scope', () async {
        final folders = await getFolders();
        final old = folders.where((f) => f.id == folder.id).firstOrNull;
        if (onlyIfMissing && old != null) {
          if (nutritionDataEqual(old.toJson(), folder.toJson())) return;
          throw StateError('La carpeta ya existe con otros datos.');
        }
        folders.add(folder);
        await _saveFolders(folders);
      });

  Future<void> renameFolder(String id, String name) =>
      NutritionWrites.run('templates:$_scope', () async {
        final folders = await getFolders();
        final index = folders.indexWhere((folder) => folder.id == id);
        if (index < 0) return;
        final item = folders[index];
        folders[index] = TemplateFolder(
          id: item.id,
          name: name,
          icon: item.icon,
          isDefault: item.isDefault,
          order: item.order,
        );
        await _saveFolders(folders);
      });

  Future<void> _saveFolders(List<TemplateFolder> folders) async {
    final prefs = await _instance;
    await prefs.setString(
      _foldersKey,
      jsonEncode(folders.map((f) => f.toJson()).toList()),
    );
  }

  Future<void> _saveTemplates(List<MealTemplate> templates) async {
    final prefs = await _instance;
    await prefs.setString(
      _templatesKey,
      jsonEncode(templates.map((t) => t.toJson()).toList()),
    );
  }

  List<TemplateFolder> get _defaultFolders => const [
    TemplateFolder(
      id: 'breakfast',
      name: 'Desayunos',
      isDefault: true,
      order: 1,
    ),
    TemplateFolder(id: 'lunch', name: 'Almuerzos', isDefault: true, order: 2),
    TemplateFolder(id: 'dinner', name: 'Cenas', isDefault: true, order: 3),
  ];
}
