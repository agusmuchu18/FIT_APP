import 'package:flutter/material.dart';

import '../../../core/data/home_modules_controller.dart';
import '../../common/theme/app_colors.dart';

class ModulesSettingsScreen extends StatefulWidget {
  const ModulesSettingsScreen({super.key});

  @override
  State<ModulesSettingsScreen> createState() => _ModulesSettingsScreenState();
}

class _ModulesSettingsScreenState extends State<ModulesSettingsScreen> {
  final HomeModulesController _controller = HomeModulesController.instance;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChange);
    if (!_controller.initialized) {
      _controller.load();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    final enabled = _controller.enabledModules;
    final activeModules = _controller.optionalOrder.where(enabled.contains).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Módulos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(
            title: 'Módulos base (incluidos)',
            child: const Column(
              children: [
                _BaseModuleTile(title: 'Entrenamiento'),
                Divider(height: 1),
                _BaseModuleTile(title: 'Alimentación'),
                Divider(height: 1),
                _BaseModuleTile(title: 'Sueño'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionCard(
            title: 'Módulos opcionales',
            child: Column(
              children: [
                for (final module in ModuleId.values)
                  SwitchListTile(
                    value: enabled.contains(module),
                    onChanged: (value) => _controller.setEnabled(module, value),
                    title: Text(_moduleTitle(module)),
                    subtitle: Text(_moduleSubtitle(module)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionCard(
            title: 'Orden en Home',
            child: activeModules.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Activá módulos para habilitar el reordenamiento.'),
                  )
                : ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: activeModules.length,
                    onReorder: _controller.reorderEnabledModules,
                    buildDefaultDragHandles: false,
                    itemBuilder: (context, index) {
                      final module = activeModules[index];
                      return ListTile(
                        key: ValueKey('module-${module.name}'),
                        title: Text(_moduleTitle(module)),
                        subtitle: Text(_moduleSubtitle(module)),
                        leading: const Icon(Icons.drag_indicator_rounded),
                        trailing: ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle_rounded),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _controller.reset,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Restablecer'),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          child,
        ],
      ),
    );
  }

  String _moduleTitle(ModuleId id) {
    switch (id) {
      case ModuleId.habits:
        return 'Hábitos';
      case ModuleId.psychology:
        return 'Psicología';
      case ModuleId.lab:
        return 'Laboratorio';
      case ModuleId.menstrual:
        return 'Ciclo menstrual';
    }
  }

  String _moduleSubtitle(ModuleId id) {
    switch (id) {
      case ModuleId.habits:
        return 'Checklist diario y rachas';
      case ModuleId.psychology:
        return 'Mentalidad, estrés y adherencia';
      case ModuleId.lab:
        return 'Probá hipótesis y medí resultados';
      case ModuleId.menstrual:
        return 'Seguimiento y predicciones';
    }
  }
}

class _BaseModuleTile extends StatelessWidget {
  const _BaseModuleTile({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: const Text('Incluido por defecto'),
      trailing: const Icon(Icons.lock_rounded, size: 18),
    );
  }
}
