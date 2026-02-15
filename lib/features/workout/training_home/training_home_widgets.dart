import 'package:flutter/material.dart';

import '../../common/theme/app_colors.dart';

class PrimaryStartWorkoutCard extends StatelessWidget {
  const PrimaryStartWorkoutCard({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        overlayColor: MaterialStateProperty.resolveWith(
          (states) => states.contains(MaterialState.pressed)
              ? colorScheme.primary.withOpacity(0.06)
              : colorScheme.primary.withOpacity(0.02),
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: colorScheme.surface,
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary.withOpacity(0.12),
                ),
                child: Icon(Icons.add, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Registrar entrenamiento (sin rutina)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class RoutineActionTile extends StatelessWidget {
  const RoutineActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: AppColors.card,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: AppColors.accent, size: 24),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class ContinueWorkoutCard extends StatelessWidget {
  const ContinueWorkoutCard({
    super.key,
    required this.elapsed,
    required this.onContinue,
    required this.onDiscard,
  });

  final String elapsed;
  final VoidCallback onContinue;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Continuar entrenamiento', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Tiempo transcurrido: $elapsed', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onContinue,
                  child: const Text('Continuar'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: onDiscard, child: const Text('Descartar')),
            ],
          ),
        ],
      ),
    );
  }
}

class RoutineMiniCard extends StatelessWidget {
  const RoutineMiniCard({
    super.key,
    required this.title,
    required this.tags,
    required this.exerciseCount,
    required this.estimatedMinutes,
    required this.lastUsed,
    required this.isPinned,
    required this.onTap,
    required this.onMenuSelected,
  });

  final String title;
  final List<String> tags;
  final int exerciseCount;
  final int? estimatedMinutes;
  final String lastUsed;
  final bool isPinned;
  final VoidCallback onTap;
  final ValueChanged<String> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      onLongPress: () => onMenuSelected('menu'),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: onMenuSelected,
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    const PopupMenuItem(value: 'duplicate', child: Text('Duplicar')),
                    PopupMenuItem(
                      value: 'pin',
                      child: Text(isPinned ? 'Desfijar' : 'Fijar'),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                )
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: tags
                  .take(2)
                  .map(
                    (tag) => Chip(
                      label: Text(tag),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
            const Spacer(),
            Text('$exerciseCount ejercicios', style: theme.textTheme.bodySmall),
            if (estimatedMinutes != null)
              Text('~$estimatedMinutes min', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
            Text('Última vez: $lastUsed', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class EmptyRoutinesInfoCard extends StatelessWidget {
  const EmptyRoutinesInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withOpacity(0.12),
            ),
            child: Icon(Icons.bookmark_border, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Todavía no tenés rutinas guardadas.',
                  maxLines: 2,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Usá ‘Nueva rutina’ o ‘Buscar rutinas’ para empezar.',
                  maxLines: 2,
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
