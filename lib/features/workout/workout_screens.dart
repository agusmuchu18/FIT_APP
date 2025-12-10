import 'package:flutter/material.dart';
import '../../core/domain/entities.dart';
import '../../main.dart';
import '../../shared/template_selector.dart';

class WorkoutLiteScreen extends StatefulWidget {
  const WorkoutLiteScreen({super.key});

  @override
  State<WorkoutLiteScreen> createState() => _WorkoutLiteScreenState();
}

class _WorkoutLiteScreenState extends State<WorkoutLiteScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _durationController = TextEditingController(text: '30');
  final List<String> _templates = const ['Full-body rápido', 'HIIT 15', 'Cardio ligero'];

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _applyTemplate(String template) {
    setState(() {
      _nameController.text = template;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Workout Lite')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PremiumHeader(
                icon: Icons.flash_on_rounded,
                title: 'Registro express',
                description: 'Completa en menos de 1 minuto con solo lo esencial.',
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
                      Text('Detalles básicos', style: textTheme.titleMedium),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del workout',
                          prefixIcon: Icon(Icons.edit_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duración (min)',
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
                      Text('Sugerencias rápidas', style: textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Elige una plantilla y ajústala. Pensado para cerrar tu registro sin distracciones.',
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
                  onPressed: () => _saveQuickEntry(context),
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

  Future<void> _saveQuickEntry(BuildContext context) async {
    final entry = WorkoutEntry(
      id: DateTime.now().toIso8601String(),
      name: _nameController.text,
      durationMinutes: int.tryParse(_durationController.text) ?? 0,
      intensity: 'Moderado',
    );

    final repository = RepositoryScope.of(context);
    await repository.saveWorkout(entry, sync: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Guardado: ${entry.name}')),
    );
  }
}

class WorkoutProScreen extends StatefulWidget {
  const WorkoutProScreen({super.key});

  @override
  State<WorkoutProScreen> createState() => _WorkoutProScreenState();
}

class _WorkoutProScreenState extends State<WorkoutProScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final List<String> _templates = const ['Fuerza 5x5', 'Pecho/Espalda', 'Piernas detalle'];
  String _intensity = 'Moderado';

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _applyTemplate(String template) {
    setState(() {
      _nameController.text = template;
      _intensity = 'Alto';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Workout Pro')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PremiumHeader(
                icon: Icons.auto_graph_rounded,
                title: 'Modo profesional',
                description: 'Más campos para planificar como atleta o coach.',
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
                      Text('Plan del día', style: textTheme.titleMedium),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del workout',
                          prefixIcon: Icon(Icons.fitness_center_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _durationController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Duración (min)',
                                prefixIcon: Icon(Icons.timer_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Intensidad',
                              ),
                              child: Wrap(
                                spacing: 8,
                                children: ['Bajo', 'Moderado', 'Alto']
                                    .map(
                                      (level) => ChoiceChip(
                                        label: Text(level),
                                        selected: _intensity == level,
                                        onSelected: (_) =>
                                            setState(() => _intensity = level),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        ],
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
                      Text('Notas de técnica', style: textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Incluye ajustes de tempo, respiración o cues para la sesión.',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notas avanzadas',
                          prefixIcon: Icon(Icons.notes_rounded),
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
                  onPressed: () => _saveProEntry(context),
                  icon: const Icon(Icons.save_alt_rounded),
                  label: const Text('Guardar plantilla profesional'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProEntry(BuildContext context) async {
    final entry = WorkoutEntry(
      id: DateTime.now().toIso8601String(),
      name: _nameController.text,
      durationMinutes: int.tryParse(_durationController.text) ?? 0,
      intensity: _intensity,
      notes: _notesController.text,
      template: _nameController.text,
    );

    final repository = RepositoryScope.of(context);
    await repository.saveWorkout(entry, sync: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Plantilla avanzada creada: ${entry.name}')),
    );
  }
}

class _PremiumHeader extends StatelessWidget {
  const _PremiumHeader({
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
