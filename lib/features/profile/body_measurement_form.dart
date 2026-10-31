import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../common/theme/app_colors.dart';
import 'body_measurement.dart';
import 'data/body_measurement_repository.dart';

class BodyMeasurementForm extends StatefulWidget {
  const BodyMeasurementForm({
    super.key,
    required this.repository,
    required this.unitFor,
    this.existing,
    this.recentFields = const [BodyMetric.weight, BodyMetric.waist],
    this.now,
  });
  final BodyMeasurementRepository repository;
  final String Function(BodyMetric metric) unitFor;
  final BodyMeasurement? existing;
  final Iterable<BodyMetric> recentFields;
  final DateTime? now;
  @override
  State<BodyMeasurementForm> createState() => _BodyMeasurementFormState();
}

class _BodyMeasurementFormState extends State<BodyMeasurementForm> {
  final _form = GlobalKey<FormState>();
  final _notes = TextEditingController();
  late final Map<BodyMetric, TextEditingController> _fields;
  late DateTime _date;
  bool _busy = false;
  String? _error;
  late final _units = {for (final m in BodyMetric.values) m: widget.unitFor(m)};
  @override
  void initState() {
    super.initState();
    final now = widget.now ?? DateTime.now();
    _date = widget.existing?.date ?? DateUtils.dateOnly(now);
    _notes.text = widget.existing?.notes ?? '';
    final metrics = widget.existing?.values.keys ?? widget.recentFields;
    _fields = {for (final metric in metrics) metric: TextEditingController()};
    for (final e
        in widget.existing?.values.entries ??
            <MapEntry<BodyMetric, BodyValue>>[]) {
      _fields[e.key]!.text = _entryNumber(e.value.inUnit(_units[e.key]!));
    }
  }

  // Enough significant digits to avoid rounding historical data on an untouched
  // edit. Unchanged fields below retain the original value and unit verbatim.
  String _entryNumber(double value) {
    final text = value.toStringAsPrecision(12);
    if (text.contains('e')) return text;
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    _notes.dispose();
    super.dispose();
  }

  Future<void> _addField() async {
    final selected = await showModalBottomSheet<BodyMetric>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: ListView(
            children: [
              const ListTile(title: Text('Agregar una medida')),
              for (final metric in BodyMetric.values.where(
                (m) => !_fields.containsKey(m),
              ))
                ListTile(
                  title: Text(metric.label),
                  onTap: () => Navigator.pop(context, metric),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _fields[selected] = TextEditingController());
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final values = <BodyMetric, BodyValue>{};
    for (final field in _fields.entries) {
      final raw = field.value.text.trim();
      if (raw.isEmpty) continue;
      final original = widget.existing?.values[field.key];
      values[field.key] =
          original != null &&
              raw == _entryNumber(original.inUnit(_units[field.key]!))
          ? original
          : BodyValue(
              double.parse(raw.replaceAll(',', '.')),
              _units[field.key]!,
            );
    }
    if (values.isEmpty) {
      setState(
        () => _error = 'Ingresá al menos una medida. El resto es opcional.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.save(
        editingId: widget.existing?.id,
        expectedRevision: widget.existing?.revision,
        date: _date,
        values: values,
        notes: _notes.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo guardar. Tus entradas se conservan. Si el registro cambió en otra pantalla, volvé a abrirlo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Registrar medidas' : 'Editar medidas',
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Solo vos · guardado en este dispositivo'),
            const SizedBox(height: 8),
            const Text(
              'Completá solo lo que mediste. No calculamos grasa ni masa magra desde el peso.',
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(DateFormat('dd/MM/yyyy').format(_date)),
              onPressed: _busy
                  ? null
                  : () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(1900),
                        lastDate: DateUtils.dateOnly(
                          widget.now ?? DateTime.now(),
                        ),
                      );
                      if (date != null && mounted) setState(() => _date = date);
                    },
            ),
            const SizedBox(height: 16),
            for (final entry in _fields.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Text(
                        '${entry.key.label} (${_units[entry.key]})',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      label: '${entry.key.label} (${_units[entry.key]})',
                      child: TextFormField(
                        key: ValueKey('body-${entry.key.name}'),
                        controller: entry.value,
                        enabled: !_busy,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'Opcional',
                          errorMaxLines: 3,
                        ),
                        validator: (text) {
                          if (text == null || text.trim().isEmpty) return null;
                          final value = double.tryParse(
                            text.trim().replaceAll(',', '.'),
                          );
                          if (value == null) return 'Ingresá un número válido';
                          try {
                            BodyValue(
                              value,
                              _units[entry.key]!,
                            ).validate(entry.key);
                          } catch (_) {
                            return entry.key == BodyMetric.bodyFat
                                ? 'Usá un valor entre 0 y 100'
                                : 'Usá un valor positivo y finito';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            if (_fields.length < BodyMetric.values.length)
              OutlinedButton.icon(
                onPressed: _busy ? null : _addField,
                icon: const Icon(Icons.add),
                label: const Text('Agregar otra medida'),
              ),
            const SizedBox(height: 16),
            const Text('Notas privadas (opcional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notes,
              enabled: !_busy,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notas',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
            ),
            if (_error != null)
              Semantics(liveRegion: true, child: Text(_error!)),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.background,
                minimumSize: const Size(48, 48),
              ),
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(),
                    )
                  : const Icon(Icons.check),
              label: Text(_busy ? 'Guardando…' : 'Guardar medidas'),
            ),
          ],
        ),
      ),
    ),
  );
}
