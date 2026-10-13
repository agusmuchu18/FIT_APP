import 'package:flutter/material.dart';

import '../../common/theme/app_colors.dart';
import '../../common/widgets/fit_glyph.dart';

class PrimaryStartWorkoutCard extends StatelessWidget {
  const PrimaryStartWorkoutCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: AppColors.card,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxWidth * 9 / 16,
              ),
              child: Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/workout/session_strength.webp',
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                      excludeFromSemantics: true,
                      errorBuilder: (context, error, stackTrace) =>
                          const ColoredBox(color: AppColors.card),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.64),
                            Colors.black.withValues(alpha: 0.64),
                            Colors.transparent,
                          ],
                          stops: const [0, 0.5, 1],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * 0.68,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FitGlyph(
                            kind: FitGlyphKind.workout,
                            color: AppColors.accentTraining,
                            size: 24,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Entrenamiento libre',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Registrá cada serie a tu ritmo.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Iniciar sesión',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const FitGlyph(
                                kind: FitGlyphKind.arrowForward,
                                color: AppColors.textPrimary,
                                size: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
    required this.glyph,
    this.imageAsset,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final FitGlyphKind glyph;
  final String? imageAsset;
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
          image: imageAsset == null
              ? null
              : DecorationImage(
                  image: AssetImage(imageAsset!),
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                  colorFilter: ColorFilter.mode(
                    AppColors.card.withValues(alpha: 0.78),
                    BlendMode.srcOver,
                  ),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FitGlyph(kind: glyph, color: AppColors.accent, size: 24),
            const SizedBox(height: 12),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
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
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Continuar entrenamiento',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Tiempo transcurrido: $elapsed',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
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
    required this.typeTag,
    required this.secondaryTag,
    required this.exercisePreview,
    required this.exerciseCount,
    required this.estimatedMinutes,
    required this.lastUsed,
    required this.isPinned,
    required this.onTap,
    required this.onStartTap,
    required this.onMenuSelected,
  });

  final String title;
  final String typeTag;
  final String? secondaryTag;
  final List<String> exercisePreview;
  final int exerciseCount;
  final int? estimatedMinutes;
  final String lastUsed;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onStartTap;
  final ValueChanged<String> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = _accentForType(typeTag, colorScheme);
    final preview = exercisePreview.take(2).toList(growable: false);
    final remaining = exercisePreview.length - preview.length;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      onLongPress: () => onMenuSelected('menu'),
      child: Ink(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
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
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: onMenuSelected,
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Editar'),
                          ),
                          const PopupMenuItem(
                            value: 'duplicate',
                            child: Text('Duplicar'),
                          ),
                          PopupMenuItem(
                            value: 'pin',
                            child: Text(isPinned ? 'Desfijar' : 'Fijar'),
                          ),
                          const PopupMenuItem(
                            value: 'move',
                            child: Text('Mover a carpeta'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Eliminar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _compactChip(typeTag),
                      if (secondaryTag != null &&
                          secondaryTag!.trim().isNotEmpty &&
                          secondaryTag != typeTag)
                        _compactChip(secondaryTag!),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$exerciseCount ejercicios${estimatedMinutes != null ? ' · ~$estimatedMinutes min' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastUsed,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final exercise in preview)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _compactChip(exercise),
                          ),
                        if (remaining > 0) _compactChip('+$remaining'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: onStartTap,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: const VisualDensity(
                          horizontal: -2,
                          vertical: -2,
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text('Iniciar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactChip(String label) {
    return Chip(
      label: Text(label, overflow: TextOverflow.ellipsis),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Color _accentForType(String tag, ColorScheme colorScheme) {
    final normalized = tag.toLowerCase();
    if (normalized.contains('gym')) return colorScheme.primary;
    if (normalized.contains('deporte') || normalized.contains('outdoor')) {
      return colorScheme.secondary;
    }
    return colorScheme.outline;
  }
}

class RoutineFolderCard extends StatelessWidget {
  const RoutineFolderCard({
    super.key,
    required this.name,
    required this.count,
    required this.onTap,
    this.onMenuSelected,
    this.isVirtual = false,
  });

  final String name;
  final int count;
  final VoidCallback onTap;
  final ValueChanged<String>? onMenuSelected;
  final bool isVirtual;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
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
                Icon(
                  isVirtual
                      ? Icons.folder_off_outlined
                      : Icons.folder_open_rounded,
                  color: AppColors.accent,
                ),
                const Spacer(),
                if (!isVirtual && onMenuSelected != null)
                  PopupMenuButton<String>(
                    onSelected: onMenuSelected,
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                      PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '$count ${count == 1 ? 'rutina' : 'rutinas'}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
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
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
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
              color: colorScheme.primary.withValues(alpha: 0.12),
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
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Usá ‘Nueva rutina’ o ‘Buscar rutinas’ para empezar.',
                  maxLines: 2,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
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
