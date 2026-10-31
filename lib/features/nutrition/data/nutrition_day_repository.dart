import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/account_storage_scope.dart';
import '../../../core/data/repositories.dart';
import '../../../core/domain/entities.dart' as core;
import '../domain/models.dart';
import 'nutrition_writes.dart';
part 'nutrition_workspace.dart';

class NutritionGoal {
  const NutritionGoal({this.kcal, this.protein, this.carbs, this.fat});
  final double? kcal, protein, carbs, fat;
}

class NutritionDaySummary {
  const NutritionDaySummary({
    required this.consumed,
    required this.goal,
    required this.byMealType,
    this.projectionPending = false,
  });
  final MacroValues consumed;
  final NutritionGoal goal;
  final Map<MealType, MacroValues> byMealType;
  final bool projectionPending;
  int? get remainingKcal => goal.kcal == null || consumed.kcal == null
      ? null
      : (goal.kcal! - consumed.kcal!).round();
}

class RecentNutritionItem {
  const RecentNutritionItem({
    required this.id,
    required this.title,
    required this.mealType,
    required this.kcal,
    required this.at,
    this.macros,
  });
  final String id, title;
  final MealType mealType;
  final int kcal;
  final DateTime at;
  final MacroValues? macros;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'mealType': mealType.name,
    'kcal': kcal,
    'at': at.toIso8601String(),
    if (macros != null) 'macros': macros!.toJson(),
  };
  factory RecentNutritionItem.fromJson(Map<String, dynamic> json) =>
      RecentNutritionItem(
        id: json['id'] as String,
        title: json['title'] as String,
        mealType: MealType.values.byName(json['mealType'] as String),
        kcal: (json['kcal'] as num).round(),
        at: DateTime.parse(json['at'] as String),
        macros: json['macros'] is Map
            ? MacroValues.fromJson(
                Map<String, dynamic>.from(json['macros'] as Map),
              )
            : null,
      );
}

