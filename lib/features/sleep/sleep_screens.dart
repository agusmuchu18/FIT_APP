import 'package:flutter/material.dart';
import '../../core/domain/entities.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Sueño Lite')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _hoursController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Horas dormidas'),
            ),
            const SizedBox(height: 12),
            TemplateSelector(
              templates: _templates,
              onSelected: _applyTemplate,
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {
                final entry = SleepEntry(
                  id: DateTime.now().toIso8601String(),
                  hours: double.tryParse(_hoursController.text) ?? 0,
                  quality: 'Buena',
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Guardado: ${entry.hours}h')),
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

class SleepProScreen extends StatefulWidget {
  const SleepProScreen({super.key});

  @override
  State<SleepProScreen> createState() => _SleepProScreenState();
}

class _SleepProScreenState extends State<SleepProScreen> {
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _qualityController = TextEditingController(text: 'Buena');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Sueño Pro')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _hoursController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Horas dormidas'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _qualityController,
              decoration: const InputDecoration(labelText: 'Calidad percibida'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Observaciones detalladas'),
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
                final entry = SleepEntry(
                  id: DateTime.now().toIso8601String(),
                  hours: double.tryParse(_hoursController.text) ?? 0,
                  quality: _qualityController.text,
                  notes: _notesController.text,
                  template: _notesController.text,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Plantilla avanzada creada: ${entry.template}')),
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
