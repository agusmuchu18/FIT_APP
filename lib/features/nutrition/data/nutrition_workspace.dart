part of 'nutrition_day_repository.dart';

/// Snapshot of a plan. Planning never creates consumed nutrition implicitly.
class PlannedNutritionMeal {
  const PlannedNutritionMeal({
    required this.id,
    required this.date,
    required this.mealType,
    required this.template,
    this.consumed = false,
  });
  final String id;
  final DateTime date;
  final MealType mealType;
  final MealTemplate template;
  final bool consumed;
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'mealType': mealType.name,
    'template': template.toJson(),
    'consumed': consumed,
  };
  factory PlannedNutritionMeal.fromJson(Map<String, dynamic> j) =>
      PlannedNutritionMeal(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        mealType: MealType.values.byName(j['mealType'] as String),
        template: MealTemplate.fromJson(
          Map<String, dynamic>.from(j['template'] as Map),
        ),
        consumed: j['consumed'] as bool? ?? false,
      );
}

extension NutritionWorkspace on NutritionDayRepository {
  Future<NutritionGoal> configuredGoal(DateTime date) async {
    final fallback = (await _fitness?.getPreferences())?.targetCalories;
    final name = AccountStorageScope.boxName(
      NutritionDayRepository.boxName,
      scope,
    );
    if (!Hive.isBoxOpen(name)) return NutritionGoal(kcal: fallback?.toDouble());
    return _run((b) async => _goalFor(b, date, fallback));
  }

  Future<bool> professionalMode() =>
      _run((b) async => b.get('__mode') == 'pro');
  Future<void> setProfessionalMode(bool pro) =>
      _run((b) => b.put('__mode', pro ? 'pro' : 'lite'));

  Future<void> saveGoal(DateTime effective, MacroValues goal) => _run((
    b,
  ) async {
    NutritionDayRepository._macros(goal.toJson());
    if (goal.kcal != null && goal.kcal! <= 0) {
      throw const FormatException(
        'La meta de energía debe ser positiva o estar vacía.',
      );
    }
    final previous = b.get('__goal:${_day(effective)}');
    if (previous != null) {
      final row = Map<String, dynamic>.from(jsonDecode(previous) as Map);
      if (nutritionDataEqual(row['values'], goal.toJson())) return;
      final revisionId = const Uuid().v4();
      await b.put(
        '__goalRevision:$revisionId',
        jsonEncode({...row, 'revisionId': revisionId}),
      );
    }
    await b.put(
      '__goal:${_day(effective)}',
      jsonEncode({
        'date': DateTime(
          effective.year,
          effective.month,
          effective.day,
        ).toIso8601String(),
        'values': goal.toJson(),
        'source': 'manual',
      }),
    );
    // Notify existing Home consumers. The dated journal remains authoritative.
    _fitness?.mealsRevision.value++;
  });
  Future<List<Map<String, dynamic>>> goalHistory() => _run(
    (b) async => [
      ..._metadata(b, '__goal:'),
      ..._metadata(b, '__goalRevision:'),
    ]..sort((a, c) => (a['date'] as String).compareTo(c['date'] as String)),
  );

