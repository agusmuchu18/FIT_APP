import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/routine_labels.dart';
import '../../domain/workout_analytics.dart';
import '../workout_history_detail_screen.dart';
import '../../domain/training_export.dart';
import '../../data/workout_repository.dart';
import 'workout_units_host.dart';
import '../training_export_screen.dart';

String trainingNumber(num value) => NumberFormat('0.##', 'es').format(value);

class TrainingRecordTile extends StatelessWidget {
  const TrainingRecordTile({super.key, required this.record, this.repository});
  final ExercisePersonalRecord record;
  final WorkoutRepository? repository;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      isThreeLine: true,
      leading: Icon(
        record.estimated ? Icons.functions : Icons.emoji_events_outlined,
      ),
      title: Text(
        '${RoutineLabels.exerciseName(record.exerciseName)} · ${record.kind.label}',
      ),
      subtitle: Text(
        '${WorkoutUnits.of(context).valueWithUnit(record.unit, record.value)}'
        '${record.reps == null ? '' : ' · ${record.reps} rep'}\n'
        '${record.loadLabel} · ${DateFormat.yMd('es').format(record.date.toLocal())}',
      ),
      trailing: IconButton(
        tooltip: 'Crear tarjeta de récord',
        icon: const Icon(Icons.ios_share_outlined),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TrainingExportScreen(
              data: TrainingExportData.record(
                record,
                units: WorkoutUnits.of(context),
              ),
            ),
          ),
        ),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WorkoutHistoryDetailScreen(
            sessionId: record.sessionId,
            repository: repository,
          ),
        ),
      ),
    ),
  );
}
