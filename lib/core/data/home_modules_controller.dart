import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ModuleId { habits, psychology, lab, menstrual }

class HomeModulesController extends ChangeNotifier {
  HomeModulesController._();

  static final HomeModulesController instance = HomeModulesController._();

  static const _enabledModulesKey = 'app.home.modules.enabled';
  static const _optionalOrderKey = 'app.home.modules.order';

  static const List<ModuleId> defaultOrder = [
    ModuleId.habits,
    ModuleId.psychology,
    ModuleId.lab,
    ModuleId.menstrual,
  ];

  bool _initialized = false;
  Set<ModuleId> _enabledModules = <ModuleId>{};
  List<ModuleId> _optionalOrder = List<ModuleId>.from(defaultOrder);

  bool get initialized => _initialized;
  Set<ModuleId> get enabledModules => Set<ModuleId>.unmodifiable(_enabledModules);
  List<ModuleId> get optionalOrder => List<ModuleId>.unmodifiable(_optionalOrder);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabledRaw = prefs.getStringList(_enabledModulesKey) ?? const <String>[];
    final orderRaw = prefs.getStringList(_optionalOrderKey) ?? defaultOrder.map((e) => e.name).toList();

    final enabled = enabledRaw
        .map(_moduleFromName)
        .whereType<ModuleId>()
        .toSet();

    final order = orderRaw
        .map(_moduleFromName)
        .whereType<ModuleId>()
        .toList();

    for (final module in defaultOrder) {
      if (!order.contains(module)) {
        order.add(module);
      }
    }

    _enabledModules = enabled;
    _optionalOrder = order;
    _initialized = true;
    notifyListeners();
  }

  Future<void> setEnabled(ModuleId id, bool enabled) async {
    if (enabled) {
      _enabledModules.add(id);
      if (!_optionalOrder.contains(id)) {
        _optionalOrder.add(id);
      }
    } else {
      _enabledModules.remove(id);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> removeFromHome(ModuleId id) => setEnabled(id, false);

  Future<void> reorderEnabledModules(int oldIndex, int newIndex) async {
    final active = _activeOrderedModules();
    if (active.length < 2) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final moved = active.removeAt(oldIndex);
    active.insert(newIndex, moved);

    final inactive = _optionalOrder.where((module) => !_enabledModules.contains(module)).toList();
    _optionalOrder = [...active, ...inactive];

    await _persist();
    notifyListeners();
  }

  Future<void> reset() async {
    _enabledModules = <ModuleId>{};
    _optionalOrder = List<ModuleId>.from(defaultOrder);
    await _persist();
    notifyListeners();
  }

  List<ModuleId> _activeOrderedModules() {
    return _optionalOrder.where(_enabledModules.contains).toList();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _enabledModulesKey,
      _enabledModules.map((e) => e.name).toList(),
    );
    await prefs.setStringList(
      _optionalOrderKey,
      _optionalOrder.map((e) => e.name).toList(),
    );
  }

  ModuleId? _moduleFromName(String raw) {
    for (final module in ModuleId.values) {
      if (module.name == raw) return module;
    }
    return null;
  }
}
