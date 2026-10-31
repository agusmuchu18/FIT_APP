import 'nutrition_barcode_screen.dart';
import 'widgets/nutrition_theme.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../application/food_log_controller.dart';
import '../../../main.dart';
import '../data/nutrition_day_repository.dart';
import '../data/fdc_client.dart';
import '../data/food_repository.dart';
import '../data/nutrition_api_config.dart';
import '../domain/models.dart';
import 'create_food_item_sheet.dart';
import 'nutrition_text_screen.dart';
import 'meal_draft_sheet.dart';
import 'templates_sheet.dart';
import 'widgets/food_action_chips_row.dart';
import 'widgets/food_result_card.dart';
import 'widgets/food_search_bar.dart';
import 'widgets/meal_draft_bottom_bar.dart';
import 'widgets/meal_type_wheel.dart';

class FoodLogScreen extends StatefulWidget {
  const FoodLogScreen({
    super.key,
    this.initialMealType,
    this.date,
    this.selectOnly = false,
  });

  final MealType? initialMealType;
  final DateTime? date;
  final bool selectOnly;

  @override
  State<FoodLogScreen> createState() => _FoodLogScreenState();
}

class _FoodLogScreenState extends State<FoodLogScreen> {
  late final FoodLogController controller;
  late final FoodRepository repository;
  final searchController = TextEditingController();
  String _filter = 'all';

  @override
  void initState() {
    super.initState();

    final fdcClient = FdcClient(
      apiKey: NutritionApiConfig.usdaApiKey,
      proxyBaseUrl: kIsWeb ? NutritionApiConfig.usdaProxyBaseUrl : '',
    );
    repository = FoodRepository(
      fdc: fdcClient,
      days: NutritionDayRepository(
        fitness: context
            .getInheritedWidgetOfExactType<RepositoryScope>()
            ?.repository,
      ),
    );
    controller = FoodLogController(repository: repository, date: widget.date)
      ..addListener(_refresh);
    if (widget.initialMealType != null) {
      controller.setMealType(widget.initialMealType!);
    }
  }

  void _refresh() {
    if (!mounted) return;
    final uiMessage = controller.consumeUiMessage();
    if (searchController.text != controller.query) {
      searchController.text = controller.query;
      searchController.selection = TextSelection.collapsed(
        offset: searchController.text.length,
      );
    }
    setState(() {});
    if (uiMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(uiMessage)));
    }
  }

  @override
  void dispose() {
    controller.removeListener(_refresh);
    controller.dispose();
    repository.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _review() {
    if (widget.selectOnly) {
      Navigator.pop(
        context,
        List<DraftEntry>.of(controller.currentDraft.entries),
      );
    } else {
      MealDraftSheet.show(context, controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = controller.currentDraft;
    final candidates = controller.query.isEmpty
        ? controller.emptyQueryItems
        : controller.results;
    final list = _filter == 'frequent'
        ? controller.frequentFoods
              .where(
                (f) =>
                    controller.query.isEmpty ||
                    candidates.any((x) => x.id == f.id),
              )
              .toList()
        : _filter == 'favorites'
        ? (controller.query.isEmpty
              ? controller.favoriteFoods
              : candidates
                    .where((f) => controller.favoriteFoodIds.contains(f.id))
                    .toList())
        : _filter == 'custom'
        ? candidates.where((f) => f.isCustom).toList()
        : candidates;
    return NutritionTheme(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.selectOnly ? 'Ingredientes' : 'Alimentos'),
          actions: [
            IconButton(
              tooltip: 'Buscar por código',
              icon: const Icon(Icons.qr_code_2),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NutritionBarcodeScreen(
                    repository: repository,
                    onApply: controller.addOrUpdateDraft,
                    onCreate: (code) {
                      if (mounted) {
                        CreateFoodItemSheet.show(
                          context,
                          controller,
                          barcode: code,
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Cargar desde texto',
              icon: const Icon(Icons.text_snippet_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NutritionTextEntryScreen(
                    repository: repository,
                    onApply: (entries) {
                      for (final e in entries) {
                        controller.addOrUpdateDraft(e);
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.selectOnly)
                      MealTypeWheel(
                        selected: controller.selectedMealType,
                        onChanged: controller.setMealType,
                      ),
                    const SizedBox(height: 10),
                    if (!NutritionApiConfig.hasRemoteSearch)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Sin conexión remota · Podés buscar en el catálogo USDA guardado y crear alimentos.',
                        ),
                      ),
                    FoodSearchBar(
                      controller: searchController,
                      onChanged: controller.onQueryChanged,
                      onClear: () {
                        searchController.clear();
                        controller.onQueryChanged('');
                      },
                    ),
                    const SizedBox(height: 10),
                    FoodActionChipsRow(
                      draftCount: draft.itemCount,
                      onDraftTap: _review,
                      onTemplatesTap: () =>
                          TemplatesSheet.show(context, controller),
                      onCopyLastTap: _copyLast,
                      onCreateTap: () =>
                          CreateFoodItemSheet.show(context, controller),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final e in const {
                          'all': 'Todos',
                          'favorites': 'Favoritos',
                          'frequent': 'Frecuentes',
                          'custom': 'Propios',
                        }.entries)
                          ChoiceChip(
                            label: Text(e.value),
                            selected: _filter == e.key,
                            onSelected: (_) => setState(() => _filter = e.key),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: controller.isSearching
                          ? const Center(
                              child: CircularProgressIndicator(
                                semanticsLabel: 'Buscando alimentos',
                              ),
                            )
                          : list.isEmpty
                          ? _emptyState()
                          : ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (_, i) {
                                final food = list[i];
                                return FoodResultCard(
                                  key: ValueKey(food.id),
                                  food: food,
                                  onEdit: food.isCustom
                                      ? () => CreateFoodItemSheet.show(
                                          context,
                                          controller,
                                          food: food,
                                        )
                                      : null,
                                  expanded:
                                      controller.expandedFoodId == food.id,
                                  draftEntry: controller.entryForFood(food.id),
                                  loading: controller.isLoadingFood(food.id),
                                  isFavorite: controller.favoriteFoodIds
                                      .contains(food.id),
                                  onFavorite: () =>
                                      controller.toggleFavorite(food.id),
                                  onTap: () =>
                                      controller.toggleExpanded(food.id),
                                  onSave: (entry) {
                                    controller.addOrUpdateDraft(entry);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Agregado al borrador'),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: widget.selectOnly
                ? FilledButton(
                    onPressed: draft.entries.isEmpty ? null : _review,
                    child: Text('Usar ${draft.itemCount} ingredientes'),
                  )
                : MealDraftBottomBar(
                    draft: draft,
                    bump: controller.didBump,
                    onTap: _review,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Sin resultados'),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => CreateFoodItemSheet.show(context, controller),
            child: const Text('Crear alimento'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyLast() async {
    bool replace = true;
    if (controller.currentDraft.entries.isNotEmpty) {
      final result = await showModalBottomSheet<bool>(
        context: context,
        builder: (_) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                title: const Text('Reemplazar'),
                onTap: () => Navigator.pop(context, true),
              ),
              ListTile(
                title: const Text('Sumar'),
                onTap: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      );
      if (result == null) return;
      replace = result;
    }
    late bool ok;
    try {
      ok = await controller.copyLastMeal(replace: replace);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudieron sumar los datos. Elegí reemplazar el borrador para conservar sus unidades.',
            ),
          ),
        );
      }
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Última comida copiada'
                : 'No hay comida previa para este tipo',
          ),
        ),
      );
    }
  }
}
