import 'dart:convert';

import '../domain/models.dart';
import 'food_repository.dart';
import 'templates_repository.dart';
import 'nutrition_day_repository.dart';
import 'nutrition_writes.dart';

class NutritionImportPreview {
  const NutritionImportPreview(this.added, this.duplicates, this.conflicts);
  final int added, duplicates, conflicts;
}

/// Coordinates the existing stores; it is not another nutrition repository.
/// Writes are add-only. A failed device write can be retried with the same file.
class NutritionBackupService {
  NutritionBackupService({
    required this.days,
    required this.foods,
    required this.templates,
  }) {
    if (days.scope != foods.storageScope ||
        days.scope != templates.storageScope) {
      throw ArgumentError(
        'Los repositorios deben pertenecer a la misma cuenta.',
      );
    }
  }
  final NutritionDayRepository days;
  final FoodRepository foods;
  final TemplatesRepository templates;
  Future<String> exportData() async {
    final diary = Map<String, dynamic>.from(
      jsonDecode(await days.exportJournal()) as Map,
    );
    diary['fasts'] = await days.fastingHistory();
    return jsonEncode({
      'format': 'FIT_APP_NUTRITION_BACKUP',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'journal': diary,
      'foods': (await foods.loadLocalCatalog())
          .where((f) => f.isCustom)
          .map((f) => f.toJson())
          .toList(),
      'templates': (await templates.getTemplates())
          .map((t) => t.toJson())
          .toList(),
      'folders': (await templates.getFolders()).map((f) => f.toJson()).toList(),
      'favorites': (await foods.favoriteFoodIds()).toList(),
    });
  }

  Map<String, dynamic> _packet(String text) {
    if (text.length > 5000000) {
      throw const FormatException('La copia supera 5 MB.');
    }
    final p = Map<String, dynamic>.from(jsonDecode(text) as Map);
    if (p['format'] == 'FIT_APP_NUTRITION' && p['version'] == 1) {
      return {
        'journal': p,
        'foods': [],
        'templates': [],
        'folders': [],
        'favorites': [],
      };
    }
    if (p['format'] != 'FIT_APP_NUTRITION_BACKUP' ||
        p['version'] != 1 ||
        p['journal'] is! Map) {
      throw const FormatException('Versión de copia no compatible.');
    }
    for (final k in ['foods', 'templates', 'folders', 'favorites']) {
      if (p[k] is! List || (p[k] as List).length > 10000) {
        throw const FormatException('Lista no válida en la copia.');
      }
    }
    final ids = <String>{};
    for (final raw in p['foods'] as List) {
      final f = FoodItem.fromJson(Map<String, dynamic>.from(raw as Map));
      validateNutritionFood(f);
      if (!f.isCustom || !ids.add('food:${f.id}')) {
        throw const FormatException('ID de alimento duplicado o no personal.');
      }
    }
    for (final raw in p['templates'] as List) {
      final t = MealTemplate.fromJson(Map<String, dynamic>.from(raw as Map));
      validateNutritionTemplate(t);
      if (!ids.add('recipe:${t.id}')) {
        throw const FormatException('ID de receta duplicado.');
      }
    }
    for (final raw in p['folders'] as List) {
      final f = TemplateFolder.fromJson(Map<String, dynamic>.from(raw as Map));
      if (f.id.isEmpty || f.name.trim().isEmpty || !ids.add('folder:${f.id}')) {
        throw const FormatException('Carpeta inválida.');
      }
    }
    for (final id in p['favorites'] as List) {
      if (id is! String || id.isEmpty) {
        throw const FormatException('Favorito inválido.');
      }
    }
    return p;
  }

  Future<NutritionImportPreview> inspect(String text) async {
    final p = _packet(text);
    final journal = Map<String, dynamic>.from(p['journal'] as Map);
    final diary = await days.inspectImport(jsonEncode(journal)),
        meta = await days.inspectMetadata(journal);
    var added = diary.added + meta.added,
        duplicates = diary.duplicates + meta.duplicates,
        conflicts = diary.conflicts + meta.conflicts;
    final currentFoods = {
      for (final f in await foods.loadLocalCatalog()) f.id: f,
    };
    final currentTemplates = {
      for (final t in await templates.getTemplates()) t.id: t,
    };
    final currentFolders = {
      for (final f in await templates.getFolders()) f.id: f,
    };
    void count(Object? old, Object? fresh) {
      if (old == null) {
        added++;
      } else if (nutritionDataEqual(old, fresh)) {
        duplicates++;
      } else {
        conflicts++;
      }
    }

    for (final raw in p['foods'] as List) {
      final f = FoodItem.fromJson(Map<String, dynamic>.from(raw as Map));
      count(currentFoods[f.id]?.toJson(), f.toJson());
    }
    for (final raw in p['templates'] as List) {
      final t = MealTemplate.fromJson(Map<String, dynamic>.from(raw as Map));
      count(currentTemplates[t.id]?.toJson(), t.toJson());
    }
    for (final raw in p['folders'] as List) {
      final f = TemplateFolder.fromJson(Map<String, dynamic>.from(raw as Map));
      count(currentFolders[f.id]?.toJson(), f.toJson());
    }
    return NutritionImportPreview(added, duplicates, conflicts);
  }

  Future<int> importData(String text) =>
      NutritionWrites.run('backup:${days.scope}', () async {
        final p = _packet(text);
        final preview = await inspect(text);
        if (preview.conflicts > 0) {
          throw StateError(
            'La copia tiene conflictos. No se sobrescriben datos.',
          );
        }
        for (final raw in p['foods'] as List) {
          await foods.createCustomFood(
            FoodItem.fromJson(Map<String, dynamic>.from(raw as Map)),
            onlyIfMissing: true,
          );
        }
        for (final raw in p['folders'] as List) {
          await templates.addFolder(
            TemplateFolder.fromJson(Map<String, dynamic>.from(raw as Map)),
            onlyIfMissing: true,
          );
        }
        for (final raw in p['templates'] as List) {
          await templates.add(
            MealTemplate.fromJson(Map<String, dynamic>.from(raw as Map)),
            onlyIfMissing: true,
          );
        }
        final journal = Map<String, dynamic>.from(p['journal'] as Map);
        await days.importJournal(jsonEncode(journal));
        await days.importMetadata(journal);
        final favorites = await foods.favoriteFoodIds();
        for (final id in (p['favorites'] as List).cast<String>()) {
          if (!favorites.contains(id)) {
            await foods.setFavoriteFood(id, true);
          }
        }
        return preview.added;
      });
}
