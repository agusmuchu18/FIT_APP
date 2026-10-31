import 'dart:async';

import 'package:flutter/material.dart';

import '../data/food_repository.dart';
import '../domain/models.dart';

class FoodLogController extends ChangeNotifier {
  FoodLogController({required this._repository, this.date}) {
    _init();
  }

  final FoodRepository _repository;
  final DateTime? date;
  final Map<MealType, List<DraftEntry>> _draftByType = {
    for (final t in MealType.values) t: [],
  };
  final List<FoodItem> _recentFoods = [];
  final Map<MealType, LoggedMeal> _registrationAttempts = {};

  MealType selectedMealType = MealType.dinner;
  List<FoodItem> results = [];
  List<FoodItem> suggested = [];
  Set<String> favoriteFoodIds = {};
  List<FoodItem> frequentFoods = [];
  List<FoodItem> favoriteFoods = [];
  List<MealTemplate> templates = [];
  String query = '';
  String? expandedFoodId;
  bool didBump = false;
  bool isRegistering = false;
  bool isSearching = false;
  bool _disposed = false;
  FoodItem? highlightedFood;

  final Set<String> loadingFoodIds = <String>{};
  String? uiMessage;

  Timer? _debounce;
  int _searchGeneration = 0;

  MealDraft get currentDraft => MealDraft(
    mealType: selectedMealType,
    entries: _draftByType[selectedMealType] ?? [],
  );

  Future<void> _init() async {
    try {
      await refreshSuggestions();
      templates = await _repository.getTemplates();
    } catch (_) {
      setUiMessage(
        'No se pudieron cargar los datos guardados. No se modificaron.',
      );
    }
    notifyListeners();
  }

  void setMealType(MealType type) {
    selectedMealType = type;
    expandedFoodId = null;
    refreshSuggestions();
  }

  int _suggestionGeneration = 0;
  Future<void> refreshSuggestions() async {
    final generation = ++_suggestionGeneration;
    final type = selectedMealType;
    try {
      final favorites = await _repository.favoriteFoodIds();
      final frequent = await _repository.frequentFoods();
      final catalog = await _repository.loadLocalCatalog();
      final suggestions = await _repository.getSuggestedFoods(type);
      if (_disposed || generation != _suggestionGeneration) return;
      favoriteFoodIds = favorites;
      frequentFoods = frequent;
      favoriteFoods = catalog.where((f) => favorites.contains(f.id)).toList();
      suggested = suggestions;
      notifyListeners();
    } catch (_) {
      if (!_disposed && generation == _suggestionGeneration) {
        setUiMessage(
          'No se pudieron cargar las sugerencias. Podés volver a intentarlo.',
        );
      }
    }
  }

