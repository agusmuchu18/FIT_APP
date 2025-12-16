import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/domain/entities.dart';
import '../../main.dart';
import '../common/theme/app_colors.dart';
import '../common/widgets/primary_button.dart';
import '../common/widgets/summary_card.dart';
import 'domain/sleep_time_utils.dart';

class SleepLiteScreen extends StatefulWidget {
  const SleepLiteScreen({super.key});

  @override
  State<SleepLiteScreen> createState() => _SleepLiteScreenState();
}

class _SleepLiteScreenState extends State<SleepLiteScreen> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _bedTime = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 0);
  String _quality = 'Buena';

  int? get _bedMinutes => _bedTime.hour * 60 + _bedTime.minute;
  int? get _wakeMinutes => _wakeTime.hour * 60 + _wakeTime.minute;

  int? get _durationMinutes => _bedMinutes != null && _wakeMinutes != null
      ? computeDurationMinutes(bedMin: _bedMinutes!, wakeMin: _wakeMinutes!)
      : null;

  @override
  Widget build(BuildContext context) {
    final durationMinutes = _durationMinutes;
    final durationError = durationMinutes == null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Sueño Lite'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SleepHeader(
                icon: Icons.nightlight_round,
                title: 'Registro express',
                description:
                    'Captura tu noche en segundos: hora de dormir, despertar y calidad.',
              ),
              const SizedBox(height: 18),
              SummaryCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Fecha'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _ElevatedField(
                            label: _formatDate(_selectedDate),
                            icon: Icons.event,
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ElevatedField(
                            label:
                                'Día ${['L', 'M', 'X', 'J', 'V', 'S', 'D'][_selectedDate.weekday - 1]}',
                            icon: Icons.today_outlined,
                            onTap: _pickDate,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SummaryCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Horario'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ElevatedField(
                            label: 'A dormir ${_bedTime.format(context)}',
                            icon: Icons.bedtime_outlined,
                            onTap: () => _pickTime(isBed: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ElevatedField(
                            label: 'Despertar ${_wakeTime.format(context)}',
                            icon: Icons.wb_sunny_outlined,
                            onTap: () => _pickTime(isBed: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            durationError
                                ? Icons.error_outline
                                : Icons.timer_outlined,
                            color: durationError
                                ? Colors.redAccent
                                : AppColors.accentSecondary,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Duración estimada',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                durationError
                                    ? 'Revisa las horas (mín 2h, máx 16h)'
                                    : '${(durationMinutes! / 60).toStringAsFixed(1)} h',
                                style: TextStyle(
                                  color:
                                      durationError ? Colors.redAccent : Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SummaryCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Calidad rápida'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: ['Excelente', 'Buena', 'Ligera']
                          .map(
                            (q) => ChoiceChip(
                              label: Text(q),
                              selected: _quality == q,
                              onSelected: (_) => setState(() => _quality = q),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                onPressed: durationError ? null : () => _saveLite(context),
                icon: Icons.check_circle,
                label: 'Guardar',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime({required bool isBed}) async {
    final initial = isBed ? _bedTime : _wakeTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isBed) {
          _bedTime = picked;
        } else {
          _wakeTime = picked;
        }
      });
    }
  }

  Future<void> _saveLite(BuildContext context) async {
    final durationMinutes = _durationMinutes;
    if (durationMinutes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Duración inválida. Ajusta los horarios.')),
      );
      return;
    }

    final entry = SleepEntry(
      id: const Uuid().v4(),
      hours: durationMinutes / 60,
      quality: _quality,
      qualityScore: _qualityScore(_quality),
      bedtime: formatMinutesToHHmm(_bedMinutes!),
      wakeTime: formatMinutesToHHmm(_wakeMinutes!),
      sleepDate: _formatDateIso(_selectedDate),
      tags: const [],
    );

    final repository = RepositoryScope.of(context);
    await repository.saveSleep(entry, sync: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Guardado: ${entry.hours.toStringAsFixed(1)} h')),
    );
    Navigator.pop(context);
  }
}

class SleepProScreen extends StatefulWidget {
  const SleepProScreen({super.key});

  @override
  State<SleepProScreen> createState() => _SleepProScreenState();
}

class _SleepProScreenState extends State<SleepProScreen> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _bedTime = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 0);
  String _quality = 'Buena';
  String? _selectedTemplate;
  bool _usedScreensBeforeSleep = false;
  int _stressLevel = 3;
  int _energyLevel = 3;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _customTagController = TextEditingController();
  final List<String> _availableTags = const [
    'cafeina_tarde',
    'alcohol',
    'siesta',
    'entreno_tarde',
    'estres_alto',
    'pantallas',
  ];
  final Set<String> _selectedTags = <String>{};

  final List<_TemplatePreset> _templates = const [
    _TemplatePreset(
      name: 'Recuperación',
      quality: 'Excelente',
      tags: ['entreno_tarde', 'siesta'],
      notes: 'Cenar ligero, estiramientos suaves, respiración 4-7-8.',
    ),
    _TemplatePreset(
      name: 'Jet lag',
      quality: 'Ligera',
      tags: ['pantallas', 'estres_alto'],
      notes: 'Bloquear luz azul, ajustar horario de comidas y luz solar.',
    ),
    _TemplatePreset(
      name: 'Día laboral',
      quality: 'Buena',
      tags: ['cafeina_tarde'],
      notes: 'Higiene básica + corte cafeína 6h antes de dormir.',
    ),
  ];

  int? get _bedMinutes => _bedTime.hour * 60 + _bedTime.minute;
  int? get _wakeMinutes => _wakeTime.hour * 60 + _wakeTime.minute;
  int? get _durationMinutes => _bedMinutes != null && _wakeMinutes != null
      ? computeDurationMinutes(bedMin: _bedMinutes!, wakeMin: _wakeMinutes!)
      : null;

  @override
  void dispose() {
    _notesController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final durationMinutes = _durationMinutes;
    final durationError = durationMinutes == null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Sueño Pro'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SleepHeader(
                icon: Icons.self_improvement_rounded,
                title: 'Modo profesional',
                description:
                    'Detalle completo: hábitos, calidad, estrés y energía al despertar.',
              ),
              const SizedBox(height: 16),
              SummaryCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Fecha y horario'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ElevatedField(
                            label: _formatDate(_selectedDate),
                            icon: Icons.event,
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ElevatedField(
                            label: 'Dormir ${_bedTime.format(context)}',
                            icon: Icons.bedtime_outlined,
                            onTap: () => _pickTime(isBed: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ElevatedField(
                            label: 'Despertar ${_wakeTime.format(context)}',
                            icon: Icons.wb_twilight,
                            onTap: () => _pickTime(isBed: false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Duración',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  durationError
                                      ? 'Revisa horas'
                                      : '${(durationMinutes! / 60).toStringAsFixed(1)} h',
                                  style: TextStyle(
                                    color: durationError
                                        ? Colors.redAccent
                                        : AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (durationError)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Duración fuera de rango (2-16h). Ajusta los horarios.',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SummaryCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Calidad, pantallas y energía'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: ['Excelente', 'Buena', 'Ligera', 'Mala']
                          .map(
                            (q) => ChoiceChip(
                              label: Text(q),
                              selected: _quality == q,
                              onSelected: (_) => setState(() => _quality = q),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('¿Usaste pantallas antes de dormir?'),
                      value: _usedScreensBeforeSleep,
                      onChanged: (value) =>
                          setState(() => _usedScreensBeforeSleep = value),
                    ),
                    const SizedBox(height: 8),
                    _LabeledSlider(
                      label: 'Estrés percibido',
                      value: _stressLevel,
                      onChanged: (value) => setState(() => _stressLevel = value),
                    ),
                    _LabeledSlider(
                      label: 'Energía al despertar',
                      value: _energyLevel,
                      onChanged: (value) => setState(() => _energyLevel = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SummaryCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Hábitos (tags)'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _availableTags
                          .map(
                            (tag) => FilterChip(
                              label: Text(tag.replaceAll('_', ' ')),
                              selected: _selectedTags.contains(tag),
                              onSelected: (selected) => setState(() {
                                if (selected) {
                                  _selectedTags.add(tag);
                                } else {
                                  _selectedTags.remove(tag);
                                }
                              }),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customTagController,
                            decoration: const InputDecoration(
                              labelText: 'Agregar tag',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            final tag = _customTagController.text.trim();
                            if (tag.isNotEmpty) {
                              setState(() {
                                _selectedTags.add(tag);
                                _customTagController.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SummaryCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Notas y plantilla'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Observaciones',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: _templates
                          .map(
                            (t) => ChoiceChip(
                              label: Text(t.name),
                              selected: _selectedTemplate == t.name,
                              onSelected: (_) {
                                setState(() {
                                  _selectedTemplate = t.name;
                                  _quality = t.quality;
                                  _selectedTags
                                    ..clear()
                                    ..addAll(t.tags);
                                  _notesController.text = t.notes;
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                onPressed: durationError ? null : () => _savePro(context),
                icon: Icons.save_alt,
                label: 'Guardar Pro',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime({required bool isBed}) async {
    final initial = isBed ? _bedTime : _wakeTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isBed) {
          _bedTime = picked;
        } else {
          _wakeTime = picked;
        }
      });
    }
  }

  Future<void> _savePro(BuildContext context) async {
    final durationMinutes = _durationMinutes;
    if (durationMinutes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Duración inválida, ajusta horas.')),
      );
      return;
    }

    final entry = SleepEntry(
      id: const Uuid().v4(),
      hours: durationMinutes / 60,
      quality: _quality,
      qualityScore: _qualityScore(_quality),
      bedtime: formatMinutesToHHmm(_bedMinutes!),
      wakeTime: formatMinutesToHHmm(_wakeMinutes!),
      sleepDate: _formatDateIso(_selectedDate),
      tags: _selectedTags.toList(),
      template: _selectedTemplate,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      screenUsageBeforeSleep: _usedScreensBeforeSleep,
      stressLevel: _stressLevel,
      wakeEnergy: _energyLevel,
    );

    final repository = RepositoryScope.of(context);
    await repository.saveSleep(entry, sync: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sueño Pro guardado.')),
    );
    Navigator.pop(context);
  }
}

class _SleepHeader extends StatelessWidget {
  const _SleepHeader({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return SummaryCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2A3D),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.accentSecondary, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        fontFamily: 'Inter',
      ),
    );
  }
}

class _ElevatedField extends StatelessWidget {
  const _ElevatedField({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}

class _TemplatePreset {
  const _TemplatePreset({
    required this.name,
    required this.quality,
    required this.tags,
    required this.notes,
  });

  final String name;
  final String quality;
  final List<String> tags;
  final String notes;
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$day/$month';
}

String _formatDateIso(DateTime date) => date.toIso8601String().split('T').first;

int _qualityScore(String quality) {
  final normalized = quality.toLowerCase();
  if (normalized.contains('excel')) return 5;
  if (normalized.contains('buena') || normalized.contains('very')) return 4;
  if (normalized.contains('ok') || normalized.contains('normal')) return 3;
  if (normalized.contains('lig')) return 2;
  if (normalized.contains('mala')) return 1;
  return 3;
}
