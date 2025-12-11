import 'package:flutter/material.dart';

import '../../core/domain/entities.dart';
import '../../main.dart';
import '../common/theme/app_colors.dart';
import '../common/widgets/app_choice_chip.dart';
import '../common/widgets/primary_button.dart';
import '../common/widgets/summary_card.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<String> _goals = const [
    'Mejorar salud general',
    'Ganar masa muscular',
    'Mejorar rendimiento deportivo',
    'Bajar estrés',
  ];
  final List<String> _experienceLevels = const [
    'Principiante',
    'Intermedio',
    'Avanzado',
  ];

  String? _goal;
  String? _experience;
  int _sessionsPerWeek = 3;
  String _mode = 'Lite';
  bool _isSaving = false;
  UserPreferences? _existing;

  @override
  void initState() {
    super.initState();
    _goal = _goals.first;
    _experience = _experienceLevels.first;
    _prefill();
  }

  Future<void> _prefill() async {
    final repository = RepositoryScope.of(context);
    final existing = await repository.getPreferences();
    if (!mounted) return;

    setState(() {
      _existing = existing;
      _goal = existing?.primaryGoal ?? _goals.first;
      _experience = existing?.experienceLevel ?? _experienceLevels.first;
      _sessionsPerWeek = existing?.targetSessionsPerWeek ?? _sessionsPerWeek;
      _mode = existing?.modePreference ?? _mode;
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
          'Conozcámonos',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (_existing != null)
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pushReplacementNamed('/home'),
              style:
                  TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
              child: const Text('Ir a inicio'),
            ),
        ],
      ),
      body: SafeArea(
        child: Container(
          color: AppColors.background,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(hasData: _existing != null),
                  const SizedBox(height: 18),
                  _QuestionCard(
                    title: 'Objetivo principal',
                    description:
                        'Usaremos esto para personalizar tus recordatorios y mensajes.',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _goals
                          .map(
                            (item) => AppChoiceChip(
                              label: item,
                              selected: _goal == item,
                              onSelected: (_) => setState(() => _goal = item),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _QuestionCard(
                    title: 'Nivel de experiencia',
                    description: 'Para adaptar la dificultad y los consejos.',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _experienceLevels
                          .map(
                            (item) => AppChoiceChip(
                              label: item,
                              selected: _experience == item,
                              onSelected: (_) => setState(() => _experience = item),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _QuestionCard(
                    title: 'Frecuencia objetivo',
                    description: '¿Cuántos días por semana planeas entrenar?',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_sessionsPerWeek días',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Slider(
                          value: _sessionsPerWeek.toDouble(),
                          min: 1,
                          max: 7,
                          divisions: 6,
                          label: '$_sessionsPerWeek',
                          activeColor: AppColors.accent,
                          inactiveColor: AppColors.surface,
                          onChanged: (value) => setState(
                            () => _sessionsPerWeek = value.round(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _QuestionCard(
                    title: 'Modo preferido',
                    description:
                        'Elige el modo que abrirá por defecto: Lite (rápido), Pro (detallado) o mixto.',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: ['Lite', 'Pro', 'Mixto']
                          .map(
                            (item) => AppChoiceChip(
                              label: item,
                              selected: _mode == item,
                              onSelected: (_) => setState(() => _mode = item),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    onPressed: _isSaving ? null : _submit,
                    icon: Icons.check_circle_rounded,
                    label: _existing == null
                        ? 'Comenzar con mi plan'
                        : 'Actualizar preferencias',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_goal == null || _experience == null) return;

    setState(() => _isSaving = true);

    final repository = RepositoryScope.of(context);
    final preferences = UserPreferences(
      id: _existing?.id ?? 'current-user',
      primaryGoal: _goal!,
      experienceLevel: _experience!,
      targetSessionsPerWeek: _sessionsPerWeek,
      modePreference: _mode,
    );

    await repository.savePreferences(preferences, sync: true);

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Preferencias guardadas: ${preferences.modePreference}')),
    );

    Navigator.of(context).pushReplacementNamed('/home');
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.hasData});

  final bool hasData;

  @override
  Widget build(BuildContext context) {
    final description = hasData
        ? 'Actualiza tus preferencias y mantén sincronizados tus objetivos.'
        : 'Un par de preguntas rápidas para personalizar tus flujos.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Configura tu experiencia',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SummaryCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
