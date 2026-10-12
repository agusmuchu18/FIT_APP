import 'package:flutter/material.dart';

import '../../domain/session_models.dart';

class SetRow extends StatefulWidget {
  const SetRow({
    super.key,
    required this.set,
    required this.onChanged,
    this.isTimed = false,
    this.isAssisted = false,
    this.onDurationChanged,
    this.onDelete,
  });
  final SetInSession set;
  final bool isTimed;
  final bool isAssisted;
  final ValueChanged<int?>? onDurationChanged;
  final VoidCallback? onDelete;
  final void Function({
    double? kg,
    bool? clearKg,
    int? reps,
    bool? clearReps,
    bool? done,
  })
  onChanged;
  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  late final TextEditingController _kgController;
  late final TextEditingController _repsController;
  late final FocusNode _kgFocusNode;
  late final FocusNode _repsFocusNode;
  bool _kgInvalid = false;
  bool _repsInvalid = false;
  String get _loadText =>
      (widget.isAssisted ? widget.set.assistanceKg : widget.set.kg)
          ?.toString() ??
      '';
  String get _resultText =>
      (widget.isTimed ? widget.set.durationSeconds : widget.set.reps)
          ?.toString() ??
      '';
  @override
  void initState() {
    super.initState();
    _kgController = TextEditingController(text: _loadText);
    _repsController = TextEditingController(text: _resultText);
    _kgFocusNode = FocusNode()..addListener(_syncUnfocusedFields);
    _repsFocusNode = FocusNode()..addListener(_syncUnfocusedFields);
  }

  void _syncUnfocusedFields() {
    if (!_kgFocusNode.hasFocus) {
      final text = _loadText;
      if (_kgController.text != text) _kgController.text = text;
    }
    if (!_repsFocusNode.hasFocus && _repsController.text != _resultText) {
      _repsController.text = _resultText;
    }
  }

  @override
  void didUpdateWidget(covariant SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncUnfocusedFields();
  }

  @override
  void dispose() {
    _kgController.dispose();
    _repsController.dispose();
    _kgFocusNode.dispose();
    _repsFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.set.done;
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: done
            ? Theme.of(context).colorScheme.primary.withValues(alpha: .12)
            : Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: .15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Serie ${widget.set.index}\nAnterior: ${widget.set.previous?.label ?? '—'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Checkbox(
                value: done,
                semanticLabel: 'Serie ${widget.set.index} completada',
                onChanged:
                    done ||
                        (!_kgInvalid &&
                            !_repsInvalid &&
                            widget.set.hasValidResult(isTimed: widget.isTimed))
                    ? (value) => widget.onChanged(done: value ?? false)
                    : null,
              ),
              if (widget.onDelete != null)
                PopupMenuButton<String>(
                  tooltip: 'Opciones de la serie ${widget.set.index}',
                  onSelected: (_) => widget.onDelete!(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar serie'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.isTimed) ...[
                Expanded(
                  child: TextField(
                    controller: _kgController,
                    focusNode: _kgFocusNode,
                    readOnly: done,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: widget.isAssisted ? 'Asist. kg' : 'Kg',
                      helperText: 'Opcional',
                      errorText: _kgInvalid ? 'Carga inválida' : null,
                    ),
                    onChanged: (value) {
                      final parsed = double.tryParse(
                        value.trim().replaceAll(',', '.'),
                      );
                      final invalid =
                          value.trim().isNotEmpty &&
                          (parsed == null || !parsed.isFinite || parsed < 0);
                      setState(() => _kgInvalid = invalid);
                      widget.onChanged(
                        kg: invalid ? null : parsed,
                        clearKg: invalid || parsed == null,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: TextField(
                  controller: _repsController,
                  focusNode: _repsFocusNode,
                  readOnly: done,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: widget.isTimed ? 'Segundos' : 'Reps',
                    helperText: 'Mayor a cero',
                    errorText: _repsInvalid
                        ? (widget.isTimed
                              ? 'Duración inválida'
                              : 'Repeticiones inválidas')
                        : null,
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value.trim());
                    final invalid =
                        value.trim().isNotEmpty &&
                        (parsed == null || parsed <= 0);
                    setState(() => _repsInvalid = invalid);
                    if (widget.isTimed) {
                      widget.onDurationChanged?.call(invalid ? null : parsed);
                    } else {
                      widget.onChanged(
                        reps: invalid ? null : parsed,
                        clearReps: invalid || parsed == null,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
