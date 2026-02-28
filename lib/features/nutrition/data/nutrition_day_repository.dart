import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

class NutritionDaySummary {
  const NutritionDaySummary({
    required this.consumed,
    required this.goal,
    required this.byMealType,
  });

  final MacroValues consumed;
  final MacroValues goal;
  final Map<MealType, MacroValues> byMealType;

  int get remainingKcal => (goal.kcal - consumed.kcal).round();
}

class RecentNutritionItem {
  const RecentNutritionItem({
    required this.id,
    required this.title,
    required this.mealType,
    required this.kcal,
    required this.at,
  });

  final String id;
  final String title;
  final MealType mealType;
  final int kcal;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'mealType': mealType.name,
        'kcal': kcal,
        'at': at.toIso8601String(),
      };

  factory RecentNutritionItem.fromJson(Map<String, dynamic> json) {
    final mealTypeName = (json['mealType'] ?? MealType.snack.name).toString();
    return RecentNutritionItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Registro').toString(),
      mealType: MealType.values.where((item) => item.name == mealTypeName).isEmpty
          ? MealType.snack
          : MealType.values.firstWhere((item) => item.name == mealTypeName),
      kcal: (json['kcal'] as num? ?? 0).toInt(),
      at: DateTime.tryParse((json['at'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class NutritionDayRepository {
  NutritionDayRepository({SharedPreferences? prefs}) : _prefs = prefs;

  static const _dayLogKey = 'nutrition.day_logs.v1';
  static const _recentKey = 'nutrition.recent.v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async => _prefs ??= await SharedPreferences.getInstance();

  Future<NutritionDaySummary> getTodaySummary() async {
    final map = await _readDayLogs();
    final todayKey = _keyFor(DateTime.now());
    final logs = map[todayKey] ?? const [];
    final byMeal = {for (final type in MealType.values) type: MacroValues.zero};

    MacroValues total = MacroValues.zero;
    for (final log in logs) {
      final macros = MacroValues.fromJson(Map<String, dynamic>.from(log['macros'] as Map));
      total = total + macros;
      final typeName = log['mealType']?.toString() ?? MealType.snack.name;
      final mealType = MealType.values.where((item) => item.name == typeName).isEmpty
          ? MealType.snack
          : MealType.values.firstWhere((item) => item.name == typeName);
      byMeal[mealType] = byMeal[mealType]! + macros;
    }

    // TODO: conectar a objetivos reales del usuario cuando exista source de metas nutricionales.
    const goal = MacroValues(kcal: 2400, protein: 160, carbs: 260, fat: 80);
    return NutritionDaySummary(consumed: total, goal: goal, byMealType: byMeal);
  }

  Future<void> addTemplateToToday(MealTemplate template, {MealType? mealType}) async {
    final logs = await _readDayLogs();
    final todayKey = _keyFor(DateTime.now());
    final list = logs[todayKey] ?? <Map<String, dynamic>>[];

    list.add({
      'mealType': (mealType ?? template.mealType ?? MealType.snack).name,
      'templateId': template.id,
      'templateName': template.name,
      'macros': template.effectiveTotals.toJson(),
      'createdAt': DateTime.now().toIso8601String(),
    });

    logs[todayKey] = list;
    await _saveDayLogs(logs);

    final recents = await getRecents();
    recents.removeWhere((item) => item.id == template.id);
    recents.insert(
      0,
      RecentNutritionItem(
        id: template.id,
        title: template.name,
        mealType: mealType ?? template.mealType ?? MealType.snack,
        kcal: template.effectiveTotals.kcal.round(),
        at: DateTime.now(),
      ),
    );
    await _saveRecents(recents.take(8).toList());
  }

  Future<void> duplicateRecent(RecentNutritionItem item) async {
    final fakeTemplate = MealTemplate(
      id: item.id,
      name: item.title,
      mealType: item.mealType,
      totals: MacroValues(kcal: item.kcal.toDouble(), protein: 0, carbs: 0, fat: 0),
      createdAt: DateTime.now(),
    );
    await addTemplateToToday(fakeTemplate, mealType: item.mealType);
  }

  Future<List<RecentNutritionItem>> getRecents() async {
    final prefs = await _instance;
    final raw = prefs.getString(_recentKey);
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .whereType<Map>()
        .map((item) => RecentNutritionItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, List<Map<String, dynamic>>>> _readDayLogs() async {
    final prefs = await _instance;
    final raw = prefs.getString(_dayLogKey);
    if (raw == null || raw.isEmpty) return {};

    final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    return decoded.map(
      (key, value) => MapEntry(
        key,
        (value as List<dynamic>).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(),
      ),
    );
  }

  Future<void> _saveDayLogs(Map<String, List<Map<String, dynamic>>> logs) async {
    final prefs = await _instance;
    await prefs.setString(_dayLogKey, jsonEncode(logs));
  }

  Future<void> _saveRecents(List<RecentNutritionItem> recents) async {
    final prefs = await _instance;
    await prefs.setString(_recentKey, jsonEncode(recents.map((item) => item.toJson()).toList()));
  }

  String _keyFor(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
