import 'dart:async';

import 'package:flutter/material.dart';

import '../data/food_repository.dart';
import '../domain/models.dart';

class FoodLogController extends ChangeNotifier {
  FoodLogController({required FoodRepository repository}) : _repository = repository {
    _init();
  }

  final FoodRepository _repository;
  final Map<MealType, List<DraftEntry>> _draftByType = {for (final t in MealType.values) t: []};
  final List<FoodItem> _recentFoods = [];

  MealType selectedMealType = MealType.dinner;
  List<FoodItem> results = [];
  List<FoodItem> suggested = [];
  List<MealTemplate> templates = [];
  String query = '';
  String? expandedFoodId;
  bool isPro = false;
  bool didBump = false;
  FoodItem? highlightedFood;

  final Set<String> loadingFoodIds = <String>{};
  String? uiMessage;

  Timer? _debounce;

  MealDraft get currentDraft => MealDraft(mealType: selectedMealType, entries: _draftByType[selectedMealType] ?? []);

  Future<void> _init() async {
    suggested = await _repository.getSuggestedFoods(selectedMealType);
    templates = await _repository.getTemplates();
    notifyListeners();
  }

  void setMealType(MealType type) {
    selectedMealType = type;
    expandedFoodId = null;
    refreshSuggestions();
  }

  Future<void> refreshSuggestions() async {
    suggested = await _repository.getSuggestedFoods(selectedMealType);
    notifyListeners();
  }

  void onQueryChanged(String value) {
    query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () async {
      if (query.trim().isEmpty) {
        results = [];
      } else {
        try {
          results = await _repository.searchFoods(query);
        } catch (e) {
          results = await _repository.searchLocalFoods(query);
          setUiMessage('No se pudo consultar USDA. Mostrando catálogo local.');
        }
      }
      notifyListeners();
    });
  }

  Future<void> toggleExpanded(String foodId) async {
    expandedFoodId = expandedFoodId == foodId ? null : foodId;
    notifyListeners();

    if (expandedFoodId != foodId || !foodId.startsWith('fdc:')) return;

    final idx = results.indexWhere((food) => food.id == foodId);
    if (idx < 0) return;

    final food = results[idx];
    final hasMacros = food.macrosPer100.kcal > 0 || food.macrosPer100.protein > 0 || food.macrosPer100.carbs > 0 || food.macrosPer100.fat > 0;
    if (hasMacros || loadingFoodIds.contains(foodId)) return;

    final fdcId = int.tryParse(foodId.substring(4));
    if (fdcId == null) return;

    loadingFoodIds.add(foodId);
    notifyListeners();

    try {
      final fullFood = await _repository.getFoodItemFromFdc(fdcId);
      final fullIdx = results.indexWhere((item) => item.id == foodId);
      if (fullIdx >= 0) {
        results[fullIdx] = fullFood;
      }
    } catch (e) {
      setUiMessage('Error cargando macros USDA para este alimento.');
    } finally {
      loadingFoodIds.remove(foodId);
      notifyListeners();
    }
  }

  bool isLoadingFood(String id) => loadingFoodIds.contains(id);

  void setUiMessage(String msg) {
    uiMessage = msg;
  }

  String? consumeUiMessage() {
    final message = uiMessage;
    uiMessage = null;
    return message;
  }

  DraftEntry? entryForFood(String foodId) {
    for (final entry in currentDraft.entries) {
      if (entry.food.id == foodId) return entry;
    }
    return null;
  }

  void addOrUpdateDraft(DraftEntry entry) {
    final current = List<DraftEntry>.from(currentDraft.entries);
    final idx = current.indexWhere((e) => e.food.id == entry.food.id);
    if (idx >= 0) {
      current[idx] = entry;
    } else {
      current.add(entry);
      _addRecent(entry.food);
    }
    _draftByType[selectedMealType] = current;
    didBump = true;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 220), () {
      didBump = false;
      notifyListeners();
    });
  }

  void removeEntry(String foodId) {
    final current = List<DraftEntry>.from(currentDraft.entries)..removeWhere((e) => e.food.id == foodId);
    _draftByType[selectedMealType] = current;
    notifyListeners();
  }

  void clearDraft() {
    _draftByType[selectedMealType] = [];
    notifyListeners();
  }

  Future<void> registerCurrentDraft() async {
    if (currentDraft.entries.isEmpty) return;
    await _repository.logMeal(LoggedMeal(date: DateTime.now(), mealType: selectedMealType, entries: currentDraft.entries));
    clearDraft();
  }

  Future<bool> copyLastMeal({required bool replace}) async {
    final lastMeal = await _repository.getLastLoggedMeal(selectedMealType);
    if (lastMeal == null) return false;
    final current = replace ? <DraftEntry>[] : List<DraftEntry>.from(currentDraft.entries);
    current.addAll(lastMeal.entries);
    _draftByType[selectedMealType] = current;
    notifyListeners();
    return true;
  }

  Future<void> saveTemplate(String name) async {
    if (name.trim().isEmpty || currentDraft.entries.isEmpty) return;
    await _repository.saveTemplate(MealTemplate(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name.trim(), mealType: selectedMealType, entries: currentDraft.entries));
    templates = await _repository.getTemplates();
    notifyListeners();
  }

  Future<void> loadTemplate(MealTemplate template, {required bool replace}) async {
    final current = replace ? <DraftEntry>[] : List<DraftEntry>.from(currentDraft.entries);
    current.addAll(template.entries);
    _draftByType[selectedMealType] = current;
    notifyListeners();
  }

  Future<void> deleteTemplate(String id) async {
    await _repository.deleteTemplate(id);
    templates = await _repository.getTemplates();
    notifyListeners();
  }

  Future<void> createFood(FoodItem food) async {
    await _repository.createCustomFood(food);
    highlightedFood = food;
    query = food.name;
    results = [food, ...await _repository.searchFoods(food.name)];
    notifyListeners();
  }

  List<FoodItem> get emptyQueryItems => _recentFoods.isEmpty ? suggested : _recentFoods;

  void _addRecent(FoodItem food) {
    _recentFoods.removeWhere((f) => f.id == food.id);
    _recentFoods.insert(0, food);
    if (_recentFoods.length > 10) _recentFoods.removeLast();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
