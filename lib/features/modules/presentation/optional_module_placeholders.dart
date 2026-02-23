import 'package:flutter/material.dart';

import '../../common/theme/app_colors.dart';

class PsychologyModuleScreen extends StatelessWidget {
  const PsychologyModuleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ModulePlaceholderShell(
      title: 'Psicología',
      subtitle: 'Mentalidad, estrés y adherencia',
      actions: const [
        'Check-in emocional',
        'Respiración guiada',
        'Bloque de enfoque',
      ],
    );
  }
}

class LabModuleScreen extends StatelessWidget {
  const LabModuleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ModulePlaceholderShell(
      title: 'Laboratorio personal',
      subtitle: 'Probá hipótesis y medí resultados',
      actions: const [
        'Crear experimento',
        'Definir variable principal',
        'Comparar resultados',
      ],
    );
  }
}

class MenstrualModuleScreen extends StatelessWidget {
  const MenstrualModuleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ModulePlaceholderShell(
      title: 'Ciclo menstrual',
      subtitle: 'Seguimiento y predicciones',
      actions: const [
        'Registrar día',
        'Síntomas y energía',
        'Predicción del próximo ciclo',
      ],
    );
  }
}

class _ModulePlaceholderShell extends StatelessWidget {
  const _ModulePlaceholderShell({
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final List<String> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            subtitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withOpacity(0.86),
                ),
          ),
          const SizedBox(height: 14),
          for (final action in actions) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded),
                  const SizedBox(width: 10),
                  Expanded(child: Text(action)),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