  Future<List<PlannedNutritionMeal>> plans() => _run(
    (b) async =>
        _metadata(b, '__plan:').map(PlannedNutritionMeal.fromJson).toList()
          ..sort((a, c) => a.date.compareTo(c.date)),
  );
  Future<void> plan(PlannedNutritionMeal meal) => _run((b) async {
    validateNutritionTemplate(meal.template);
    if (meal.id.isEmpty || meal.template.entries.isEmpty) {
      throw const FormatException('Elegí una receta con ingredientes.');
    }
    NutritionDayRepository._macros(meal.template.effectiveTotals.toJson());
    final key = '__plan:${meal.id}';
    if (b.containsKey(key)) throw StateError('El plan ya existe.');
    await b.put(key, jsonEncode(meal.toJson()));
  });
  Future<void> removePlan(String id) => _run((b) async {
    if (b.containsKey('__plan:$id')) {
      await b.put('__removedPlan:$id', b.get('__plan:$id')!);
    }
    await b.delete('__plan:$id');
  });
  Future<void> consumePlan(String id) => _run((b) async {
    final raw = b.get('__plan:$id');
    if (raw == null) throw StateError('El plan ya no está disponible.');
    final p = PlannedNutritionMeal.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
    if (p.consumed) return;
    await _save(
      b,
      LoggedMeal(
        id: 'nutrition-plan:$id',
        date: p.date,
        mealType: p.mealType,
        entries: p.template.entries,
        snapshot: p.template.effectiveTotals,
        title: p.template.name,
        sourceId: p.id,
        method: 'plan-confirmed',
      ),
    );
    await b.put('__plan:$id', jsonEncode({...p.toJson(), 'consumed': true}));
  });
  Future<int> copyPlanWeek(DateTime source, DateTime target) => _run((b) async {
    final from = DateTime.utc(source.year, source.month, source.day),
        to = DateTime.utc(target.year, target.month, target.day);
    if (to.difference(from).inDays.abs() < 7) {
      throw const FormatException(
        'Las semanas de origen y destino no deben superponerse.',
      );
    }
    final all = _metadata(
      b,
      '__plan:',
    ).map(PlannedNutritionMeal.fromJson).toList();
    final additions = <String, PlannedNutritionMeal>{};
    for (final p in all) {
      final day = DateTime.utc(p.date.year, p.date.month, p.date.day),
          offset = DateTime.utc(
            p.date.year,
            p.date.month,
            p.date.day,
          ).difference(from).inDays;
      if (day.isBefore(from) || offset >= 7) continue;
      final date = DateTime(
        target.year,
        target.month,
        target.day + offset,
        p.date.hour,
        p.date.minute,
      );
      final id = 'copy:${p.id}:${to.toIso8601String()}';
      final copied = PlannedNutritionMeal(
        id: id,
        date: date,
        mealType: p.mealType,
        template: p.template,
      );
      final old = b.get('__plan:$id');
      if (old != null &&
          !nutritionDataEqual({
            ...Map<String, dynamic>.from(jsonDecode(old) as Map),
            'consumed': false,
          }, copied.toJson())) {
        throw StateError('La semana de destino ya tiene una copia diferente.');
      }
      if (old == null) additions[id] = copied;
    }
    for (final p in additions.values) {
      await b.put('__plan:${p.id}', jsonEncode(p.toJson()));
    }
    return additions.length;
  });

  Future<Map<String, num>> shoppingList() => _run((b) async {
    final totals = <String, num>{};
    for (final raw in _metadata(b, '__plan:')) {
      final p = PlannedNutritionMeal.fromJson(raw);
      if (p.consumed) continue;
      for (final e in p.template.entries) {
        final unit = e.unit == FoodUnit.ml ? 'ml' : 'g';
        final key = '${e.food.id}|${e.food.name}|$unit';
        totals[key] =
            (totals[key] ?? 0) +
            (e.unit == FoodUnit.ml ? e.quantity : e.effectiveGrams);
      }
    }
    return totals;
  });

  Future<Map<String, dynamic>> dailyNote(DateTime day) => _run(
    (b) async => b.get('__note:${_day(day)}') == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(
            jsonDecode(b.get('__note:${_day(day)}')!) as Map,
          ),
  );
  Future<void> saveDailyNote(
    DateTime day, {
    required String note,
    required String supplements,
  }) => _run((b) async {
    if (note.length > 4000 || supplements.length > 2000) {
      throw const FormatException('El texto es demasiado largo.');
    }
    await b.put(
      '__note:${_day(day)}',
      jsonEncode({
        'note': note,
        'supplements': supplements,
        'date': day.toIso8601String(),
      }),
    );
  });