  void onQueryChanged(String value) {
    query = value;
    _debounce?.cancel();
    final searchQuery = value.trim();
    final generation = ++_searchGeneration;
    results = [];
    isSearching = searchQuery.isNotEmpty;
    notifyListeners();
    _debounce = Timer(const Duration(milliseconds: 220), () async {
      if (searchQuery.isEmpty) {
        results = [];
      } else {
        try {
          final found = await _repository.searchFoods(searchQuery);
          if (generation != _searchGeneration) return;
          results = found;
        } catch (e) {
          final local = await _repository.searchLocalFoods(searchQuery);
          if (generation != _searchGeneration) return;
          results = local;
          setUiMessage('No se pudo consultar USDA. Mostrando catálogo local.');
        }
      }
      if (generation != _searchGeneration) return;
      isSearching = false;
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
    final hasMacros = food.detailsLoaded;
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
    final current = List<DraftEntry>.from(currentDraft.entries)
      ..removeWhere((e) => e.food.id == foodId);
    _draftByType[selectedMealType] = current;
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    try {
      await _repository.toggleFavoriteFood(id);
      favoriteFoodIds = await _repository.favoriteFoodIds();
      favoriteFoods = (await _repository.loadLocalCatalog())
          .where((f) => favoriteFoodIds.contains(f.id))
          .toList();
    } catch (_) {
      setUiMessage('No se pudo guardar el favorito. Podés reintentar.');
    }
    notifyListeners();
  }

  void clearDraft() {
    _draftByType[selectedMealType] = [];
    _registrationAttempts.remove(selectedMealType);
    notifyListeners();
  }

  Future<void> registerCurrentDraft() async {
    if (currentDraft.entries.isEmpty || isRegistering) return;
    final type = selectedMealType;
    final entries = List<DraftEntry>.of(currentDraft.entries);
    isRegistering = true;
    notifyListeners();
    final previousAttempt = _registrationAttempts[type];
    final operation = LoggedMeal(
      id: previousAttempt?.id,
      date: previousAttempt?.date ?? date ?? DateTime.now(),
      mealType: type,
      entries: entries,
    );
    _registrationAttempts[type] = operation;
    try {
      await _repository.logMeal(operation);
      _registrationAttempts.remove(type);
      if (_repository.projectionPending) {
        setUiMessage(
          'Comida guardada en el dispositivo. La actualización de Inicio está pendiente; se reintentará sin duplicarla.',
        );
      }
      _draftByType[type]?.removeWhere(entries.contains);
    } finally {
      isRegistering = false;
      notifyListeners();
    }
  }

  Future<bool> copyLastMeal({required bool replace}) async {
    final lastMeal = await _repository.getLastLoggedMeal(selectedMealType);
    if (lastMeal == null) return false;
    final current = _mergeEntries(
      replace ? [] : currentDraft.entries,
      lastMeal.entries,
    );
    _draftByType[selectedMealType] = current;
    notifyListeners();
    return true;
  }

  Future<void> saveTemplate(String name) async {
    if (name.trim().isEmpty || currentDraft.entries.isEmpty) return;
    await _repository.saveTemplate(
      MealTemplate(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.trim(),
        mealType: selectedMealType,
        entries: currentDraft.entries,
        createdAt: DateTime.now(),
      ),
    );
    templates = await _repository.getTemplates();
    notifyListeners();
  }

  Future<void> loadTemplate(
    MealTemplate template, {
    required bool replace,
  }) async {
    final current = _mergeEntries(
      replace ? [] : currentDraft.entries,
      template.entries,
    );
    _draftByType[selectedMealType] = current;
    notifyListeners();
  }

  List<DraftEntry> _mergeEntries(
    List<DraftEntry> base,
    List<DraftEntry> incoming,
  ) {
    final result = List<DraftEntry>.of(base);
    for (final e in incoming) {
      final index = result.indexWhere((v) => v.food.id == e.food.id);
      if (index < 0) {
        result.add(e);
        continue;
      }
      final old = result[index];
      if (!sameFoodComposition(old.food, e.food) ||
          ((old.unit == FoodUnit.ml) != (e.unit == FoodUnit.ml))) {
        throw StateError(
          'No se pueden sumar composiciones o unidades distintas. Elegí reemplazar el borrador.',
        );
      }
      if (old.unit == e.unit) {
        result[index] = old.copyWith(
          quantity: old.quantity + e.quantity,
          gramsOverride: old.gramsOverride == null && e.gramsOverride == null
              ? null
              : old.effectiveGrams + e.effectiveGrams,
        );
      } else {
        result[index] = DraftEntry(
          food: e.food,
          quantity: old.effectiveGrams + e.effectiveGrams,
          unit: FoodUnit.grams,
        );
      }
    }
    return result;
  }

  Future<void> deleteTemplate(String id) async {
    await _repository.deleteTemplate(id);
    templates = await _repository.getTemplates();
    notifyListeners();
  }

  Future<void> createFood(FoodItem food) async {
    await _repository.createCustomFood(food);
    _debounce?.cancel();
    _searchGeneration++;
    isSearching = false;
    highlightedFood = food;
    query = food.name;
    results = [food];
    expandedFoodId = food.id;
    notifyListeners();
  }

  List<FoodItem> get emptyQueryItems =>
      _recentFoods.isEmpty ? suggested : _recentFoods;

  void _addRecent(FoodItem food) {
    _recentFoods.removeWhere((f) => f.id == food.id);
    _recentFoods.insert(0, food);
    if (_recentFoods.length > 10) _recentFoods.removeLast();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _searchGeneration++;
    super.dispose();
  }
}