/// The single rich consumption journal. fit_meals is its Home/sync projection.
class NutritionDayRepository {
  NutritionDayRepository({
    SharedPreferences? prefs,
    String? scope,
    this._fitness,
  }) : scope = scope ?? AccountStorageScope.current,
       _rawPrefs = prefs;
  static const boxName = 'fit_nutrition_journal_v2';
  static const legacyDayKey = 'nutrition.day_logs.v1';
  static const legacyRecentKey = 'nutrition.recent.v1';
  final String scope;
  final SharedPreferences? _rawPrefs;
  final FitnessRepository? _fitness;
  bool projectionPending = false;
  Future<ScopedPreferences> _prefs() async => _rawPrefs == null
      ? ScopedPreferences.getInstance(scope: scope)
      : ScopedPreferences(_rawPrefs, scope: scope);
  Future<T> _run<T>(Future<T> Function(Box<String>) action) =>
      NutritionWrites.run('diary:$scope', () async {
        final box = await Hive.openBox<String>(
          AccountStorageScope.boxName(boxName, scope),
        );
        final version = box.get('__legacy_v1_complete');
        if (version == null) {
          await _migrate(box);
        } else if (version != '2') {
          throw const FormatException(
            'Versión del diario no compatible. Se conserva sin modificar.',
          );
        }
        return action(box);
      });
  static MacroValues _macros(Object? raw, {bool allowUnknown = true}) {
    if (raw is! Map ||
        ['kcal', 'protein', 'carbs', 'fat'].any(
          (k) =>
              !raw.containsKey(k) ||
              (raw[k] == null
                  ? !allowUnknown
                  : (raw[k] is! num ||
                        !(raw[k] as num).isFinite ||
                        (raw[k] as num) < 0)),
        )) {
      throw const FormatException(
        'Nutrientes incompletos o inválidos. El original se conserva.',
      );
    }
    return MacroValues.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<void> _migrate(Box<String> box) async {
    final raw = (await _prefs()).getString(legacyDayKey);
    if (raw != null) {
      final days = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      for (final day in days.entries) {
        final rows = day.value as List;
        for (var i = 0; i < rows.length; i++) {
          final old = Map<String, dynamic>.from(rows[i] as Map);
          final id = old['id'] as String? ?? 'nutrition-v1-${day.key}-$i';
          _macros(old['macros'], allowUnknown: false);
          final date = DateTime.parse(old['createdAt'] as String);
          final type = MealType.values.byName(old['mealType'] as String);
          for (final e in (old['entries'] as List? ?? const [])) {
            DraftEntry.fromJson(Map<String, dynamic>.from(e as Map));
          }
          if (!box.containsKey(id)) {
            await box.put(
              id,
              jsonEncode({
                ...old,
                'id': id,
                'schemaVersion': 2,
                'date': date.toIso8601String(),
                'title': old['templateName'] ?? mealTypeLabel(type),
                'entries': old['entries'] ?? [],
                'method': 'legacy',
                'sourceId': old['templateId'],
                'projected': false,
              }),
            );
          }
        }
      }
    }
    // Last write commits migration. The original preference is never removed.
    await box.put('__legacy_v1_complete', '2');
  }

  List<Map<String, dynamic>> _rows(Box<String> box) => [
    for (final key in box.keys)
      if (!key.toString().startsWith('__')) _decodeRow(box.get(key)!),
  ];
  Map<String, dynamic> _decodeRow(String raw) {
    final row = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    if (row['schemaVersion'] != 2 && row['schemaVersion'] != 3) {
      throw const FormatException(
        'Versión de comida no compatible. Se conserva sin modificar.',
      );
    }
    return row;
  }

  LoggedMeal _meal(Map<String, dynamic> row) => LoggedMeal(
    id: row['id'] as String,
    date: DateTime.parse(row['date'] as String),
    mealType: MealType.values.byName(row['mealType'] as String),
    entries: (row['entries'] as List)
        .map((e) => DraftEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    snapshot: _macros(row['macros']),
    title: row['title'] as String?,
    sourceId: row['sourceId'] as String?,
    method: row['method'] as String? ?? 'manual',
  );
  Future<void> _reconcile(Box<String> box) async {
    final fitness = _fitness;
    if (fitness == null) {
      projectionPending = _rows(box).any((r) => r['projected'] != true);
      return;
    }
    final projections = await fitness.getMealProjections();
    final byId = {for (final m in projections) m.id: m};
    // Adopt older core-only entries by stable ID, never guessed titles or dates.
    for (final e in projections) {
      if (e.deleted || box.containsKey(e.id)) continue;
      await box.put(
        e.id,
        jsonEncode({
          'schemaVersion': 2,
          'id': e.id,
          'date': e.recordedAt.toIso8601String(),
          'createdAt': e.meta.createdAt.toIso8601String(),
          'title': e.title,
          'mealType': MealType.snack.name,
          'entries': [],
          'method': 'legacyCore',
          'macros': {
            'kcal': e.unknownNutrients.contains('kcal') ? null : e.energyKcal,
            'protein': e.unknownNutrients.contains('protein')
                ? null
                : e.proteinGrams,
            'carbs': e.unknownNutrients.contains('carbs')
                ? null
                : e.carbohydrateGrams,
            'fat': e.unknownNutrients.contains('fat') ? null : e.fatGrams,
          },
          'projected': true,
        }),
      );
    }
    projectionPending = false;
    for (final row in _rows(box)) {
      if (row['projected'] == true) continue;
      try {
        await _project(box, row, byId[row['id']]);
      } catch (_) {
        projectionPending = true;
      }
    }
  }

  Future<void> _project(
    Box<String> box,
    Map<String, dynamic> row,
    core.MealEntry? existing,
  ) async {
    final fitness = _fitness;
    if (fitness == null) {
      projectionPending = true;
      return;
    }
    final meal = _meal(row);
    final created = DateTime.parse(row['createdAt'] as String);
    if (row['deleted'] == true) {
      if (existing != null && !existing.deleted) {
        if (jsonEncode(existing.toJson()) !=
            jsonEncode(row['expectedProjection'])) {
          throw StateError('Conflicto al eliminar. Se conserva el original.');
        }
        await fitness.saveMeal(existing.markDeleted());
      }
      await box.put(meal.id, jsonEncode({...row, 'projected': true}));
      return;
    }
    if (existing != null) {
      final macros = meal.totals.toCoreMacros();
      if (existing.title != (meal.title ?? mealTypeLabel(meal.mealType)) ||
          existing.calories != (meal.totals.kcal?.round() ?? 0) ||
          existing.macros.protein != macros.protein ||
          existing.macros.carbs != macros.carbs ||
          existing.macros.fat != macros.fat ||
          (existing.nutritionSnapshot != null &&
              ((existing.unknownNutrients.contains('kcal')
                          ? null
                          : existing.energyKcal) !=
                      meal.totals.kcal ||
                  (existing.unknownNutrients.contains('protein')
                          ? null
                          : existing.proteinGrams) !=
                      meal.totals.protein ||
                  (existing.unknownNutrients.contains('carbs')
                          ? null
                          : existing.carbohydrateGrams) !=
                      meal.totals.carbs ||
                  (existing.unknownNutrients.contains('fat')
                          ? null
                          : existing.fatGrams) !=
                      meal.totals.fat)) ||
          existing.recordedAt != meal.date ||
          existing.deleted) {
        if (row['projectionUpdate'] != true ||
            jsonEncode(existing.toJson()) !=
                jsonEncode(row['expectedProjection'])) {
          throw StateError(
            'Conflicto con un registro existente. No se sobrescribió.',
          );
        }
        await fitness.saveMeal(
          existing.copyWith(
            title: meal.title,
            calories: meal.totals.kcal?.round() ?? 0,
            macros: meal.totals.toCoreMacros(),
            nutritionSnapshot: meal.totals.toJson().cast<String, num?>(),
            meta: existing.meta.touched().copyWith(deleted: false),
          ),
        );
      }
      await box.put(meal.id, jsonEncode({...row, 'projected': true}));
      return;
    }
    await fitness.saveMeal(
      core.MealEntry(
        id: meal.id,
        title: meal.title ?? mealTypeLabel(meal.mealType),
        consumedAt: meal.date,
        nutritionSnapshot: Map<String, num?>.unmodifiable(
          meal.totals.toJson().cast<String, num?>(),
        ),
        calories: (meal.totals.kcal?.round() ?? 0),
        macros: meal.totals.toCoreMacros(),
        template: meal.sourceId,
        meta: core.EntityMeta(
          createdAt: created,
          updatedAt: created,
          deleted: false,
          revision: 1,
        ),
      ),
    );
    await box.put(meal.id, jsonEncode({...row, 'projected': true}));
  }

  Future<void> recover() => _run(_reconcile);
  Future<List<LoggedMeal>> listMeals() => _run((box) async {
    await _reconcile(box);
    return _rows(box).where((r) => r['deleted'] != true).map(_meal).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  });
  Future<NutritionDaySummary> getTodaySummary() => getSummary(DateTime.now());
  Future<NutritionDaySummary> getSummary(DateTime date) => _run((box) async {
    await _reconcile(box);
    var total = MacroValues.zero;
    final byMeal = {for (final type in MealType.values) type: MacroValues.zero};
    for (final meal in _rows(
      box,
    ).where((r) => r['deleted'] != true).map(_meal)) {
      if (_day(meal.date) != _day(date)) continue;
      total = total + meal.totals;
      byMeal[meal.mealType] = byMeal[meal.mealType]! + meal.totals;
    }
    final kcal = (await _fitness?.getPreferences())?.targetCalories;
    return NutritionDaySummary(
      consumed: total,
      goal: _goalFor(box, date, kcal),
      byMealType: byMeal,
      projectionPending: projectionPending,
    );
  });
  Future<void> _save(
    Box<String> box,
    LoggedMeal meal, {
    Map<String, dynamic>? template,
  }) async {
    for (final entry in meal.entries) {
      validateNutritionEntry(entry);
      if (!entry.quantity.isFinite ||
          entry.quantity <= 0 ||
          !entry.food.supportsUnit(entry.unit) ||
          (entry.gramsOverride != null && entry.gramsOverride! <= 0) ||
          (entry.unit == FoodUnit.ml && entry.food.macrosPer100ml == null)) {
        throw const FormatException(
          'La cantidad o equivalencia no está confirmada. No se registró la comida.',
        );
      }
      _macros(entry.computedMacros.toJson());
    }
    final snapshot = meal.totals;
    _macros(snapshot.toJson());
    final payload = {
      'schemaVersion': 3,
      'id': meal.id,
      'date': meal.date.toIso8601String(),
      'mealType': meal.mealType.name,
      'title': meal.title ?? mealTypeLabel(meal.mealType),
      'entries': meal.entries.map((e) => e.toJson()).toList(),
      'macros': snapshot.toJson(),
      'sourceId': meal.sourceId,
      'method': meal.method,
    };
    final existing = box.get(meal.id);
    if (existing != null) {
      final row = Map<String, dynamic>.from(jsonDecode(existing) as Map);
      if (payload.keys.any(
        (k) => jsonEncode(row[k]) != jsonEncode(payload[k]),
      )) {
        throw StateError(
          'Identificador de comida ya utilizado. No se sobrescribió el registro.',
        );
      }
    } else {
      await box.put(
        meal.id,
        jsonEncode({
          ...payload,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'utcOffsetMinutes': meal.date.timeZoneOffset.inMinutes,
          'utcDate': meal.date.toUtc().toIso8601String(),
          'templateSnapshot': ?template,
          'projected': false,
        }),
      );
    }
    // Canonical write has succeeded. Projection failures remain durable and visible.
    try {
      await _reconcile(box);
    } catch (_) {
      projectionPending = true;
    }
  }

  Future<void> logMeal(LoggedMeal meal) => _run((box) => _save(box, meal));
  Future<void> addTemplateToToday(
    MealTemplate template, {
    MealType? mealType,
    DateTime? date,
  }) => _run(
    (box) => _save(
      box,
      LoggedMeal(
        date: date ?? DateTime.now(),
        mealType: mealType ?? template.mealType ?? MealType.snack,
        entries: template.entries,
        snapshot: template.effectiveTotals,
        title: template.name,
        sourceId: template.id,
        method: 'template',
      ),
      template: template.toJson(),
    ),
  );
  Future<LoggedMeal?> getLastLoggedMeal(MealType type) async =>
      (await listMeals())
          .where((m) => m.mealType == type && m.entries.isNotEmpty)
          .firstOrNull;
  Future<List<RecentNutritionItem>> getRecents() => _run((box) async {
    final rows = _rows(box).where((r) => r['deleted'] != true).toList()
      ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    final result = [
      for (final row in rows.take(8))
        RecentNutritionItem(
          id: row['id'] as String,
          title: row['title'] as String,
          mealType: MealType.values.byName(row['mealType'] as String),
          kcal: (_macros(row['macros']).kcal?.round() ?? 0),
          macros: _macros(row['macros']),
          at: DateTime.parse(row['date'] as String),
        ),
    ];
    if (result.isEmpty) {
      final raw = (await _prefs()).getString(legacyRecentKey);
      if (raw != null) {
        return (jsonDecode(raw) as List)
            .map(
              (e) => RecentNutritionItem.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      }
    }
    return result;
  });
  Future<void> duplicateRecent(RecentNutritionItem item, {DateTime? date}) =>
      _run((box) async {
        final row = _rows(box).where((r) => r['id'] == item.id).firstOrNull;
        if (row == null) {
          throw StateError(
            'No están los nutrientes originales. Elegí una plantilla o alimento para confirmar su composición.',
          );
        }
        final old = _meal(row);
        await _save(
          box,
          LoggedMeal(
            date: date ?? DateTime.now(),
            mealType: old.mealType,
            entries: old.entries,
            snapshot: old.totals,
            title: old.title,
            sourceId: old.id,
            method: 'repeat',
          ),
        );
      });
  String _day(DateTime d) => '${d.year}-${d.month}-${d.day}';
}
