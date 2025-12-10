import 'package:flutter/material.dart';
import '../../core/domain/entities.dart';
import '../../main.dart';
import '../../shared/template_selector.dart';

class SleepLiteScreen extends StatefulWidget {
  const SleepLiteScreen({super.key});

  @override
  State<SleepLiteScreen> createState() => _SleepLiteScreenState();
}

class _SleepLiteScreenState extends State<SleepLiteScreen> {
  final TextEditingController _hoursController = TextEditingController(text: '7.5');
  final List<String> _templates = const ['Día laboral', 'Fin de semana', 'Viaje'];

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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sueño Lite')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SleepHeader(
                icon: Icons.nightlight_round,
                title: 'Registro express',
                description: 'Rutina nocturna en menos de 1 minuto, con datos esenciales.',
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Horas de descanso', style: textTheme.titleMedium),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _hoursController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Horas dormidas',
                          prefixIcon: Icon(Icons.timer_rounded),
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
                      Text('Plantillas rápidas', style: textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Elige la rutina que más se parezca a tu noche y ajusta las horas.',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
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
                  onPressed: () => _saveQuickSleep(context),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Guardar en menos de 1 minuto'),
                ),
              ),
            ],
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
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _qualityController =
      TextEditingController(text: 'Buena');
  final TextEditingController _notesController = TextEditingController();
  final List<String> _templates = const ['Rutina circadiana', 'Recuperación', 'Jet lag'];

  @override
  void dispose() {
    _hoursController.dispose();
    _qualityController.dispose();
    _notesController.dispose();
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sueño Pro')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SleepHeader(
                icon: Icons.self_improvement_rounded,
                title: 'Modo profesional',
                description: 'Control detallado para atletas: calidad, horas y hábitos.',
                colorScheme: colorScheme,
                textTheme: textTheme,
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
    required this.colorScheme,
    required this.textTheme,
  });

  final IconData icon;
  final String title;
  final String description;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: colorScheme.primary, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(description, style: textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
