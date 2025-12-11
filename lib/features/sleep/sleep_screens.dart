import 'package:flutter/material.dart';
import '../../core/domain/entities.dart';
import '../../main.dart';
import '../../shared/template_selector.dart';
import '../common/theme/app_colors.dart';
import '../common/widgets/primary_button.dart';
import '../common/widgets/summary_card.dart';

class SleepLiteScreen extends StatefulWidget {
  const SleepLiteScreen({super.key});

  @override
  State<SleepLiteScreen> createState() => _SleepLiteScreenState();
}

class _SleepLiteScreenState extends State<SleepLiteScreen> {
  final TextEditingController _hoursController = TextEditingController(text: '7.5');
  final List<String> _templates = const ['Día laboral', 'Fin de semana', 'Viaje'];

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textMuted),
      prefixIcon: Icon(icon, color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  void dispose() {
    _hoursController.dispose();
    super.dispose();
  }

  void _applyTemplate(String template) {
    setState(() {
      _hoursController.text = template.contains('Fin') ? '9' : '7.5';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Sueño Lite',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: Container(
          color: AppColors.background,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SleepHeader(
                  icon: Icons.nightlight_round,
                  title: 'Registro express',
                  description: 'Rutina nocturna en menos de 1 minuto, con datos esenciales.',
                ),
                const SizedBox(height: 18),
                SummaryCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('Horas de descanso'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _hoursController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(
                          'Horas dormidas',
                          Icons.timer_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SummaryCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _SectionTitle('Plantillas rápidas'),
                      SizedBox(height: 8),
                      Text(
                        'Elige la rutina que más se parezca a tu noche y ajusta las horas.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 12),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SummaryCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: TemplateSelector(
                    templates: _templates,
                    onSelected: _applyTemplate,
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  onPressed: () => _saveQuickSleep(context),
                  icon: Icons.check_rounded,
                  label: 'Guardar en menos de 1 minuto',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveQuickSleep(BuildContext context) async {
    final entry = SleepEntry(
      id: DateTime.now().toIso8601String(),
      hours: double.tryParse(_hoursController.text) ?? 0,
      quality: 'Buena',
    );

    final repository = RepositoryScope.of(context);
    await repository.saveSleep(entry, sync: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Guardado: ${entry.hours}h')),
    );
  }
}

class SleepProScreen extends StatefulWidget {
  const SleepProScreen({super.key});

  @override
  State<SleepProScreen> createState() => _SleepProScreenState();
}

class _SleepProScreenState extends State<SleepProScreen> {
  final TextEditingController _hoursController = TextEditingController(text: '8');
  final TextEditingController _qualityController =
      TextEditingController(text: 'Buena');
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _bedtimeController =
      TextEditingController(text: '23:00');
  final TextEditingController _wakeTimeController =
      TextEditingController(text: '07:00');
  bool _usedScreensBeforeSleep = false;
  int _stressLevel = 3;
  int _energyLevel = 3;
  final List<String> _templates = const ['Rutina circadiana', 'Recuperación', 'Jet lag'];

  @override
  void dispose() {
    _hoursController.dispose();
    _qualityController.dispose();
    _notesController.dispose();
    _bedtimeController.dispose();
    _wakeTimeController.dispose();
    super.dispose();
  }

  void _applyTemplate(String template) {
    setState(() {
      _hoursController.text = '8';
      _qualityController.text = 'Excelente';
      _notesController.text = 'Checklist de higiene del sueño para $template';
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sueño Pro')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SleepHeader(
                icon: Icons.self_improvement_rounded,
                title: 'Modo profesional',
                description: 'Control detallado para atletas: calidad, horas y hábitos.',
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sueño registrado', style: textTheme.titleMedium),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _hoursController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Horas dormidas',
                          prefixIcon: Icon(Icons.numbers_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: const InputDecoration(labelText: 'Calidad percibida'),
                        child: Wrap(
                          spacing: 8,
                          children: ['Excelente', 'Buena', 'Ligera']
                              .map(
                                (quality) => ChoiceChip(
                                  label: Text(quality),
                                  selected: _qualityController.text == quality,
                                  onSelected: (_) =>
                                      setState(() => _qualityController.text = quality),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cuestionario diario', style: textTheme.titleMedium),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _bedtimeController,
                        decoration: const InputDecoration(
                          labelText: 'Hora a la que fuiste a dormir',
                          prefixIcon: Icon(Icons.hotel_rounded),
                          hintText: '23:15',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _wakeTimeController,
                        decoration: const InputDecoration(
                          labelText: 'Hora de despertar',
                          prefixIcon: Icon(Icons.wb_sunny_rounded),
                          hintText: '07:00',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('¿Usaste pantallas antes de dormir?'),
                        value: _usedScreensBeforeSleep,
                        onChanged: (value) =>
                            setState(() => _usedScreensBeforeSleep = value),
                      ),
                      const SizedBox(height: 8),
                      Text('Nivel de estrés (1-5)', style: textTheme.titleSmall),
                      Slider(
                        value: _stressLevel.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: '$_stressLevel',
                        onChanged: (value) =>
                            setState(() => _stressLevel = value.round()),
                      ),
                      const SizedBox(height: 8),
                      Text('Energía al despertar (1-5)',
                          style: textTheme.titleSmall),
                      Slider(
                        value: _energyLevel.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: '$_energyLevel',
                        onChanged: (value) =>
                            setState(() => _energyLevel = value.round()),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notas y rituales', style: textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Describe rutina pre-sueño, ambiente y recuperación deseada.',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Observaciones detalladas',
                          prefixIcon: Icon(Icons.edit_note_rounded),
                        ),
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Plantillas detalladas', style: textTheme.titleMedium),
                      const SizedBox(height: 8),
                      TemplateSelector(
                        templates: _templates,
                        onSelected: _applyTemplate,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _saveProSleep(context),
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Guardar plantilla profesional'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProSleep(BuildContext context) async {
    final entry = SleepEntry(
      id: DateTime.now().toIso8601String(),
      hours: double.tryParse(_hoursController.text) ?? 0,
      quality: _qualityController.text,
      notes: _notesController.text,
      template: _notesController.text,
      bedtime: _bedtimeController.text,
      wakeTime: _wakeTimeController.text,
      screenUsageBeforeSleep: _usedScreensBeforeSleep,
      stressLevel: _stressLevel,
      wakeEnergy: _energyLevel,
    );

    final repository = RepositoryScope.of(context);
    await repository.saveSleep(entry, sync: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Plantilla avanzada creada: ${entry.template}')),
    );
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