  Future<void> editMeal(
    String id, {
    required String title,
    required List<DraftEntry> entries,
    MealType? mealType,
  }) => _run((b) async {
    final raw = b.get(id);
    if (raw == null) throw StateError('Registro no disponible.');
    final row = _decodeRow(raw);
    final old = _meal(row);
    if (row['deleted'] == true) throw StateError('El registro fue eliminado.');
    if ((entries.isEmpty && old.entries.isNotEmpty) || title.trim().isEmpty) {
      throw const FormatException(
        'La comida debe tener nombre e ingredientes.',
      );
    }
    for (final e in entries) {
      if (!e.quantity.isFinite ||
          e.quantity <= 0 ||
          !e.food.supportsUnit(e.unit)) {
        throw const FormatException('Cantidad inválida.');
      }
    }
    final totals = entries.isEmpty
        ? old.totals
        : entries.fold(MacroValues.zero, (sum, e) => sum + e.computedMacros);
    NutritionDayRepository._macros(totals.toJson());
    final expected = (await _fitness?.getMealProjections())
        ?.where((m) => m.id == id)
        .firstOrNull
        ?.toJson();
    final edited = {
      ...row,
      'expectedProjection': expected,
      'schemaVersion': 3,
      'title': title.trim(),
      'mealType': (mealType ?? old.mealType).name,
      'entries': entries.map((e) => e.toJson()).toList(),
      'macros': totals.toJson(),
      'editedAt': DateTime.now().toUtc().toIso8601String(),
      'projected': false,
      'projectionUpdate': true,
    };
    await b.put('__revision:$id:${DateTime.now().microsecondsSinceEpoch}', raw);
    await b.put(id, jsonEncode(edited));
    await _reconcile(b);
    // The journal records the original snapshot separately; no old IDs change.
    assert(old.id == id);
  });
  Future<void> deleteMeal(String id) => _run((b) async {
    final raw = b.get(id);
    if (raw == null) return;
    final row = _decodeRow(raw);
    final expected = (await _fitness?.getMealProjections())
        ?.where((m) => m.id == id)
        .firstOrNull
        ?.toJson();
    await b.put(
      id,
      jsonEncode({
        ...row,
        'expectedProjection': expected,
        'deleted': true,
        'projected': false,
      }),
    );
    await _reconcile(b);
  });
  Future<void> restoreMeal(String id) => _run((b) async {
    final raw = b.get(id);
    if (raw == null) return;
    final row = _decodeRow(raw);
    if (row['deleted'] != true) return;
    final expected = (await _fitness?.getMealProjections())
        ?.where((m) => m.id == id)
        .firstOrNull
        ?.toJson();
    await b.put(
      id,
      jsonEncode({
        ...row,
        'expectedProjection': expected,
        'deleted': false,
        'projected': false,
        'projectionUpdate': true,
      }),
    );
    await _reconcile(b);
  });

  Future<bool> fastingEnabled() =>
      _run((b) async => b.get('__fastEnabled') == 'true');
  Future<void> setFastingEnabled(bool enabled) => _run((b) async {
    if (!enabled && _metadata(b, '__fast:').any((f) => f['end'] == null)) {
      throw StateError('Finalizá primero el registro activo.');
    }
    await b.put('__fastEnabled', enabled.toString());
  });
  Future<List<Map<String, dynamic>>> fastingHistory() => _run(
    (b) async => _metadata(b, '__fast:')
      ..sort((a, c) => (c['start'] as String).compareTo(a['start'] as String)),
  );
  Future<void> startFast({DateTime? now}) => _run((b) async {
    if (b.get('__fastEnabled') != 'true') {
      throw StateError('El registro opcional no está habilitado.');
    }
    if (_metadata(b, '__fast:').any((f) => f['end'] == null)) return;
    final start = (now ?? DateTime.now()).toUtc();
    await b.put(
      '__fast:${start.microsecondsSinceEpoch}',
      jsonEncode({
        'start': start.toIso8601String(),
        'end': null,
        'source': 'manual',
      }),
    );
  });
  Future<void> finishFast({DateTime? now}) => _run((b) async {
    final row = _metadata(
      b,
      '__fast:',
    ).where((f) => f['end'] == null).firstOrNull;
    if (row == null) return;
    final start = DateTime.parse(row['start'] as String),
        end = (now ?? DateTime.now()).toUtc();
    if (end.isBefore(start)) {
      throw const FormatException(
        'La finalización no puede ser anterior al inicio.',
      );
    }
    await b.put(
      '__fast:${start.microsecondsSinceEpoch}',
      jsonEncode({...row, 'end': end.toIso8601String()}),
    );
  });

