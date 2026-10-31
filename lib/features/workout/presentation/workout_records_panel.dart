import 'package:flutter/material.dart';

import '../data/workout_repository.dart';
import '../domain/workout_analytics.dart';
import 'widgets/training_record_tile.dart';

/// The Profile PR tab and training use the same canonical index.
class WorkoutRecordsPanel extends StatefulWidget {
  const WorkoutRecordsPanel({
    super.key,
    this.repository,
    this.primary = false,
    this.active = true,
  });
  final WorkoutRepository? repository;
  final bool primary;
  final bool active;
  @override
  State<WorkoutRecordsPanel> createState() => _WorkoutRecordsPanelState();
}

class _WorkoutRecordsPanelState extends State<WorkoutRecordsPanel>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late final _repository = widget.repository ?? WorkoutRepository();
  Future<TrainingPerformanceIndex>? _data;
  bool _needsRefresh = true;
  var _period = TrainingPeriod.all;
  RecordKind? _kind;
  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _data = _repository.performanceIndex();
      _needsRefresh = false;
    }
    _repository.historyRevision.addListener(_reload);
  }

  void _reload() {
    _needsRefresh = true;
    if (mounted && widget.active) {
      setState(() {
        _data = _repository.performanceIndex();
        _needsRefresh = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant WorkoutRecordsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      _reload();
    } else if (widget.active && _needsRefresh) {
      _reload();
    }
  }

  @override
  void dispose() {
    _repository.historyRevision.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<TrainingPerformanceIndex>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: _reload,
              child: const Text(
                'No se pudieron cargar los récords. Reintentar',
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final now = DateTime.now(), start = _period.start(DateTime.now());
        final end = DateTime(now.year, now.month, now.day + 1);
        // Filter the dates when these all-time records were attained. Do not
        // relabel a lesser recent performance as an all-time record.
        final records =
            snapshot.data!.records
                .where(
                  (r) =>
                      (_kind == null || r.kind == _kind) &&
                      r.date.isBefore(end) &&
                      (start == null || !r.date.isBefore(start)),
                )
                .toList()
              ..sort((a, b) => b.date.compareTo(a.date));
        return ListView.builder(
          primary: widget.primary,
          itemCount: records.length + 1,
          itemBuilder: (context, i) {
            if (i > 0) {
              return TrainingRecordTile(
                record: records[i - 1],
                repository: _repository,
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      DropdownButton<TrainingPeriod>(
                        isExpanded: true,
                        itemHeight: null,
                        value: _period,
                        items: [
                          for (final p in TrainingPeriod.values)
                            DropdownMenuItem(value: p, child: Text(p.label)),
                        ],
                        onChanged: (p) {
                          if (p != null) setState(() => _period = p);
                        },
                      ),
                      DropdownButton<RecordKind?>(
                        isExpanded: true,
                        itemHeight: null,
                        value: _kind,
                        items: [
                          const DropdownMenuItem<RecordKind?>(
                            value: null,
                            child: Text('Todos los récords'),
                          ),
                          for (final k in RecordKind.values)
                            DropdownMenuItem(value: k, child: Text(k.label)),
                        ],
                        onChanged: (k) => setState(() => _kind = k),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Récords personales vigentes, filtrados por fecha de obtención. Solo series con finalización confirmada. La 1RM es una estimación.',
                  ),
                ),
                if (records.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Todavía no hay récords verificables en este período. Completá y guardá una sesión para registrar tus marcas.',
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
