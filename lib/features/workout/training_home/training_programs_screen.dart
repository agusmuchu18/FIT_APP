import '../widgets/workout_mini_bar_host_overlay.dart';
import '../../../app/theme/app_theme.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../data/training_library_repository.dart';
import '../data/workout_repository.dart';
import '../domain/training_program.dart';
import '../pro/models/workout_models.dart';
import 'routines_repository.dart';
import 'start_routine_flow.dart';
import 'training_home_controller.dart';
import 'routine_examples_screen.dart';
import '../domain/training_examples.dart';

const _weekdays = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

class TrainingProgramsScreen extends StatefulWidget {
  const TrainingProgramsScreen({
    super.key,
    this.library,
    this.repository,
    this.routinesRepository,
  });
  final TrainingLibraryRepository? library;
  final WorkoutRepository? repository;
  final RoutinesRepository? routinesRepository;
  @override
  State<TrainingProgramsScreen> createState() => _TrainingProgramsScreenState();
}

class _TrainingProgramsScreenState extends State<TrainingProgramsScreen> {
  late final _library = widget.library ?? TrainingLibraryRepository();
  late final _history = widget.repository ?? WorkoutRepository();
  late final _routines = widget.routinesRepository ?? RoutinesRepository();
  final _launcher = TrainingHomeController();
  List<TrainingProgram>? _programs;
  Map<String, WorkoutTemplate> _templates = {};
  Set<String> _completed = {};
  String? _error;
  var _generation = 0, _starting = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _launcher.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final programs = await _library.programs();
      final routines = await _routines.getAllRoutines();
      final index = await _history.performanceIndex();
      if (!mounted || generation != _generation) return;
      setState(() {
        _programs = programs;
        _templates = {for (final r in routines) r.id: r};
        _completed = {
          for (final r in index.reports)
            if (!DateUtils.dateOnly(r.session.date.toLocal())
                    .isAfter(DateUtils.dateOnly(DateTime.now())) &&
                r.exercises.any(
                  (e) => e.performed.any((s) => s.done == true),
                ) &&
                r.session.programExecution != null)
              r.session.programExecution!.occurrenceKey,
        };
        _error = null;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error =
              'No se pudo cargar la biblioteca. Tus datos se conservan.',
        );
      }
    }
  }

  Future<void> _edit([TrainingProgram? program]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ProgramEditor(
          program: program,
          library: _library,
          routines: _templates.values.toList(),
        ),
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _structure() async {
    if (_templates.isEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const RoutineExamplesScreen()),
      );
      if (mounted) await _load();
      return;
    }
    var days = 3;
    String routineId = _templates.keys.first;
    final choose = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Estructura de ejemplo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Cuatro semanas editables, con descansos explícitos. La rutina elegida se referencia sin modificarla.',
                ),
                DropdownButtonFormField<int>(
                  initialValue: days,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 3, child: Text('3 días alternos')),
                    DropdownMenuItem(
                      value: 4,
                      child: Text('4 días por semana'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) update(() => days = v);
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: routineId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Usar esta rutina',
                  ),
                  items: [
                    for (final r in _templates.values)
                      DropdownMenuItem(
                        value: r.id,
                        child: Text(
                          r.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) update(() => routineId = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Revisar estructura'),
            ),
          ],
        ),
      ),
    );
    if (choose != true || !mounted) return;
    try {
      await _edit(
        TrainingExamples.programStructure(
          _templates[routineId]!,
          daysPerWeek: days,
        ),
      );
    } on ArgumentError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message.toString())));
      }
    }
  }

  Future<void> _start(TrainingProgram p, ProgramDay d) async {
    if (_starting) return;
    final routine = _templates[d.routineId], occurrence = p.executionFor(d);
    if (routine == null || occurrence == null) return;
    setState(() => _starting = true);
    try {
      await _launcher.initialize();
      if (!mounted || !_history.isCurrentScope) return;
      await startRoutineFlow(
        context,
        _launcher,
        routine,
        programExecution: occurrence,
      );
      if (mounted) await _load();
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _delete(TrainingProgram program) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Eliminar programa'),
        content: Text(
          'Se eliminará «${program.name}». Las rutinas y sesiones guardadas se conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _library.deleteProgram(program.id);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar. Reintentá.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.workoutFor(Theme.of(context)),
    child: WorkoutMiniBarInset(child: Builder(builder: _buildContent)),
  );

  Widget _buildContent(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Programas'),
      actions: [
        IconButton(
          tooltip: 'Nuevo programa',
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: _error != null
        ? Center(
            child: TextButton(
              onPressed: _load,
              child: Text('$_error Reintentar'),
            ),
          )
        : _programs == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Una estructura para tus semanas',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Text(
                'Organizá tus rutinas existentes y descansos. La ejecución se confirma al guardar una sesión asociada; no se marcan objetivos como realizados.',
              ),
              TextButton.icon(
                onPressed: _structure,
                icon: const Icon(Icons.auto_awesome_mosaic_outlined),
                label: const Text('Explorar estructuras editables'),
              ),
              if (_library.unreadablePrograms > 0)
                Text(
                  '${_library.unreadablePrograms} programas no pudieron leerse y se conservaron sin cambios.',
                ),
              if (_programs!.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      const Icon(Icons.calendar_view_week_outlined, size: 48),
                      const SizedBox(height: 16),
                      const Text('Todavía no tenés programas.'),
                      FilledButton(
                        onPressed: () => _edit(),
                        child: const Text('Crear programa'),
                      ),
                    ],
                  ),
                ),
              for (final p in _programs!) _programCard(p),
            ],
          ),
  );
  Widget _programCard(TrainingProgram p) {
    final now = DateTime.now(), today = DateTime.now();
    final end = DateTime(now.year, now.month, now.day + 1);
    final scheduled = [
      for (final d in p.days)
        if (!d.rest && p.dateFor(d) != null && p.dateFor(d)!.isBefore(end))
          p.executionFor(d)!.occurrenceKey,
    ];
    final done = scheduled.where(_completed.contains).length;
    final upcoming =
        p.days
            .where(
              (d) =>
                  !d.rest &&
                  p.dateFor(d) != null &&
                  !_completed.contains(p.executionFor(d)!.occurrenceKey),
            )
            .toList()
          ..sort((a, b) => p.dateFor(a)!.compareTo(p.dateFor(b)!));
    return Card(
      child: ExpansionTile(
        title: Text(p.name),
        subtitle: Text(
          '${p.weeks} semanas · ${p.active ? 'Activo' : 'Borrador'}\n${scheduled.isEmpty ? 'Sin sesiones previstas hasta hoy' : '$done/${scheduled.length} sesiones previstas hasta hoy registradas'}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.description.isNotEmpty) Text(p.description),
                if (p.goal.isNotEmpty) Text('Objetivo: ${p.goal}'),
                if (p.level.isNotEmpty) Text('Nivel: ${p.level}'),
                if (p.equipment.isNotEmpty)
                  Text('Equipamiento: ${p.equipment.join(', ')}'),
                if (p.notes.isNotEmpty) Text('Notas: ${p.notes}'),
                if (p.active && upcoming.isNotEmpty)
                  Text(
                    'Siguiente pendiente: ${DateFormat.yMMMd('es').format(p.dateFor(upcoming.first)!)}${p.dateFor(upcoming.first)!.isBefore(DateTime(today.year, today.month, today.day)) ? ' · fecha anterior' : ''}',
                  ),
                Wrap(
                  spacing: 12,
                  children: [
                    TextButton.icon(
                      onPressed: () => _edit(p),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar'),
                    ),
                    TextButton.icon(
                      onPressed: () => _delete(p),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Eliminar'),
                    ),
                  ],
                ),
                for (var week = 0; week < p.weeks; week++)
                  ExpansionTile(
                    title: Text('Semana ${week + 1}'),
                    children: [
                      for (final d in p.days.where((d) => d.week == week))
                        ListTile(
                          title: Text(
                            '${_weekdays[d.weekday - 1]} · ${d.rest ? 'Descanso planificado' : _templates[d.routineId]?.name ?? 'Rutina eliminada o no disponible'}',
                          ),
                          subtitle: Text(
                            '${p.dateFor(d) == null ? 'Sin fecha de inicio' : DateFormat.yMd('es').format(p.dateFor(d)!)}${d.notes.isEmpty ? '' : '\n${d.notes}'}${!d.rest && p.executionFor(d) != null && _completed.contains(p.executionFor(d)!.occurrenceKey) ? '\nSesión guardada' : ''}',
                          ),
                          trailing: d.rest
                              ? const Icon(Icons.bedtime_outlined)
                              : IconButton(
                                  tooltip: 'Iniciar rutina programada',
                                  onPressed:
                                      p.active &&
                                          !_starting &&
                                          _templates.containsKey(d.routineId) &&
                                          p.executionFor(d) != null
                                      ? () => _start(p, d)
                                      : null,
                                  icon: const Icon(Icons.play_arrow_rounded),
                                ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramEditor extends StatefulWidget {
  const _ProgramEditor({
    this.program,
    required this.library,
    required this.routines,
  });
  final TrainingProgram? program;
  final TrainingLibraryRepository library;
  final List<WorkoutTemplate> routines;
  @override
  State<_ProgramEditor> createState() => _ProgramEditorState();
}

class _ProgramEditorState extends State<_ProgramEditor> {
  late TrainingProgram _program =
      widget.program ??
      TrainingProgram(
        id: const Uuid().v4(),
        name: '',
        weeks: 1,
        days: const [],
      );
  late final _name = TextEditingController(text: _program.name),
      _description = TextEditingController(text: _program.description),
      _goal = TextEditingController(text: _program.goal),
      _level = TextEditingController(text: _program.level),
      _notes = TextEditingController(text: _program.notes),
      _equipment = TextEditingController(text: _program.equipment.join(', '));
  late List<WorkoutTemplate> _routines = widget.routines;
  var _saving = false, _dirty = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_name, _description, _goal, _level, _notes, _equipment]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final program = _program.copyWith(
      name: _name.text.trim(),
      description: _description.text.trim(),
      goal: _goal.text.trim(),
      level: _level.text.trim(),
      notes: _notes.text,
      equipment: _equipment.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList(),
    );
    if (program.validationError case final error?) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.library.saveProgram(program);
      if (mounted) {
        setState(() => _dirty = false);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo guardar. Se conserva tu edición para reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addDay(int week, {ProgramDay? initial}) async {
    final day = await showModalBottomSheet<ProgramDay>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          _ProgramDayEditor(week: week, routines: _routines, initial: initial),
    );
    if (day != null && mounted) {
      setState(() {
        _dirty = true;
        _program = _program.copyWith(
          days: initial == null
              ? [..._program.days, day]
              : [for (final d in _program.days) d.id == initial.id ? day : d],
        );
      });
    }
  }

  Future<void> _createRoutine() async {
    await Navigator.of(context).pushNamed('/workout/routines/new');
    final routines = await RoutinesRepository().getAllRoutines();
    if (mounted) setState(() => _routines = routines);
  }

  Future<void> _removeWeek(int week) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Quitar semana ${week + 1}'),
        content: const Text(
          'Se quitarán sus actividades planificadas y las semanas siguientes se adelantarán. Las sesiones guardadas conservan su asociación histórica original.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Quitar semana'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        _dirty = true;
        _program = _program.removeWeek(week);
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || _saving) return;
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Cambios sin guardar'),
          content: const Text(
            'Podés volver al editor para guardar tu programa.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Seguir editando'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Descartar cambios'),
            ),
          ],
        ),
      );
      if (discard == true && mounted) {
        setState(() => _dirty = false);
        await WidgetsBinding.instance.endOfFrame;
        if (context.mounted) Navigator.of(context).pop();
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.program == null ? 'Nuevo programa' : 'Editar programa',
        ),
        actions: [
          IconButton(
            tooltip: 'Guardar programa',
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          for (final entry in <(String, TextEditingController)>[
            ('Nombre', _name),
            ('Descripción', _description),
            ('Objetivo', _goal),
            ('Nivel', _level),
            ('Equipamiento (separado por comas)', _equipment),
            ('Notas del programa', _notes),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: entry.$2,
                enabled: !_saving,
                decoration: InputDecoration(labelText: entry.$1),
                onChanged: (_) => setState(() => _dirty = true),
              ),
            ),
          SwitchListTile(
            title: const Text('Programa activo'),
            value: _program.active,
            onChanged: _saving
                ? null
                : (v) => setState(() {
                    _dirty = true;
                    _program = _program.copyWith(active: v);
                  }),
          ),
          ListTile(
            title: const Text('Lunes de la primera semana'),
            subtitle: Text(
              _program.startDate == null
                  ? 'Elegir inicio'
                  : DateFormat.yMMMd('es').format(_program.startDate!),
            ),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _saving
                ? null
                : () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _program.startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (date != null && mounted) {
                      setState(() {
                        _dirty = true;
                        _program = _program.copyWith(
                          startDate: DateTime(
                            date.year,
                            date.month,
                            date.day - date.weekday + 1,
                          ),
                        );
                      });
                    }
                  },
          ),
          const Text('La fecha elegida se alinea al lunes de esa semana.'),
          TextButton.icon(
            onPressed: _saving ? null : _createRoutine,
            icon: const Icon(Icons.add),
            label: const Text('Crear una rutina para el programa'),
          ),
          for (var week = 0; week < _program.weeks; week++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Semana ${week + 1}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final day in _program.days.where(
                      (d) => d.week == week,
                    ))
                      ListTile(
                        onTap: _saving
                            ? null
                            : () => _addDay(week, initial: day),
                        title: Text(
                          '${_weekdays[day.weekday - 1]} · ${day.rest ? 'Descanso' : _routines.where((r) => r.id == day.routineId).firstOrNull?.name ?? 'Rutina no disponible'}',
                        ),
                        subtitle: day.notes.isEmpty ? null : Text(day.notes),
                        trailing: PopupMenuButton<String>(
                          enabled: !_saving,
                          tooltip: 'Opciones del día',
                          onSelected: (value) => setState(() {
                            _dirty = true;
                            _program = value == 'remove'
                                ? _program.copyWith(
                                    days: _program.days
                                        .where((d) => d.id != day.id)
                                        .toList(),
                                  )
                                : _program.moveDay(
                                    day.id,
                                    value == 'up' ? -1 : 1,
                                  );
                          }),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'up',
                              child: Text('Mover arriba'),
                            ),
                            PopupMenuItem(
                              value: 'down',
                              child: Text('Mover abajo'),
                            ),
                            PopupMenuItem(
                              value: 'remove',
                              child: Text('Quitar día'),
                            ),
                          ],
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _saving ? null : () => _addDay(week),
                          child: const Text('Agregar día'),
                        ),
                        TextButton(
                          onPressed: _saving || _program.weeks >= 52
                              ? null
                              : () => setState(() {
                                  _dirty = true;
                                  _program = _program.duplicateWeek(week);
                                }),
                          child: const Text('Duplicar semana'),
                        ),
                        if (_program.weeks > 1)
                          TextButton(
                            onPressed: _saving ? null : () => _removeWeek(week),
                            child: const Text('Quitar semana'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          TextButton(
            onPressed: _saving || _program.weeks >= 52
                ? null
                : () => setState(() {
                    _dirty = true;
                    _program = _program.copyWith(weeks: _program.weeks + 1);
                  }),
            child: const Text('Agregar semana vacía'),
          ),
          const Text(
            'Los días sin actividad quedan sin planificar. Solo “Descanso” crea un descanso explícito.',
          ),
          const Text(
            'Mover arriba o abajo cambia el orden visual de las actividades de la semana; sus fechas se mantienen. Tocá un día para cambiar su día, rutina o notas.',
          ),
        ],
      ),
    ),
  );
}

class _ProgramDayEditor extends StatefulWidget {
  const _ProgramDayEditor({
    required this.week,
    required this.routines,
    this.initial,
  });
  final int week;
  final List<WorkoutTemplate> routines;
  final ProgramDay? initial;
  @override
  State<_ProgramDayEditor> createState() => _ProgramDayEditorState();
}

class _ProgramDayEditorState extends State<_ProgramDayEditor> {
  late int _weekday = widget.initial?.weekday ?? 1;
  late bool _rest = widget.initial?.rest ?? false;
  late String? _routine = widget.initial?.routineId;
  String? _error;
  late final _notes = TextEditingController(text: widget.initial?.notes ?? '');
  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      16,
      8,
      16,
      16 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Día · Semana ${widget.week + 1}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        DropdownButtonFormField<int>(
          initialValue: _weekday,
          decoration: const InputDecoration(labelText: 'Día de la semana'),
          items: [
            for (var i = 1; i <= 7; i++)
              DropdownMenuItem(value: i, child: Text(_weekdays[i - 1])),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _weekday = v);
          },
        ),
        SwitchListTile(
          title: const Text('Descanso planificado'),
          value: _rest,
          onChanged: (v) => setState(() => _rest = v),
        ),
        if (!_rest)
          DropdownButtonFormField<String>(
            initialValue: _routine,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Rutina existente'),
            items: [
              if (_routine != null &&
                  !widget.routines.any((r) => r.id == _routine))
                DropdownMenuItem(
                  value: _routine,
                  child: const Text('Rutina no disponible'),
                ),
              for (final r in widget.routines)
                DropdownMenuItem(value: r.id, child: Text(r.name)),
            ],
            onChanged: (v) => setState(() => _routine = v),
          ),
        TextField(
          controller: _notes,
          decoration: const InputDecoration(
            labelText: 'Notas del día (opcional)',
          ),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            if (!_rest && _routine == null) {
              setState(() => _error = 'Elegí una rutina o marcá descanso.');
              return;
            }
            Navigator.pop(
              context,
              ProgramDay(
                id: widget.initial?.id ?? const Uuid().v4(),
                week: widget.week,
                weekday: _weekday,
                routineId: _rest ? null : _routine,
                rest: _rest,
                notes: _notes.text,
              ),
            );
          },
          child: const Text('Agregar día'),
        ),
      ],
    ),
  );
}