  Future<({int added, int duplicates, int conflicts})> inspectMetadata(
    Map<String, dynamic> packet,
  ) => _run((b) async {
    final entries = _validatedMetadata(packet);
    var added = 0, duplicates = 0, conflicts = 0;
    for (final e in entries.entries) {
      final old = b.get(e.key);
      if (old == null) {
        added++;
      } else if (nutritionDataEqual(jsonDecode(old), e.value)) {
        duplicates++;
      } else {
        conflicts++;
      }
    }
    final active = _metadata(
      b,
      '__fast:',
    ).where((r) => r['end'] == null).firstOrNull;
    if (active != null &&
        entries.entries.any(
          (e) =>
              e.key.startsWith('__fast:') &&
              (e.value as Map)['end'] == null &&
              !nutritionDataEqual(e.value, active),
        )) {
      conflicts++;
    }
    return (added: added, duplicates: duplicates, conflicts: conflicts);
  });
  Future<int> importMetadata(Map<String, dynamic> packet) => _run((b) async {
    final entries = _validatedMetadata(packet);
    for (final e in entries.entries) {
      final old = b.get(e.key);
      if (old != null && !nutritionDataEqual(jsonDecode(old), e.value)) {
        throw StateError('Configuración en conflicto.');
      }
    }
    final active = _metadata(
      b,
      '__fast:',
    ).where((r) => r['end'] == null).firstOrNull;
    if (active != null &&
        entries.entries.any(
          (e) =>
              e.key.startsWith('__fast:') &&
              (e.value as Map)['end'] == null &&
              !nutritionDataEqual(e.value, active),
        )) {
      throw StateError('Ya hay una ventana de ayuno activa.');
    }
    var count = 0;
    for (final e in entries.entries) {
      if (!b.containsKey(e.key)) {
        await b.put(e.key, jsonEncode(e.value));
        count++;
      }
    }
    return count;
  });
  Map<String, Object?> _validatedMetadata(Map<String, dynamic> packet) {
    final entries = <String, Object?>{};
    for (final raw in (packet['goals'] as List? ?? [])) {
      final row = Map<String, dynamic>.from(raw as Map);
      final date = DateTime.parse(row['date'] as String);
      final values = NutritionDayRepository._macros(row['values']);
      if (values.kcal != null && values.kcal! <= 0) {
        throw const FormatException('Meta inválida.');
      }
      _metadataInsert(entries, '__goal:${_day(date)}', row);
    }
    for (final raw in (packet['goalRevisions'] as List? ?? [])) {
      final row = Map<String, dynamic>.from(raw as Map);
      DateTime.parse(row['date'] as String);
      final values = NutritionDayRepository._macros(row['values']);
      final id = row['revisionId'] as String;
      if (id.isEmpty || (values.kcal != null && values.kcal! <= 0)) {
        throw const FormatException('Revisión de meta inválida.');
      }
      _metadataInsert(entries, '__goalRevision:$id', row);
    }
    for (final raw in (packet['plans'] as List? ?? [])) {
      final row = Map<String, dynamic>.from(raw as Map);
      final plan = PlannedNutritionMeal.fromJson(row);
      validateNutritionTemplate(plan.template);
      if (plan.id.isEmpty) throw const FormatException('ID de plan inválido.');
      _metadataInsert(entries, '__plan:${plan.id}', row);
    }
    for (final raw in (packet['notes'] as List? ?? [])) {
      final row = Map<String, dynamic>.from(raw as Map);
      final date = DateTime.parse(row['date'] as String);
      if ((row['note'] as String).length > 4000 ||
          (row['supplements'] as String).length > 2000) {
        throw const FormatException('Nota inválida.');
      }
      _metadataInsert(entries, '__note:${_day(date)}', row);
    }
    var active = 0;
    for (final raw in (packet['fasts'] as List? ?? [])) {
      final row = Map<String, dynamic>.from(raw as Map);
      final start = DateTime.parse(row['start'] as String),
          end = row['end'] == null
              ? null
              : DateTime.parse(row['end'] as String);
      if (end != null && end.isBefore(start)) {
        throw const FormatException('Ventana inválida.');
      }
      if (end == null) active++;
      _metadataInsert(entries, '__fast:${start.microsecondsSinceEpoch}', row);
    }
    if (active > 1 || entries.length > 10000) {
      throw const FormatException('Configuración no compatible.');
    }
    return entries;
  }

  Future<String> exportJournal() => _run(
    (b) async => jsonEncode({
      'format': 'FIT_APP_NUTRITION',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'rows': [
        for (final key in b.keys)
          if (!key.toString().startsWith('__')) _decodeRow(b.get(key)!),
      ],
      'goals': _metadata(b, '__goal:'),
      'goalRevisions': _metadata(b, '__goalRevision:'),
      'fasts': _metadata(b, '__fast:'),
      'plans': _metadata(b, '__plan:'),
      'notes': _metadata(b, '__note:'),
    }),
  );

