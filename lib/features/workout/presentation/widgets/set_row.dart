import 'package:flutter/material.dart';

import '../../domain/session_models.dart';

class SetRow extends StatefulWidget {
  const SetRow({
    super.key,
    required this.set,
    required this.onChanged,
  });

  final SetInSession set;
  final void Function({double? kg, int? reps, bool? done}) onChanged;

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  late final TextEditingController _kgController;
  late final TextEditingController _repsController;

  @override
  void initState() {
    super.initState();
    _kgController = TextEditingController(text: widget.set.kg?.toString() ?? '');
    _repsController = TextEditingController(text: widget.set.reps?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final kgText = widget.set.kg?.toString() ?? '';
    final repsText = widget.set.reps?.toString() ?? '';
    if (_kgController.text != kgText) _kgController.text = kgText;
    if (_repsController.text != repsText) _repsController.text = repsText;
  }

  @override
  void dispose() {
    _kgController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDone = widget.set.done;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDone
            ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDone
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text('${widget.set.index}')),
          SizedBox(width: 72, child: Text(widget.set.previous?.label ?? '—')),
          Expanded(
            child: TextField(
              controller: _kgController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              enabled: !isDone,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Kg',
              ),
              onChanged: (value) => widget.onChanged(kg: double.tryParse(value)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _repsController,
              keyboardType: TextInputType.number,
              enabled: !isDone,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Reps',
              ),
              onChanged: (value) => widget.onChanged(reps: int.tryParse(value)),
            ),
          ),
          const SizedBox(width: 6),
          Checkbox(
            value: isDone,
            onChanged: (value) => widget.onChanged(done: value ?? false),
          ),
        ],
      ),
    );
  }
}
