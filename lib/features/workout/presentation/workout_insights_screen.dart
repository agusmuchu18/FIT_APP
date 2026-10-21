import '../../../app/theme/app_theme.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../data/workout_repository.dart';
import '../data/training_library_repository.dart';
import '../domain/training_program.dart';
import '../domain/routine_labels.dart';
import '../domain/workout_analytics.dart';
import '../pro/models/workout_models.dart';
import '../training_home/exercise_technical_screen.dart';
import 'widgets/training_muscle_diagram.dart';
import 'widgets/training_record_tile.dart';
import 'widgets/workout_report_widgets.dart';
import 'workout_history_detail_screen.dart';
import '../domain/training_export.dart';
import 'training_export_screen.dart';
import 'widgets/workout_units_host.dart';

class WorkoutInsightsScreen extends StatefulWidget {
  const WorkoutInsightsScreen({
    super.key,
    this.repository,
    this.now,
    this.library,
  });
  final WorkoutRepository? repository;
  final TrainingLibraryRepository? library;
  final DateTime? now;
  @override
  State<WorkoutInsightsScreen> createState() => _WorkoutInsightsScreenState();
}

class _WorkoutInsightsScreenState extends State<WorkoutInsightsScreen> {
  late final _repository = widget.repository ?? WorkoutRepository();
  late final _library = widget.library ?? TrainingLibraryRepository();
  List<TrainingProgram> _programs = [];
  String? _planError;
  late final _now = widget.now ?? DateTime.now();
  TrainingPerformanceIndex? _source;
  TrainingStatistics? _stats, _previous, _monthly, _previousMonth, _calendar;
  TrainingPeriod _period = TrainingPeriod.month;
  ExerciseRanking _ranking = ExerciseRanking.sessions;
  WorkoutType? _type;
  late DateTime _month = DateTime(_now.year, _now.month),
      _focused = _now,
      _day = DateTime(_now.year, _now.month, _now.day);
  String? _error;
  var _generation = 0;
  var _planGeneration = 0;
  @override
  void initState() {
    super.initState();
    _repository.historyRevision.addListener(_load);
    _library.revision.addListener(_loadPlans);
    _loadPlans();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _planGeneration++;
    _repository.historyRevision.removeListener(_load);
    _library.revision.removeListener(_loadPlans);
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final data = await _repository.performanceIndex();
      if (!mounted || generation != _generation) return;
      setState(() {
        _source = data;
        _error = null;
        _aggregate();
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = 'No se pudieron cargar tus estadísticas. Tus registros se conservan.',
        );
      }
    }
  }

  Future<void> _loadPlans() async {
    final generation = ++_planGeneration;
    try {
      final programs = await _library.programs();
      if (!mounted || generation != _planGeneration) return;
      setState(() {
        _programs = programs
            .where((p) => p.active && p.startDate != null)
            .toList();
        _planError = _library.unreadablePrograms > 0
            ? 'Hay programas de una versión no compatible. Sus originales se conservan.'
            : null;
      });
    } catch (_) {
      if (mounted && generation == _planGeneration) {
        setState(
          () => _planError = 'No se pudo leer la planificación. El historial sigue disponible.',
        );
      }
    }
  }

  List<(TrainingProgram, ProgramDay)> _plansFor(DateTime date) => [
    for (final p in _programs)
      for (final day in p.days)
        if (isSameDay(p.dateFor(day), date)) (p, day),
  ];

  void _aggregate() {
    final source = _source;
    if (source == null) return;
    final index = _type == null
        ? source
        : TrainingPerformanceIndex(
            source.reports
                .where((r) => r.session.type == _type)
                .map((r) => r.session),
          );
    final range = TrainingDateRange.forPeriod(
      _period,
      _now,
      oldest: index.reports.firstOrNull?.session.date,
    );
    _stats = TrainingStatistics(index: index, range: range, now: _now);
    _previous = TrainingStatistics(
      index: index,
      range: range.previous,
      now: _now,
    );
    _monthly = TrainingStatistics(
      index: index,
      range: TrainingDateRange.month(_month.year, _month.month),
      now: _now,
    );
    _previousMonth = TrainingStatistics(
      index: index,
      range: TrainingDateRange.month(_month.year, _month.month - 1),
      now: _now,
    );
    _calendar = TrainingStatistics(
      index: index,
      range: TrainingDateRange.forPeriod(
        TrainingPeriod.all,
        _now,
        oldest: index.reports.firstOrNull?.session.date,
      ),
      now: _now,
    );
  }

  void _open(WorkoutReport report) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => WorkoutHistoryDetailScreen(
        sessionId: report.session.id,
        repository: _repository,
      ),
    ),
  );
  static const _types = {
    WorkoutType.strength: 'Fuerza',
    WorkoutType.cardio: 'Cardio',
    WorkoutType.functional: 'Funcional',
    WorkoutType.sport: 'Deporte',
    WorkoutType.custom: 'Personalizado',
  };
  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.workoutFor(Theme.of(context)),
    child: Builder(builder: _buildContent),
  );

  Widget _buildContent(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Tu entrenamiento'),
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Análisis'),
            Tab(text: 'Músculos'),
            Tab(text: 'Calendario'),
            Tab(text: 'Informes'),
          ],
        ),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : _stats == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Wrap(
                    spacing: 16,
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
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _period = v;
                              _aggregate();
                            });
                          }
                        },
                      ),
                      DropdownButton<WorkoutType?>(
                        isExpanded: true,
                        itemHeight: null,
                        value: _type,
                        items: [
                          const DropdownMenuItem<WorkoutType?>(
                            value: null,
                            child: Text('Todas las modalidades'),
                          ),
                          for (final t in _types.entries)
                            DropdownMenuItem(
                              value: t.key,
                              child: Text(t.value),
                            ),
                        ],
                        onChanged: (v) => setState(() {
                          _type = v;
                          _aggregate();
                        }),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _analysis(),
                      _muscles(),
                      _calendarView(),
                      _report(),
                    ],
                  ),
                ),
              ],
            ),
    ),
  );

  Widget _numbers(TrainingStatistics stats) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      WorkoutMetricGrid(
        metrics: [
          ('Sesiones', '${stats.sessions.length}'),
          ('Series registradas', '${stats.sets}'),
          (
            'Volumen externo',
            (WorkoutUnits.of(context).valueWithUnit('kg·rep', stats.volume)),
          ),
          ('Frecuencia', '${trainingNumber(stats.weeklyFrequency)} / semana'),
          (
            'Tiempo registrado',
            '${trainingNumber(stats.durationSeconds / 60)} min',
          ),
        ],
      ),
      Text(
        'Tiempo disponible en ${stats.knownDurations} de ${stats.sessions.length} sesiones. ${stats.durationKinds.length > 1
            ? 'Se mezclan duraciones con criterios diferentes; no se calcula un promedio.'
            : stats.durationKinds.singleOrNull == true
            ? 'Tiempo activo, incluidos descansos; excluye pausas.'
            : 'Tiempo total o criterio histórico no especificado.'}',
      ),
      if (stats.ambiguousVolumes > 0)
        Text(
          '${stats.ambiguousVolumes} sesiones con cargas ambiguas: el volumen mostrado es parcial.',
        ),
      if (stats.unknownCompletion)
        const Text(
          'Algunos registros antiguos no confirman la finalización de sus series. No certifican récords ni series musculares directas.',
        ),
    ],
  );
  Widget _analysis() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _numbers(_stats!),
      if (_stats!.sessions.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Todavía no hay sesiones guardadas en este período.'),
        ),
      const SizedBox(height: 24),
      Text(
        'Respecto del período anterior',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Text(
        '${DateFormat.yMd('es').format(_previous!.range.start)} – ${DateFormat.yMd('es').format(_previous!.range.end.subtract(const Duration(days: 1)))}',
      ),
      _change('Sesiones', _stats!.sessions.length, _previous!.sessions.length),
      _change('Series', _stats!.sets, _previous!.sets),
      _change('Volumen externo', _stats!.volume, _previous!.volume),
      const SizedBox(height: 24),
      Text('Actividad diaria', style: Theme.of(context).textTheme.titleMedium),
      _trend(_stats!),
      const SizedBox(height: 24),
      DropdownButtonFormField<ExerciseRanking>(
        initialValue: _ranking,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Ejercicios ordenados por',
        ),
        items: [
          for (final v in ExerciseRanking.values)
            DropdownMenuItem(value: v, child: Text(v.label)),
        ],
        onChanged: (v) {
          if (v != null) setState(() => _ranking = v);
        },
      ),
      for (final e in _stats!.rank(_ranking).take(30))
        ListTile(
          title: Text(RoutineLabels.exerciseName(e.name)),
          subtitle: Text(
            '${trainingNumber(_ranking == ExerciseRanking.volume ? WorkoutUnits.of(context).weight.fromKg(e.value(_ranking)) : e.value(_ranking))} ${switch (_ranking) {
              ExerciseRanking.sessions => 'sesiones',
              ExerciseRanking.sets => 'series',
              ExerciseRanking.volume => '${WorkoutUnits.of(context).weight.label}·rep',
              ExerciseRanking.time => 's',
            }}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _exercise(e.id),
        ),
      const Text(
        'Tiempo por ejercicio: solo segundos registrados en sus series. No se reparte la duración total entre ejercicios.',
      ),
    ],
  );
  Widget _change(String label, num current, num previous) {
    final percent = TrainingStatistics.percentChange(current, previous);
    return Text(
      '$label: ${trainingNumber(previous)} → ${trainingNumber(current)} · ${percent == null ? 'Sin base anterior para porcentaje' : '${percent >= 0 ? '+' : ''}${trainingNumber(percent)} %'}',
    );
  }

  Widget _trend(TrainingStatistics stats) {
    final days = stats.sessionsByDay.keys.toList()..sort();
    if (days.isEmpty) {
      return const Text('Sin actividad registrada para graficar.');
    }
    // One point per active day; no missing day is called a planned rest day.
    final plotted = days.length <= 90
        ? days
        : [
            for (var i = 0; i < 90; i++)
              days[(i * (days.length - 1) / 89).round()],
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 190,
          child: BarChart(
            BarChartData(
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: [
                for (var i = 0; i < plotted.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: stats.sessionsByDay[plotted[i]]!.length.toDouble(),
                        color: Theme.of(context).colorScheme.primary,
                        width: 10,
                      ),
                    ],
                  ),
              ],
              barTouchData: BarTouchData(
                touchCallback: (event, response) {
                  final index = response?.spot?.touchedBarGroupIndex;
                  if (event is FlTapUpEvent && index != null) {
                    _daySessions(
                      plotted[index],
                      stats.sessionsByDay[plotted[index]]!,
                    );
                  }
                },
              ),
            ),
            duration: Duration.zero,
          ),
        ),
        const Text(
          'Sesiones por día registrado, en orden cronológico. Tocá una barra para abrir sus sesiones.',
        ),
        if (days.length > 90)
          const Text(
            'Gráfico reducido a 90 días activos. Todos los días siguen en la tabla y el calendario.',
          ),
        ExpansionTile(
          title: const Text('Tabla diaria exacta'),
          children: [
            for (final day in days.reversed.take(60))
              ListTile(
                title: Text(DateFormat.yMMMd('es').format(day)),
                subtitle: Text('${stats.sessionsByDay[day]!.length} sesiones'),
                onTap: () => _daySessions(day, stats.sessionsByDay[day]!),
              ),
            if (days.length > 60)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Consultá las fechas anteriores desde el calendario.',
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _muscles() {
    final distribution = WorkoutAnalytics.muscleDistribution([
      for (final r in _stats!.sessions)
        for (final e in r.session.exercises)
          e.copyWith(sets: e.sets.where((s) => s.done == true).toList()),
    ]);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        WorkoutMuscleReport.distribution(valuesByMuscle: distribution),
        const SizedBox(height: 24),
        TrainingMuscleDiagram(
          muscles: _stats!.muscleSummary,
          onSelected: _muscleDetail,
        ),
        const Text(
          'Una serie con varios grupos principales puede aparecer en más de un grupo. Las series secundarias se cuentan aparte.',
        ),
        for (final m in _stats!.muscleSummary.values)
          ListTile(
            title: Text(m.region.label),
            subtitle: Text(
              '${m.directSets} series directas · ${m.secondarySets} secundarias\n${m.sessions.length} sesiones · ${trainingNumber(m.weeklyFrequency(_stats!.observedDays))}/semana',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _muscleDetail(m.region),
          ),
      ],
    );
  }

  void _exercise(String id) {
    final observations = _source?.history[id];
    if (observations?.isNotEmpty != true) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExerciseTechnicalScreen(
          exercise: observations!.first.exercise,
          repository: _repository,
        ),
      ),
    );
  }

  void _muscleDetail(TrainingMuscle region) {
    final current = _stats!.muscleSummary[region]!,
        previous = _previous!.muscleSummary[region]!;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .65,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              region.label,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            _change('Series directas', current.directSets, previous.directSets),
            _change(
              'Series secundarias',
              current.secondarySets,
              previous.secondarySets,
            ),
            const Text(
              'La participación secundaria se muestra aparte; no se suma como serie directa equivalente.',
            ),
            for (final id in current.exerciseIds)
              ListTile(
                title: Text(
                  RoutineLabels.exerciseName(
                    _source!.history[id]?.first.exercise.name ?? id,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(sheet).pop();
                  _exercise(id);
                },
              ),
            Text(
              'Distribución por días',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final day in (current.days.toList()..sort()))
              ListTile(
                title: Text(DateFormat.yMMMd('es').format(day)),
                onTap: () {
                  Navigator.of(sheet).pop();
                  _daySessions(day, _stats!.sessionsByDay[day] ?? []);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _calendarView() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'El historial respeta la modalidad elegida. La planificación muestra todos los programas activos. Un día sin registro no significa descanso.',
      ),
      if (_planError != null)
        TextButton(
          onPressed: _loadPlans,
          child: Text('$_planError Reintentar'),
        ),
      const Wrap(
        spacing: 16,
        children: [
          Text('● Sesión registrada'),
          Text('◷ Sesión prevista'),
          Text('☾ Descanso planificado'),
        ],
      ),
      TableCalendar<Object>(
        locale: 'es',
        firstDay: DateTime(
          [
            ..._programs.map((p) => p.startDate!.year),
            _calendar!.sessions.firstOrNull?.session.date.toLocal().year ??
                _now.year,
          ].reduce((a, b) => a < b ? a : b),
        ),
        lastDay: DateTime(_now.year + 2, 12, 31),
        focusedDay: _focused,
        startingDayOfWeek: StartingDayOfWeek.monday,
        availableCalendarFormats: const {CalendarFormat.month: 'Mes'},
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
        ),
        selectedDayPredicate: (d) => isSameDay(d, _day),
        eventLoader: (d) => [
          ...?_calendar!.sessionsByDay[DateTime(d.year, d.month, d.day)],
          ..._plansFor(d),
        ],
        calendarBuilders: CalendarBuilders<Object>(
          markerBuilder: (context, date, events) {
            final actual =
                _calendar!
                    .sessionsByDay[DateTime(date.year, date.month, date.day)]
                    ?.isNotEmpty ==
                true;
            final plans = _plansFor(date);
            if (!actual && plans.isEmpty) return null;
            final label = [
              if (actual) 'Sesión registrada',
              if (plans.any((p) => !p.$2.rest)) 'Sesión prevista',
              if (plans.any((p) => p.$2.rest)) 'Descanso planificado',
            ].join(', ');
            return Positioned(
              bottom: 1,
              child: Semantics(
                label: label,
                child: Text(
                  [
                    if (actual) '●',
                    if (plans.any((p) => !p.$2.rest)) '◷',
                    if (plans.any((p) => p.$2.rest)) '☾',
                  ].join(' '),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          },
        ),
        onDaySelected: (d, f) => setState(() {
          _day = DateTime(d.year, d.month, d.day);
          _focused = f;
        }),
        onPageChanged: (d) => _focused = d,
      ),
      const SizedBox(height: 16),
      Text(
        DateFormat.yMMMMd('es').format(_day),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if ((_calendar!.sessionsByDay[_day] ?? []).isEmpty)
        const Text('Sin sesiones registradas.'),
      for (final planned in _plansFor(_day))
        ListTile(
          leading: Icon(
            planned.$2.rest ? Icons.bedtime_outlined : Icons.event_outlined,
          ),
          title: Text(
            planned.$2.rest ? 'Descanso planificado' : 'Sesión prevista',
          ),
          subtitle: Text(
            '${planned.$1.name} · Semana ${planned.$2.week + 1}${planned.$2.notes.isEmpty ? '' : '\n${planned.$2.notes}'}',
          ),
        ),
      for (final report in _calendar!.sessionsByDay[_day] ?? <WorkoutReport>[])
        ListTile(
          title: Text(report.name),
          subtitle: Text(
            '${_types[report.session.type]} · ${report.performedSets} series',
          ),
          onTap: () => _open(report),
        ),
    ],
  );
  void _daySessions(
    DateTime day,
    List<WorkoutReport> reports,
  ) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheet) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          DateFormat.yMMMMd('es').format(day),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        for (final r in reports)
          ListTile(
            title: Text(r.name),
            subtitle: Text(
              '${r.performedSets} series · ${WorkoutUnits.of(context).valueWithUnit('kg·rep', r.externalVolume)}',
            ),
            onTap: () {
              Navigator.of(sheet).pop();
              _open(r);
            },
          ),
      ],
    ),
  );
  Widget _report() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TrainingExportScreen(
                data: TrainingExportData.month(
                  _monthly!,
                  units: WorkoutUnits.of(context),
                ),
              ),
            ),
          ),
          icon: const Icon(Icons.ios_share_outlined),
          label: const Text('Crear tarjeta del mes'),
        ),
      ),
      Row(
        children: [
          IconButton(
            tooltip: 'Mes anterior',
            onPressed: () => setState(() {
              _month = DateTime(_month.year, _month.month - 1);
              _aggregate();
            }),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              DateFormat.yMMMM('es').format(_month),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: 'Mes siguiente',
            onPressed: _month.isBefore(DateTime(_now.year, _now.month))
                ? () => setState(() {
                    _month = DateTime(_month.year, _month.month + 1);
                    _aggregate();
                  })
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      const Text(
        'Informe por mes calendario. Este selector es independiente del período móvil superior.',
      ),
      if (_month.year == _now.year && _month.month == _now.month)
        const Text(
          'Mes actual parcial, comparado con el mes anterior completo.',
        ),
      _numbers(_monthly!),
      const SizedBox(height: 24),
      Text(
        'Comparación con ${DateFormat.yMMMM('es').format(_previousMonth!.range.start)}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      _change(
        'Sesiones',
        _monthly!.sessions.length,
        _previousMonth!.sessions.length,
      ),
      _change('Series', _monthly!.sets, _previousMonth!.sets),
      _change('Volumen externo', _monthly!.volume, _previousMonth!.volume),
      const SizedBox(height: 24),
      _trend(_monthly!),
    ],
  );
}
