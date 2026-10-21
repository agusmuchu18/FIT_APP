import 'package:flutter/material.dart';

import '../../../../core/data/account_storage_scope.dart';
import '../../data/workout_preferences.dart';
import '../../domain/training_units.dart';

class WorkoutUnits extends InheritedWidget {
  const WorkoutUnits({
    super.key,
    required this.preferences,
    required super.child,
  });
  final WorkoutPreferences preferences;
  static WorkoutPreferences preferencesOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WorkoutUnits>()?.preferences ??
      const WorkoutPreferences();
  static TrainingUnits of(BuildContext context) => preferencesOf(context).units;
  @override
  bool updateShouldNotify(covariant WorkoutUnits oldWidget) =>
      oldWidget.preferences != preferences;
}

/// Captures account ownership once. Storage remains canonical kg/meters; only
/// presentation and explicit user entry conversions depend on this scope.
class WorkoutUnitsHost extends StatefulWidget {
  const WorkoutUnitsHost({super.key, required this.child});
  final Widget child;
  @override
  State<WorkoutUnitsHost> createState() => _WorkoutUnitsHostState();
}

class _WorkoutUnitsHostState extends State<WorkoutUnitsHost> {
  final _scope = AccountStorageScope.current;
  var _ready = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await WorkoutPreferences.load(scope: _scope);
    } catch (_) {
      WorkoutPreferences.watch(_scope).value = const WorkoutPreferences();
    } finally {
      if (mounted) setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) => !_ready
      ? const Center(child: CircularProgressIndicator())
      : ValueListenableBuilder<WorkoutPreferences>(
          valueListenable: WorkoutPreferences.watch(_scope),
          builder: (context, preferences, _) =>
              WorkoutUnits(preferences: preferences, child: widget.child),
        );
}
