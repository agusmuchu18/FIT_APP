import 'package:flutter/material.dart';

import '../application/food_log_controller.dart';
import '../data/food_repository.dart';
import '../domain/models.dart';
import 'create_food_item_sheet.dart';
import 'meal_draft_sheet.dart';
import 'paywall_sheet.dart';
import 'templates_sheet.dart';
import 'widgets/food_action_chips_row.dart';
import 'widgets/food_result_card.dart';
import 'widgets/food_search_bar.dart';
import 'widgets/meal_draft_bottom_bar.dart';
import 'widgets/meal_type_wheel.dart';

class FoodLogScreen extends StatefulWidget {
  const FoodLogScreen({super.key});

  @override
  State<FoodLogScreen> createState() => _FoodLogScreenState();
}

class _FoodLogScreenState extends State<FoodLogScreen> {
  late final FoodLogController controller;
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = FoodLogController(repository: FoodRepository())..addListener(_refresh);
  }

  void _refresh() {
    if (!mounted) return;
    if (searchController.text != controller.query) {
      searchController.text = controller.query;
      searchController.selection = TextSelection.collapsed(offset: searchController.text.length);
    }
    setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_refresh);
    controller.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = controller.currentDraft;
    final list = controller.query.isEmpty ? controller.emptyQueryItems : controller.results;
    return Scaffold(
      appBar: AppBar(title: const Text('Alimentación')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            MealTypeWheel(selected: controller.selectedMealType, onChanged: controller.setMealType),
            const SizedBox(height: 10),
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
              onDraftTap: () => MealDraftSheet.show(context, controller),
              onTemplatesTap: () => TemplatesSheet.show(context, controller),
              onCopyLastTap: _copyLast,
              onCreateTap: () => CreateFoodItemSheet.show(context, controller),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: list.isEmpty
                  ? _emptyState()
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final food = list[i];
                        return FoodResultCard(
                          food: food,
                          expanded: controller.expandedFoodId == food.id,
                          draftEntry: controller.entryForFood(food.id),
                          isPro: controller.isPro,
                          onTap: () => controller.toggleExpanded(food.id),
                          onPaywallTap: () => PaywallSheet.show(context),
                          onSave: (entry) {
                            controller.addOrUpdateDraft(entry);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agregado al borrador')));
                          },
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
      bottomSheet: Padding(
        padding: const EdgeInsets.all(10),
        child: MealDraftBottomBar(draft: draft, bump: controller.didBump, onTap: () => MealDraftSheet.show(context, controller)),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Sin resultados'),
        const SizedBox(height: 10),
        FilledButton(onPressed: () => CreateFoodItemSheet.show(context, controller), child: const Text('Crear alimento')),
      ]),
    );
  }

  Future<void> _copyLast() async {
    bool replace = true;
    if (controller.currentDraft.entries.isNotEmpty) {
      final result = await showModalBottomSheet<bool>(
        context: context,
        builder: (_) => SafeArea(
          child: Wrap(children: [
            ListTile(title: const Text('Reemplazar'), onTap: () => Navigator.pop(context, true)),
            ListTile(title: const Text('Sumar'), onTap: () => Navigator.pop(context, false)),
          ]),
        ),
      );
      if (result == null) return;
      replace = result;
    }
    final ok = await controller.copyLastMeal(replace: replace);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Última comida copiada' : 'No hay comida previa para este tipo')));
    }
  }
}
