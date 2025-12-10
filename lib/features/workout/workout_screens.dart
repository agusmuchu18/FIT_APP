import 'package:flutter/material.dart';
import '../../core/domain/entities.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Workout Lite')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre del workout'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Duración (min)'),
            ),
            const SizedBox(height: 12),
            TemplateSelector(
              templates: _templates,
              onSelected: _applyTemplate,
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {
                final entry = WorkoutEntry(
                  id: DateTime.now().toIso8601String(),
                  name: _nameController.text,
                  durationMinutes: int.tryParse(_durationController.text) ?? 0,
                  intensity: 'Moderado',
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Guardado: ${entry.name}')),
                );
              },
              child: const Text('Guardar rápido'),
            ),
          ],
        ),
      ),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Workout Pro')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre del workout'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _intensity,
              decoration: const InputDecoration(labelText: 'Intensidad'),
              items: const [
                DropdownMenuItem(value: 'Bajo', child: Text('Bajo')),
                DropdownMenuItem(value: 'Moderado', child: Text('Moderado')),
                DropdownMenuItem(value: 'Alto', child: Text('Alto')),
              ],
              onChanged: (value) => setState(() => _intensity = value ?? 'Moderado'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Duración (minutos)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notas avanzadas'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TemplateSelector(
              title: 'Plantillas detalladas',
              templates: _templates,
              onSelected: _applyTemplate,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                final entry = WorkoutEntry(
                  id: DateTime.now().toIso8601String(),
                  name: _nameController.text,
                  durationMinutes: int.tryParse(_durationController.text) ?? 0,
                  intensity: _intensity,
                  notes: _notesController.text,
                  template: _nameController.text,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Plantilla avanzada creada: ${entry.name}')),
                );
              },
              icon: const Icon(Icons.save_alt),
              label: const Text('Guardar plantilla'),
            ),
          ],
        ),
      ),
    );
  }
}
