import 'package:flutter/material.dart';

import '../../../../core/data/home_modules_controller.dart';
import '../../../common/theme/app_colors.dart';

class OptionalModule {
  const OptionalModule({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.emptyMessage,
    required this.emptyCta,
    this.insight,
    this.startsEmpty = true,
  });

  final ModuleId id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final String emptyMessage;
  final String emptyCta;
  final String? insight;
  final bool startsEmpty;
}

const _optionalModulesCatalog = <ModuleId, OptionalModule>{
  ModuleId.habits: OptionalModule(
    id: ModuleId.habits,
    title: 'Hábitos',
    subtitle: 'Checklist diario y rachas',
    icon: Icons.checklist_rounded,
    route: '/habits',
    insight: 'Vas 4 días seguidos. ¡Gran consistencia!',
    emptyMessage: 'Elegí 3 hábitos para empezar',
    emptyCta: 'Ir',
    startsEmpty: false,
  ),
  ModuleId.psychology: OptionalModule(
    id: ModuleId.psychology,
    title: 'Psicología',
    subtitle: 'Mentalidad, estrés y adherencia',
    icon: Icons.psychology_alt_rounded,
    route: '/psychology',
    emptyMessage: 'Hacé un check-in de ánimo',
    emptyCta: 'Ir',
  ),
  ModuleId.lab: OptionalModule(
    id: ModuleId.lab,
    title: 'Laboratorio',
    subtitle: 'Probá hipótesis y medí resultados',
    icon: Icons.science_rounded,
    route: '/lab',
    emptyMessage: 'Creá tu primer experimento',
    emptyCta: 'Ir',
  ),
  ModuleId.menstrual: OptionalModule(
    id: ModuleId.menstrual,
    title: 'Ciclo',
    subtitle: 'Seguimiento y predicciones',
    icon: Icons.favorite_rounded,
    route: '/menstrual',
    emptyMessage: 'Registrá tu día 1',
    emptyCta: 'Ir',
  ),
};

class HomeOptionalModulesSection extends StatelessWidget {
  const HomeOptionalModulesSection({
    super.key,
    required this.enabledModules,
    required this.optionalOrder,
    required this.onNavigate,
    required this.onRemove,
    required this.onOpenSettings,
  });

  final Set<ModuleId> enabledModules;
  final List<ModuleId> optionalOrder;
  final ValueChanged<String> onNavigate;
  final ValueChanged<ModuleId> onRemove;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final orderedEnabledModules = optionalOrder
        .where(enabledModules.contains)
        .map((id) => _optionalModulesCatalog[id])
        .whereType<OptionalModule>()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Módulos',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: orderedEnabledModules.isEmpty
              ? _ModulesEmptyState(
                  key: const ValueKey('empty-modules-state'),
                  onOpenSettings: onOpenSettings,
                )
              : Column(
                  key: ValueKey('modules-${orderedEnabledModules.map((m) => m.id.name).join('-')}'),
                  children: [
                    for (final module in orderedEnabledModules) ...[
                      HomeModuleCard(
                        key: ValueKey(module.id.name),
                        module: module,
                        onTap: () => onNavigate(module.route),
                        onRemove: () => onRemove(module.id),
                        onReorder: onOpenSettings,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class HomeModuleCard extends StatelessWidget {
  const HomeModuleCard({
    super.key,
    required this.module,
    required this.onTap,
    required this.onRemove,
    required this.onReorder,
  });

  final OptionalModule module;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onReorder;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isEmpty = module.startsEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.07),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(module.icon, size: 30, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        module.subtitle,
                        style: textTheme.bodySmall?.copyWith(
                          fontSize: 12.5,
                          color: Colors.white.withOpacity(0.68),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (isEmpty)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                module.emptyMessage,
                                style: textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withOpacity(0.82),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: onTap,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 32),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(module.emptyCta),
                            ),
                          ],
                        )
                      else
                        Text(
                          module.insight ?? '',
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.82),
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (value) {
                    if (value == 'reorder') {
                      onReorder();
                    } else if (value == 'remove') {
                      onRemove();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem<String>(
                      value: 'reorder',
                      child: Text('Reordenar'),
                    ),
                    PopupMenuItem<String>(
                      value: 'remove',
                      child: Text('Quitar de Home'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModulesEmptyState extends StatelessWidget {
  const _ModulesEmptyState({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personalizá tu Home',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Activá módulos opcionales para ver insights y accesos rápidos acá.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.70),
                ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onOpenSettings,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar módulos'),
          ),
        ],
      ),
    );
  }
}
