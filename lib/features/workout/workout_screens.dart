import 'package:flutter/material.dart';
import '../../core/domain/entities.dart';
import '../../main.dart';
import '../../shared/template_selector.dart';
import '../common/theme/app_colors.dart';
import '../common/widgets/primary_button.dart';
import '../common/widgets/summary_card.dart';

class WorkoutLiteScreen extends StatefulWidget {
  const WorkoutLiteScreen({super.key});

  @override
  State<WorkoutLiteScreen> createState() => _WorkoutLiteScreenState();
}

class _WorkoutLiteScreenState extends State<WorkoutLiteScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _durationController = TextEditingController(text: '30');
  final List<String> _templates = const ['Full-body rápido', 'HIIT 15', 'Cardio ligero'];

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Workout Lite',
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
                const _PremiumHeader(
                  icon: Icons.flash_on_rounded,
                  title: 'Registro express',
                  description:
                      'Completa en menos de 1 minuto con solo lo esencial.',
                ),
                const SizedBox(height: 18),
                SummaryCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('Detalles básicos'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        decoration:
                            _inputDecoration('Nombre del workout', Icons.edit_rounded),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(
                          'Duración (min)',
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
                      _SectionTitle('Sugerencias rápidas'),
                      SizedBox(height: 8),
                      Text(
                        'Elige una plantilla y ajústala. Pensado para cerrar tu registro sin distracciones.',
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
                  onPressed: () => _saveQuickEntry(context),
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

class _PremiumHeader extends StatelessWidget {
  const _PremiumHeader({
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
