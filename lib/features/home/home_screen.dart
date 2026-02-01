import 'package:flutter/material.dart';

import '../../core/domain/entities.dart';
import '../../main.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = RepositoryScope.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FIT Home'),
        actions: [
          IconButton(
            tooltip: 'Editar preferencias',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.of(context).pushNamed('/'),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<UserPreferences?>(
          future: repository.getPreferences(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final preferences = snapshot.data;
            if (preferences == null) {
              return _EmptyState(theme: theme);
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _WelcomeCard(preferences: preferences),
                const SizedBox(height: 12),
                _ModuleCard(
                  title: 'Entrenamiento',
                  description: 'Registra tus sesiones y revisa el progreso.',
                  icon: Icons.fitness_center_rounded,
                  route: '/workout',
                ),
                const SizedBox(height: 12),
                _ModuleCard(
                  title: 'Nutrición',
                  description: 'Captura tus comidas y controla tus macros.',
                  icon: Icons.restaurant_rounded,
                  route: '/nutrition',
                ),
                const SizedBox(height: 12),
                _ModuleCard(
                  title: 'Sueño y recuperación',
                  description: 'Registra tu descanso y controla el estrés.',
                  icon: Icons.bedtime_rounded,
                  route: '/sleep',
                ),
                const SizedBox(height: 12),
                _SecondaryActions(theme: theme),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.preferences});

  final UserPreferences preferences;

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
            Row(
              children: [
                Icon(Icons.emoji_events_rounded,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Bienvenido de nuevo',
                    style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text('Objetivo: ${preferences.primaryGoal}',
                style: theme.textTheme.bodyLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Tag(text: 'Experiencia: ${preferences.experienceLevel}'),
                _Tag(text: 'Frecuencia: ${preferences.targetSessionsPerWeek} días/sem'),
                _Tag(text: 'Modo: ${preferences.modePreference}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
  });

  final String title;
  final String description;
  final IconData icon;
  final String route;

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
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pushNamed(route),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Abrir módulo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Explora más', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed('/analytics/overview'),
                  icon: const Icon(Icons.bar_chart_rounded),
                  label: const Text('Estadísticas'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed('/groups/list'),
                  icon: const Icon(Icons.groups_rounded),
                  label: const Text('Grupos de atletas'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Configura tus preferencias',
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Responde las preguntas del onboarding para abrir el modo correcto y ver mensajes personalizados.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Abrir onboarding'),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      backgroundColor: theme.colorScheme.surfaceVariant,
      label: Text(text),
      avatar: const Icon(Icons.check_circle_rounded, size: 18),
    );
  }
}
