import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';

WorkoutSession workoutReportFixture({
  String id = 'saved',
  DateTime? date,
  double kg = 40,
}) => WorkoutSession(
  id: id,
  type: WorkoutType.strength,
  date: date ?? DateTime(2026, 10, 12, 18, 30),
  templateId: 'routine',
  templateName: 'Fuerza · Tren superior',
  durationSeconds: 1474,
  durationIsActive: true,
  notes: 'Movimiento controlado, sin molestias.',
  exercises: [
    WorkoutExercise(
      id: 'bench_press',
      name: 'Press de banca',
      targetLoadType: RoutineExerciseLoadType.weightedKg,
      notes: 'Pausa breve al bajar.',
      sets: [
        SetEntry(id: 'bench1', reps: 10, externalLoadKg: kg, done: true),
        SetEntry(id: 'bench2', reps: 8, externalLoadKg: kg, done: false),
      ],
    ),
    WorkoutExercise(
      id: 'lat_pulldown',
      name: 'Jalón al pecho',
      targetLoadType: RoutineExerciseLoadType.machineKg,
      sets: [SetEntry(id: 'lat1', reps: 12, externalLoadKg: kg, done: true)],
    ),
  ],
);

class WorkoutReportsRepository extends WorkoutRepository {
  WorkoutReportsRepository(this.sessions, {this.fail = false});
  final List<WorkoutSession> sessions;
  bool fail;
  int reads = 0;
  @override
  Future<List<WorkoutSession>> listAllSessions() async {
    reads++;
    if (fail) throw StateError('Storage unavailable');
    return sessions;
  }
}
