import '../../../common/theme/app_layout.dart';

import 'package:flutter/material.dart';

import '../../domain/models.dart';

class FoodResultCard extends StatefulWidget {
  const FoodResultCard({
    super.key,
    required this.food,
    required this.expanded,
    required this.draftEntry,
    required this.loading,
    required this.onTap,
    required this.onSave,
    this.isFavorite = false,
    this.onFavorite,
    this.onEdit,
  });
  final FoodItem food;
  final bool expanded, loading;
  final DraftEntry? draftEntry;
  final VoidCallback onTap;
  final ValueChanged<DraftEntry> onSave;
  final bool isFavorite;
  final VoidCallback? onFavorite, onEdit;
  @override
  State<FoodResultCard> createState() => _FoodResultCardState();
}

class _FoodResultCardState extends State<FoodResultCard> {
  final _quantity = TextEditingController();
  late FoodUnit _unit;
  bool _quantityChanged = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FoodResultCard old) {
    super.didUpdateWidget(old);
    if (old.food.id != widget.food.id || old.draftEntry != widget.draftEntry) {
      _load();
    }
  }

  void _load() {
    _quantityChanged = false;
    _unit =
        widget.draftEntry?.unit ??
        (widget.food.supportsUnit(FoodUnit.serving)
            ? FoodUnit.serving
            : widget.food.supportsUnit(FoodUnit.grams)
            ? FoodUnit.grams
            : FoodUnit.ml);
    _quantity.text = _text(
      widget.draftEntry?.quantity ?? (_unit == FoodUnit.serving ? 1 : 100),
    );
  }

  String _text(num n) => n.toDouble() == n.roundToDouble()
      ? n.toInt().toString()
      : n.toString().replaceAll('.', ',');
  double? get _amount =>
      double.tryParse(_quantity.text.trim().replaceAll(',', '.'));
  bool get _valid =>
      _amount != null &&
      _amount!.isFinite &&
      _amount! > 0 &&
      _amount! <= 100000;
  DraftEntry get _entry => DraftEntry(
    food: widget.food,
    quantity: _valid ? _amount! : 0,
    unit: _unit,
    gramsOverride: _quantityChanged ? null : widget.draftEntry?.gramsOverride,
  );
  void _step(int direction) {
    _quantityChanged = true;
    setState(() {
      _quantity.text = _text(
        ((_amount ?? 0) + direction * (_unit == FoodUnit.serving ? 0.5 : 10))
            .clamp(0.1, 100000),
      );
    });
  }

  void _switch(FoodUnit unit) {
    _quantityChanged = true;
    final grams = _entry.effectiveGrams;
    setState(() {
      final previous = _unit;
      _unit = unit;
      _quantity.text = _text(
        unit == FoodUnit.ml || previous == FoodUnit.ml
            ? 100
            : unit == FoodUnit.grams
            ? grams
            : grams / widget.food.defaultServingGrams,
      );
    });
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = _entry.computedMacros;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(AppShape.control),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.food.name,
                      maxLines: widget.expanded ? null : 2,
                      overflow: widget.expanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          widget.food.categoryLabel,
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          '${MacroValues.display(m.kcal, decimals: 0)} kcal',
                        ),
                        Icon(
                          widget.expanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _motion(
              context,
              widget.expanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.onFavorite != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: widget.onFavorite,
                              icon: Icon(
                                widget.isFavorite
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                              ),
                              label: Text(
                                widget.isFavorite
                                    ? 'Guardado'
                                    : 'Guardar en favoritos',
                              ),
                            ),
                          ),
                        if (widget.onEdit != null)
                          TextButton.icon(
                            onPressed: widget.onEdit,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Editar alimento propio'),
                          ),
                        if (widget.loading)
                          const LinearProgressIndicator(
                            semanticsLabel: 'Cargando nutrientes',
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Reducir cantidad',
                              onPressed: () => _step(-1),
                              icon: const Icon(Icons.remove),
                            ),
                            Expanded(
                              child: TextField(
                                key: ValueKey('quantity-${widget.food.id}'),
                                controller: _quantity,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (_) => setState(() {
                                  _quantityChanged = true;
                                }),
                                decoration: InputDecoration(
                                  labelText: 'Cantidad',
                                  suffixText: _unit == FoodUnit.grams
                                      ? 'g'
                                      : _unit == FoodUnit.ml
                                      ? 'ml'
                                      : 'porciones',
                                  errorText: _valid
                                      ? null
                                      : 'Ingresá una cantidad válida',
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Aumentar cantidad',
                              onPressed: () => _step(1),
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final u in FoodUnit.values)
                              if (widget.food.supportsUnit(u))
                                ChoiceChip(
                                  label: Text(
                                    u == FoodUnit.serving
                                        ? 'Porción'
                                        : u == FoodUnit.grams
                                        ? 'g'
                                        : 'ml',
                                  ),
                                  selected: u == _unit,
                                  onSelected: (_) => _switch(u),
                                ),
                          ],
                        ),
                        if (_unit == FoodUnit.serving)
                          Text(
                            '${widget.food.servingLabel ?? '1 porción'} = ${_text(widget.food.defaultServingGrams)} g${widget.food.servingVerified ? '' : ' · equivalencia declarada'}',
                            style: theme.textTheme.bodySmall,
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'P ${MacroValues.display(m.protein)} g · C ${MacroValues.display(m.carbs)} g · G ${MacroValues.display(m.fat)} g',
                        ),
                        if (widget.food.source == 'legacy' &&
                            !widget.food.isCustom)
                          const Text(
                            'Referencia heredada sin fuente documentada. Podés elegir un registro USDA para contrastarla.',
                          ),
                        if (!m.isComplete)
                          const Text(
                            '— Información no disponible. No equivale a cero.',
                          ),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Fuente y nutrientes'),
                          children: [
                            ListTile(
                              title: Text(
                                widget.food.isCustom
                                    ? 'Declarado por vos'
                                    : widget.food.source,
                              ),
                              subtitle: Text(
                                [
                                  if (widget.food.externalId != null)
                                    'ID ${widget.food.externalId}',
                                  if (widget.food.originalName != null)
                                    widget.food.originalName!,
                                  if (widget.food.brand != null)
                                    widget.food.brand!,
                                  if (widget.food.energyMethod != null)
                                    widget.food.energyMethod!,
                                  if (widget.food.sourceDate != null)
                                    'Fecha de la fuente: ${widget.food.sourceDate}',
                                  ...widget.food.dataNotes,
                                ].join(' · '),
                              ),
                            ),
                            for (final e in widget.food.micronutrients.entries)
                              ListTile(
                                dense: true,
                                title: Text(_label(e.key)),
                                trailing: Text(
                                  MacroValues.display(
                                    e.value == null || _unit == FoodUnit.ml
                                        ? null
                                        : e.value! *
                                              (_unit == FoodUnit.ml
                                                  ? _amount ?? 0
                                                  : _entry.effectiveGrams) /
                                              100,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed:
                                widget.loading ||
                                    !_valid ||
                                    !widget.food.detailsLoaded
                                ? null
                                : () => widget.onSave(_entry),
                            child: Text(
                              widget.draftEntry == null
                                  ? 'Agregar al borrador'
                                  : 'Actualizar',
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _motion(BuildContext context, Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedSize(duration: AppVisual.motionNormal, child: child);
  }

  String _label(String key) =>
      const {
        'fiber_g': 'Fibra (g)',
        'sugar_g': 'Azúcares (g)',
        'saturatedFat_g': 'Grasas saturadas (g)',
        'sodium_mg': 'Sodio (mg)',
        'potassium_mg': 'Potasio (mg)',
        'calcium_mg': 'Calcio (mg)',
        'iron_mg': 'Hierro (mg)',
        'magnesium_mg': 'Magnesio (mg)',
        'vitaminC_mg': 'Vitamina C (mg)',
        'vitaminD_ug': 'Vitamina D (µg)',
      }[key] ??
      key;
}
