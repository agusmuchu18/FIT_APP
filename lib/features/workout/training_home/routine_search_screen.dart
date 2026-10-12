import 'package:flutter/material.dart';

import '../pro/models/workout_models.dart';
import 'routine_preview_screen.dart';
import 'routines_repository.dart';
import 'training_home_controller.dart';

String _foldSearch(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[áàäâ]'), 'a')
    .replaceAll(RegExp('[éèëê]'), 'e')
    .replaceAll(RegExp('[íìïî]'), 'i')
    .replaceAll(RegExp('[óòöô]'), 'o')
    .replaceAll(RegExp('[úùüû]'), 'u')
    .replaceAll('ñ', 'n');

List<WorkoutTemplate> searchWorkoutRoutines(
  List<WorkoutTemplate> routines,
  String query,
) {
  final terms = _foldSearch(query).trim().split(RegExp(r'\s+'));
  if (terms.length == 1 && terms.single.isEmpty) return routines;
  return routines
      .where((routine) {
        final haystack = _foldSearch(
          [
            routine.name,
            routine.activityName ?? '',
            ...routine.exercises.map((exercise) => exercise.name),
          ].join(' '),
        );
        return terms.every(haystack.contains);
      })
      .toList(growable: false);
}

class WorkoutRoutineSearchScreen extends StatefulWidget {
  const WorkoutRoutineSearchScreen({super.key});

  @override
  State<WorkoutRoutineSearchScreen> createState() =>
      _WorkoutRoutineSearchScreenState();
}

class _WorkoutRoutineSearchScreenState
    extends State<WorkoutRoutineSearchScreen> {
  final _queryController = TextEditingController();
  final _repository = RoutinesRepository();
  late Future<List<WorkoutTemplate>> _routinesFuture = _repository
      .getAllRoutines();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _openRoutine(WorkoutTemplate routine) async {
    final controller = TrainingHomeController();
    try {
      await controller.initialize();
      if (!mounted) return;
      final lastUsed = controller.metadataFor(routine.id).lastUsedAt;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RoutinePreviewScreen(
            routine: routine,
            controller: controller,
            typeLabel: switch (routine.type) {
              WorkoutType.strength => 'Fuerza',
              WorkoutType.cardio => 'Cardio',
              WorkoutType.functional => 'Funcional',
              WorkoutType.sport => 'Deporte',
              WorkoutType.custom => 'Personalizado',
            },
            lastUsedLabel: lastUsed == null ? 'Nunca' : 'Usada recientemente',
          ),
        ),
      );
      if (mounted) {
        setState(() => _routinesFuture = _repository.getAllRoutines());
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir la rutina. Reintentá.'),
          ),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar rutinas')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _queryController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre o ejercicio',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<WorkoutTemplate>>(
                future: _routinesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('No se pudieron cargar las rutinas.'),
                          TextButton(
                            onPressed: () => setState(
                              () => _routinesFuture = _repository
                                  .getAllRoutines(),
                            ),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    );
                  }
                  final routines = snapshot.data ?? const <WorkoutTemplate>[];
                  if (routines.isEmpty) {
                    return const Center(
                      child: Text('Todavía no hay rutinas para buscar.'),
                    );
                  }
                  final matches = searchWorkoutRoutines(
                    routines,
                    _queryController.text,
                  );
                  if (matches.isEmpty) {
                    return const Center(
                      child: Text('No encontramos rutinas con esa búsqueda.'),
                    );
                  }
                  return ListView.builder(
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final routine = matches[index];
                      return Card(
                        child: ListTile(
                          title: Text(routine.name),
                          subtitle: Text(
                            '${routine.exercises.length} ejercicios',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openRoutine(routine),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