  Future<({int added, int duplicates, int conflicts})> inspectImport(
    String text,
  ) => _run((b) async {
    final data = _validateImport(text);
    var added = 0, duplicates = 0, conflicts = 0;
    for (final row in data) {
      final existing = b.get(row['id']);
      if (existing == null) {
        added++;
      } else if (_sameImportedRow(_decodeRow(existing), row)) {
        duplicates++;
      } else {
        conflicts++;
      }
    }
    return (added: added, duplicates: duplicates, conflicts: conflicts);
  });
  Future<int> importJournal(String text) => _run((b) async {
    final rows = _validateImport(text);
    // Check the complete packet before the first write. Retry after I/O failure
    // is idempotent; conflicting originals are never overwritten.
    for (final row in rows) {
      final current = b.get(row['id']);
      if (current != null && !_sameImportedRow(_decodeRow(current), row)) {
        throw StateError('Hay IDs en conflicto. No se sobrescribieron datos.');
      }
    }
    var added = 0;
    for (final row in rows) {
      if (!b.containsKey(row['id'])) {
        await b.put(row['id'], jsonEncode({...row, 'projected': false}));
        added++;
      }
    }
    await _reconcile(b);
    return added;
  });
  List<Map<String, dynamic>> _validateImport(String text) {
    if (text.length > 5000000) {
      throw const FormatException('El archivo supera el límite de 5 MB.');
    }
    final j = Map<String, dynamic>.from(jsonDecode(text) as Map);
    if (j['format'] != 'FIT_APP_NUTRITION' ||
        j['version'] != 1 ||
        j['rows'] is! List ||
        (j['rows'] as List).length > 10000) {
      throw const FormatException('Formato o versión no compatible.');
    }
    final ids = <String>{};
    return [
      for (final raw in j['rows'] as List) _validateImportedRow(raw, ids),
    ];
  }

  Map<String, dynamic> _validateImportedRow(Object? raw, Set<String> ids) {
    final row = _decodeRow(jsonEncode(raw));
    final meal = _meal(row);
    if (meal.id.isEmpty || meal.id.startsWith('__') || !ids.add(meal.id)) {
      throw const FormatException('Identificador inválido o duplicado.');
    }
    DateTime.parse(row['createdAt'] as String);
    for (final e in meal.entries) {
      validateNutritionEntry(e);
      if (!e.quantity.isFinite ||
          e.quantity <= 0 ||
          !e.food.supportsUnit(e.unit)) {
        throw const FormatException('Cantidad no válida.');
      }
    }
    return {...row, 'projectionUpdate': false, 'expectedProjection': null};
  }

  bool _sameImportedRow(Map<String, dynamic> a, Map<String, dynamic> c) => [
    'id',
    'date',
    'title',
    'entries',
    'macros',
    'mealType',
    'deleted',
  ].every((k) => nutritionDataEqual(a[k], c[k]));
}

List<Map<String, dynamic>> _metadata(Box<String> b, String prefix) => [
  for (final key in b.keys)
    if (key.toString().startsWith(prefix))
      Map<String, dynamic>.from(jsonDecode(b.get(key)!) as Map),
];
NutritionGoal _goalFor(Box<String> b, DateTime date, int? fallback) {
  final rows =
      _metadata(b, '__goal:')
          .where(
            (g) =>
                !DateTime.parse(g['date'] as String)
                    .isAfter(DateTime(date.year, date.month, date.day)),
          )
          .toList()
        ..sort((a, c) => (c['date'] as String).compareTo(a['date'] as String));
  if (rows.isEmpty) {
    final now = DateTime.now();
    if (date.year != now.year ||
        date.month != now.month ||
        date.day != now.day) {
      return const NutritionGoal();
    }
    return NutritionGoal(
      kcal: fallback != null && fallback > 0 ? fallback.toDouble() : null,
    );
  }
  final m = NutritionDayRepository._macros(rows.first['values']);
  return NutritionGoal(
    kcal: m.kcal,
    protein: m.protein,
    carbs: m.carbs,
    fat: m.fat,
  );
}

void _metadataInsert(Map<String, Object?> entries, String key, Object? row) {
  if (entries.containsKey(key)) {
    throw const FormatException('Metadatos duplicados.');
  }
  entries[key] = row;
}
