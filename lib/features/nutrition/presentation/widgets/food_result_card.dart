import 'package:flutter/material.dart';

import '../../../common/theme/app_colors.dart';
import '../../domain/models.dart';

class FoodResultCard extends StatefulWidget {
  const FoodResultCard({
    super.key,
    required this.food,
    required this.expanded,
    required this.draftEntry,
    required this.isPro,
    required this.loading,
    required this.onTap,
    required this.onSave,
    required this.onPaywallTap,
  });

  final FoodItem food;
  final bool expanded;
  final DraftEntry? draftEntry;
  final bool isPro;
  final bool loading;
  final VoidCallback onTap;
  final ValueChanged<DraftEntry> onSave;
  final VoidCallback onPaywallTap;

  @override
  State<FoodResultCard> createState() => _FoodResultCardState();
}

class _FoodResultCardState extends State<FoodResultCard> {
  late int quantity;
  late FoodUnit unit;
  int grams = 100;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FoodResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draftEntry != widget.draftEntry) _load();
  }

  void _load() {
    quantity = widget.draftEntry?.quantity ?? 1;
    unit = widget.draftEntry?.unit ?? FoodUnit.serving;
    grams = widget.draftEntry?.gramsOverride ?? widget.food.defaultServingGrams;
  }

  @override
  Widget build(BuildContext context) {
    final macros = _buildEntry().computedMacros;
    return Card(
      color: AppColors.card,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.food.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text(widget.food.categoryLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted)),
              ])),
              Text('${macros.kcal.round()} kcal\n${macros.protein.round()} P', textAlign: TextAlign.right),
            ]),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: widget.expanded ? _expanded(macros) : const SizedBox.shrink(),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _expanded(MacroValues macros) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 12),
      if (widget.loading)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 8),
              Text('Cargando macros...'),
            ],
          ),
        ),
      Row(children: [
        const Text('Cantidad'),
        const Spacer(),
        IconButton(onPressed: () => setState(() => quantity = (quantity - 1).clamp(1, 99)), icon: const Icon(Icons.remove)),
        Text('$quantity'),
        IconButton(onPressed: () => setState(() => quantity = (quantity + 1).clamp(1, 99)), icon: const Icon(Icons.add)),
      ]),
      Wrap(spacing: 8, children: [
        if (widget.food.supportsUnit(FoodUnit.serving)) ChoiceChip(label: const Text('Porción'), selected: unit == FoodUnit.serving, onSelected: (_) => setState(() => unit = FoodUnit.serving)),
        if (widget.food.supportsUnit(FoodUnit.grams)) ChoiceChip(label: const Text('g'), selected: unit == FoodUnit.grams, onSelected: (_) => setState(() => unit = FoodUnit.grams)),
        if (widget.food.supportsUnit(FoodUnit.ml)) ChoiceChip(label: const Text('ml'), selected: unit == FoodUnit.ml, onSelected: (_) => setState(() => unit = FoodUnit.ml)),
      ]),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: widget.isPro ? null : widget.onPaywallTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(children: [
            Container(
              padding: const EdgeInsets.all(10),
              color: AppColors.surface,
              child: Row(children: [
                const Text('Peso (PRO)'),
                const Spacer(),
                IconButton(onPressed: widget.isPro ? () => setState(() => grams = (grams - 10).clamp(10, 1000)) : null, icon: const Icon(Icons.remove)),
                SizedBox(width: 52, child: TextFormField(initialValue: '$grams', enabled: widget.isPro, keyboardType: TextInputType.number, onChanged: (v) => grams = int.tryParse(v) ?? grams)),
                IconButton(onPressed: widget.isPro ? () => setState(() => grams = (grams + 10).clamp(10, 1000)) : null, icon: const Icon(Icons.add)),
              ]),
            ),
            if (!widget.isPro)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.06),
                  alignment: Alignment.center,
                  child: const Icon(Icons.lock_outline),
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Text('P ${macros.protein.toStringAsFixed(1)} · C ${macros.carbs.toStringAsFixed(1)} · G ${macros.fat.toStringAsFixed(1)}'),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () => widget.onSave(_buildEntry()),
          child: Text(widget.draftEntry == null ? 'Agregar al borrador' : 'Actualizar'),
        ),
      ),
    ]);
  }

  DraftEntry _buildEntry() {
    return DraftEntry(food: widget.food, quantity: quantity, unit: unit, gramsOverride: widget.isPro && unit != FoodUnit.ml ? grams : null);
  }
}
