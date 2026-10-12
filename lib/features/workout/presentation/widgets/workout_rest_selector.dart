import 'package:flutter/material.dart';

import '../../../common/theme/app_layout.dart';

class WorkoutRestSelector extends StatelessWidget {
  const WorkoutRestSelector({
    super.key,
    required this.enabled,
    required this.seconds,
    required this.onToggle,
    required this.onChanged,
  });
  final bool enabled;
  final int seconds;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      const Text('Descanso automático'),
      Semantics(
        label: 'Descanso automático',
        child: Switch(value: enabled, onChanged: onToggle),
      ),
      IconButton(
        tooltip: 'Reducir descanso 15 segundos',
        onPressed: enabled && seconds > 1
            ? () => onChanged((seconds - 15).clamp(1, 3600))
            : null,
        icon: const Icon(Icons.remove),
      ),
      TextButton(
        onPressed: enabled
            ? () async {
                final duration = await showModalBottomSheet<int>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  useSafeArea: true,
                  builder: (_) => _RestDurationSheet(seconds: seconds),
                );
                if (duration != null) onChanged(duration);
              }
            : null,
        child: Semantics(
          label: 'Configurar duración de descanso, $seconds segundos',
          child: Text(
            '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
          ),
        ),
      ),
      IconButton(
        tooltip: 'Aumentar descanso 15 segundos',
        onPressed: enabled && seconds < 3600
            ? () => onChanged((seconds + 15).clamp(1, 3600))
            : null,
        icon: const Icon(Icons.add),
      ),
    ],
  );
}

class _RestDurationSheet extends StatefulWidget {
  const _RestDurationSheet({required this.seconds});
  final int seconds;
  @override
  State<_RestDurationSheet> createState() => _RestDurationSheetState();
}

class _RestDurationSheetState extends State<_RestDurationSheet> {
  static const presets = [30, 45, 60, 90, 120];
  final _form = GlobalKey<FormState>();
  late int _selected;
  late bool _custom;
  late final TextEditingController _value;
  @override
  void initState() {
    super.initState();
    _selected = widget.seconds;
    _custom = !presets.contains(_selected);
    _value = TextEditingController(text: '$_selected');
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.md,
      AppSpacing.xl,
      AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Duración del descanso',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final preset in presets)
                ChoiceChip(
                  label: Text('$preset segundos'),
                  selected: !_custom && _selected == preset,
                  onSelected: (_) => setState(() {
                    _selected = preset;
                    _custom = false;
                  }),
                ),
              ChoiceChip(
                label: const Text('Personalizado'),
                selected: _custom,
                onSelected: (_) => setState(() => _custom = true),
              ),
            ],
          ),
          if (_custom) ...[
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _value,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Segundos',
                helperText: 'Entre 1 y 3600 segundos',
              ),
              validator: (text) {
                final value = int.tryParse(text ?? '');
                return value == null || value < 1 || value > 3600
                    ? 'Ingresá un número entre 1 y 3600.'
                    : null;
              },
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                Navigator.of(context)
                    .pop(_custom ? int.parse(_value.text) : _selected);
              },
              child: const Text('Guardar duración'),
            ),
          ),
        ],
      ),
    ),
  );
}
