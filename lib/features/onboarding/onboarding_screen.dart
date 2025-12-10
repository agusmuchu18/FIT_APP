import 'package:flutter/material.dart';

import '../../core/domain/entities.dart';
import '../../main.dart';

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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conozcámonos'),
        actions: [
          if (_existing != null)
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pushReplacementNamed('/home'),
              child: const Text('Ir a inicio'),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _Header(theme: theme, hasData: _existing != null),
              const SizedBox(height: 16),
              _QuestionCard(
                title: 'Objetivo principal',
                description:
                    'Usaremos esto para personalizar tus recordatorios y mensajes.',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _goals
                      .map(
                        (item) => ChoiceChip(
                          label: Text(item),
                          selected: _goal == item,
                          onSelected: (_) => setState(() => _goal = item),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              _QuestionCard(
                title: 'Nivel de experiencia',
                description: 'Para adaptar la dificultad y los consejos.',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _experienceLevels
                      .map(
                        (item) => ChoiceChip(
                          label: Text(item),
                          selected: _experience == item,
                          onSelected: (_) => setState(() => _experience = item),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              _QuestionCard(
                title: 'Frecuencia objetivo',
                description: '¿Cuántos días por semana planeas entrenar?',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$_sessionsPerWeek días'),
                    Slider(
                      value: _sessionsPerWeek.toDouble(),
                      divisions: 6,
                      min: 1,
                      max: 7,
                      label: '$_sessionsPerWeek',
                      onChanged: (value) =>
                          setState(() => _sessionsPerWeek = value.round()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _QuestionCard(
                title: 'Modo preferido',
                description:
                    'Elige el modo que abrirá por defecto: Lite (rápido), Pro (detallado) o mixto.',
                child: Wrap(
                  spacing: 8,
                  children: ['Lite', 'Pro', 'Mixto']
                      .map(
                        (item) => ChoiceChip(
                          label: Text(item),
                          selected: _mode == item,
                          onSelected: (_) => setState(() => _mode = item),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: const Icon(Icons.check_circle_rounded),
                label: Text(_existing == null
                    ? 'Comenzar con mi plan'
                    : 'Actualizar preferencias'),
              ),
            ],
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
  const _Header({required this.theme, required this.hasData});

  final ThemeData theme;
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Configura tu experiencia', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          hasData
              ? 'Actualiza tus preferencias y mantén sincronizados tus objetivos.'
              : 'Un par de preguntas rápidas para personalizar tus flujos.',
          style: theme.textTheme.bodyLarge,
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
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
