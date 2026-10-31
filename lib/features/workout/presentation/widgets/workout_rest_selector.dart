import 'package:flutter/material.dart';

import '../../../common/theme/app_layout.dart';

class WorkoutRestSelector extends StatefulWidget {
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
  State<WorkoutRestSelector> createState() => _WorkoutRestSelectorState();
}

class _WorkoutRestSelectorState extends State<WorkoutRestSelector> {
  final _value = TextEditingController();
  var _editing = false;
  String? _error;
  @override
  void didUpdateWidget(covariant WorkoutRestSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _editing) {
      _editing = false;
      _error = null;
    }
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _submit() {
    final input = _value.text.trim();
    final parts = input.split(':');
    int? parsed;
    if (parts.length == 1) {
      parsed = int.tryParse(input);
    } else if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]), seconds = int.tryParse(parts[1]);
      if (minutes != null &&
          minutes >= 0 &&
          seconds != null &&
          seconds >= 0 &&
          seconds < 60) {
        parsed = minutes * 60 + seconds;
      }
    }
    if (parsed == null || parsed < 1 || parsed > 3600) {
      setState(
        () => _error = 'Ingresá de 1 a 3600 segundos, o minutos:segundos.',
      );
      return;
    }
    widget.onChanged(parsed);
    setState(() {
      _editing = false;
      _error = null;
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Descanso automático'),
          Semantics(
            label: 'Descanso automático',
            child: Switch(value: widget.enabled, onChanged: widget.onToggle),
          ),
          IconButton(
            tooltip: 'Reducir descanso 15 segundos',
            onPressed: widget.enabled && widget.seconds > 1
                ? () => widget.onChanged((widget.seconds - 15).clamp(1, 3600))
                : null,
            icon: const Icon(Icons.remove),
          ),
          if (_editing)
            SizedBox(
              width: 110,
              child: TextField(
                key: const ValueKey('inline-rest-duration'),
                controller: _value,
                autofocus: true,
                keyboardType: TextInputType.datetime,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Segundos o m:ss',
                  isDense: true,
                ),
                onTap: () => _value.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _value.text.length,
                ),
                onSubmitted: (_) => _submit(),
              ),
            )
          else
            TextButton(
              onPressed: widget.enabled
                  ? () => setState(() {
                      _value.text = '${widget.seconds}';
                      _value.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _value.text.length,
                      );
                      _editing = true;
                    })
                  : null,
              child: Semantics(
                label:
                    'Configurar duración de descanso, ${widget.seconds} segundos',
                child: Text(
                  '${widget.seconds ~/ 60}:${(widget.seconds % 60).toString().padLeft(2, '0')}',
                ),
              ),
            ),
          if (_editing) ...[
            IconButton(
              tooltip: 'Guardar duración',
              onPressed: _submit,
              icon: const Icon(Icons.check),
            ),
            IconButton(
              tooltip: 'Cancelar edición',
              onPressed: () => setState(() {
                _editing = false;
                _error = null;
              }),
              icon: const Icon(Icons.close),
            ),
          ] else
            IconButton(
              tooltip: 'Aumentar descanso 15 segundos',
              onPressed: widget.enabled && widget.seconds < 3600
                  ? () => widget.onChanged((widget.seconds + 15).clamp(1, 3600))
                  : null,
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
}
