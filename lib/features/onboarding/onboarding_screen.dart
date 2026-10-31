import 'package:flutter/material.dart';

import '../../core/domain/entities.dart';
import '../../main.dart';
import '../common/theme/app_colors.dart';
import '../common/widgets/app_choice_chip.dart';
import '../common/widgets/primary_button.dart';
import '../common/widgets/summary_card.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<String> _contextOptions = const [
    'Quiero mejorar mis hábitos generales',
    'Entreno de forma regular',
    'Estoy siguiendo un plan estructurado',
    'Soy atleta / entreno con objetivos competitivos',
    'Trabajo o entreno a otras personas',
  ];
  final List<String> _focusOptions = const [
    'Rendimiento físico',
    'Salud general',
    'Composición corporal',
    'Recuperación / descanso',
    'Nutrición',
    'Seguimiento profesional (coach / equipo)',
  ];
  final List<String> _improvementOptions = const [
    'Fuerza',
    'Resistencia',
    'Velocidad',
    'Técnica',
    'Peso corporal',
    'Masa muscular',
    'Energía diaria',
    'Sueño',
    'Alimentación',
  ];
  final List<String> _timeGoalOptions = const [
    'No',
    'En X semanas / meses',
    'Fecha específica (calendario)',
  ];
  final List<String> _trainingLogOptions = const ['Completo'];
  final List<String> _trainingSupervisionOptions = const [
    'Solo',
    'Con entrenador',
    'Entrenador + equipo',
  ];
  final List<String> _nutritionLogOptions = const ['Completo'];
  final List<String> _dietStructureOptions = const [
    'No',
    'Sí, creada por mí',
    'Sí, de un profesional',
    'Quiero importar una dieta existente',
  ];
  final List<String> _sleepTrackingOptions = const [
    'Manual básico (horas + calidad)',
    'Manual detallado (latencia, despertares, sensación)',
    'Automático (dispositivo)',
  ];
  final List<String> _dailyTimeOptions = const [
    '< 1 minuto',
    '1–3 minutos',
    '5+ minutos',
  ];
  final List<String> _trainingFrequencyOptions = const [
    '1–2 veces por semana',
    '3–4 veces por semana',
    '5+ veces por semana',
    'Variable',
  ];
  final List<String> _bodyTrackingOptions = const [
    'Peso corporal',
    'Medidas corporales',
    '% grasa (si disponible)',
  ];
  final List<String> _professionalUseOptions = const [
    'Solo para mí',
    'Soy entrenador / preparador',
    'Trabajo con un equipo',
  ];
  final List<String> _visibilityOptions = const [
    'Entrenamiento',
    'Alimentación',
    'Sueño',
    'Resúmenes semanales',
    'Alertas de incumplimiento',
  ];
  final List<String> _deviceOptions = const [
    'Apple Watch',
    'Fitbit',
    'Garmin',
    'Otro',
    'Ninguno por ahora',
  ];
  final List<String> _dataMergeOptions = const [
    'Sí, automáticamente',
    'No, solo como referencia',
    'Preguntar cada vez',
  ];

  String _contextStatus = 'Quiero mejorar mis hábitos generales';
  String _timeGoal = 'No';
  String _trainingLog = 'Completo';
  String _trainingSupervision = 'Solo';
  String _nutritionLog = 'Completo';
  String _dietStructure = 'No';
  String _sleepTracking = 'Manual básico (horas + calidad)';
  String _dailyTime = '< 1 minuto';
  String _trainingFrequency = '3–4 veces por semana';
  String _professionalUse = 'Solo para mí';
  String _dataMerge = 'Sí, automáticamente';
  final Set<String> _focusAreas = {'Rendimiento físico'};
  final Set<String> _improvements = {'Fuerza'};
  final Set<String> _bodyTracking = {'Peso corporal'};
  final Set<String> _visibility = {'Entrenamiento'};
  final Set<String> _devices = {};
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _sexController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  bool _isSaving = false;
  UserPreferences? _existing;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    _ageController.dispose();
    _sexController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _prefill() async {
    final repository = RepositoryScope.of(context);
    final existing = await repository.getPreferences();
    if (!mounted) return;

    setState(() {
      _existing = existing;
      if (existing == null) return;
      _contextStatus = existing.experienceLevel.isNotEmpty
          ? existing.experienceLevel
          : _contextStatus;
      if (existing.primaryGoal.isNotEmpty) {
        _focusAreas
          ..clear()
          ..addAll(existing.primaryGoal.split(' + '));
      }
      _trainingFrequency = _mapSessionsToFrequency(
        existing.targetSessionsPerWeek,
      );
      _trainingLog = existing.modePreference.isNotEmpty
          ? existing.modePreference
          : _trainingLog;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showProfessionalDetails = _professionalUse != 'Solo para mí';
    final showDataMergeQuestion =
        _devices.isNotEmpty && !_devices.contains('Ninguno por ahora');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Conozcámonos',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (_existing != null)
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pushReplacementNamed('/home'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
              ),
              child: const Text('Ir a inicio'),
            ),
        ],
      ),
      body: SafeArea(
        child: Container(
          color: AppColors.background,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(hasData: _existing != null),
                  const SizedBox(height: 16),
                  const _SectionTitle(title: 'Principios del onboarding'),
                  const SizedBox(height: 10),
                  const _PrinciplesCard(),
                  const SizedBox(height: 20),
                  const _SectionTitle(
                    title: '1️⃣ Contexto general del usuario',
                  ),
                  const SizedBox(height: 10),
                  _QuestionCard(
                    title: '¿Cómo describirías tu situación actual?',
                    description:
                        'Ajusta el lenguaje y los dashboards por defecto.',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _contextOptions
                          .map(
                            (item) => AppChoiceChip(
                              label: item,
                              selected: _contextStatus == item,
                              onSelected: (_) =>
                                  setState(() => _contextStatus = item),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _QuestionCard(
                    title: '¿Cuál es tu principal foco hoy?',
                    description:
                        'Podés elegir hasta 2 para ordenar el dashboard inicial.',
                    child: _MultiSelectWrap(
                      options: _focusOptions,
                      selected: _focusAreas,
                      maxSelection: 2,
                      onChanged: (item) => setState(
                        () => _toggleSelection(_focusAreas, item, 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _SectionTitle(title: '2️⃣ Objetivos'),
                  const SizedBox(height: 10),
                  _QuestionCard(
                    title: '¿Qué querés mejorar principalmente?',
                    description:
                        'Define KPIs principales y gráficos iniciales.',
                    child: _MultiSelectWrap(
                      options: _improvementOptions,
                      selected: _improvements,
                      onChanged: (item) =>
                          setState(() => _toggleSelection(_improvements, item)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _QuestionCard(
                    title: '¿Tenés un objetivo temporal?',
                    description: 'Activa comparativas y proyecciones simples.',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _timeGoalOptions
                          .map(
                            (item) => AppChoiceChip(
                              label: item,
                              selected: _timeGoal == item,
                              onSelected: (_) =>
                                  setState(() => _timeGoal = item),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _SectionTitle(title: '3️⃣ Nivel de detalle por módulo'),
                  const SizedBox(height: 10),
                  _QuestionCard(
                    title: '🏋️ ¿Cómo querés registrar tu entrenamiento?',
                    description:
                        'Usamos un registro completo con detalle por ejercicio.',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _trainingLogOptions
                          .map(
                            (item) => AppChoiceChip(
                              label: item,
                              selected: _trainingLog == item,
                              onSelected: (_) =>
                                  setState(() => _trainingLog = item),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _QuestionCard(
                    title: '¿Entrenás solo o con alguien que te supervisa?',
                    description:
                        'Habilita vistas compartidas y roles según corresponda.',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _trainingSupervisionOptions
                          .map(
                            (item) => AppChoiceChip(
                              label: item,
                              selected: _trainingSupervision == item,
                              onSelected: (_) =>
                                  setState(() => _trainingSupervision = item),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _QuestionCard(
                    title: '🍽️ ¿Cómo querés registrar tu alimentación?',
                    description:
                        'Usamos un registro nutricional completo con macros.',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _nutritionLogOptions
                          .map(
                            (item) => AppChoiceChip(
                              label: item,
                              selected: _nutritionLog == item,
                              onSelected: (_) =>
                                  setState(() => _nutritionLog = item),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _QuestionCard(
                    title: '¿Seguís actualmente una dieta estructurada?',
                    description:
                        'Sugiere importación o crea una estructura base.',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _dietStructureOptions
                          .map(
                            (item) => AppChoiceChip(
                              label: item,
                              selected: _dietStructure == item,
                              onSelected: (_) =>
                                  setState(() => _dietStructure = item),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _QuestionCard(
                    title: '😴 ¿Cómo querés registrar tu sueño?',
                    description:
                        'Ajusta el cuestionario nocturno y las fuentes de datos.',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _sleepTrackingOptions
                          .map(
                            (item) => AppChoiceChip(
                              label: item,
                              selected: _sleepTracking == item,
                              onSelected: (_) =>
                                  setState(() => _sleepTracking = item),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _SectionTitle(
                    title: '4️⃣ Disponibilidad y realidad del usuario',
                  ),
                  const SizedBox(height: 10),
                  _QuestionCard(
                    title:
                        '¿Cuánto tiempo real podés dedicar por día al registro?',
                    description:
                        'Define el modo por defecto y ajusta la fricción del registro.',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _dailyTimeOptions
                          .map(
                            (item) => AppChoiceChip(
                              label: item,
                              selected: _dailyTime == item,
                              onSelected: (_) =>
                                  setState(() => _dailyTime = item),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _QuestionCard(
                    title: '¿Con qué frecuencia entrenás actualmente?',
                    description:
                        'Ajusta escalas de gráficos y evita comparaciones irreales.',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _trainingFrequencyOptions
                          .map(
                            (item) => AppChoiceChip(
                              label: item,
                              selected: _trainingFrequency == item,
                              onSelected: (_) =>
                                  setState(() => _trainingFrequency = item),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _SectionTitle(title: '5️⃣ Datos físicos'),
                  const SizedBox(height: 10),
                  _QuestionCard(
                    title: 'Datos básicos (opcionales pero recomendados)',
                    description:
                        'Usamos esta información para métricas normalizadas.',
                    child: Column(
                      children: [
                        _InputRow(
                          label: 'Edad',
                          controller: _ageController,
                          hint: 'Ej: 29',
                        ),
                        _InputRow(
                          label: 'Sexo',
                          controller: _sexController,
                          hint: 'Ej: Mujer / Hombre',
                        ),
                        _InputRow(
                          label: 'Altura',
                          controller: _heightController,
                          hint: 'Ej: 170 cm',
                        ),
                        _InputRow(
                          label: 'Peso actual',
                          controller: _weightController,
                          hint: 'Ej: 68 kg',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _QuestionCard(
                    title:
                        '¿Querés registrar estos datos a lo largo del tiempo?',
                    description:
                        'Activa gráficos de composición corporal y tendencias.',
                    child: _MultiSelectWrap(
                      options: _bodyTrackingOptions,
                      selected: _bodyTracking,
                      onChanged: (item) => setState(
                        () => _toggleSelection(_bodyTracking, item, null, true),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _SectionTitle(title: '6️⃣ Uso profesional / grupos'),
                  const SizedBox(height: 10),
                  _QuestionCard(
                    title:
                        '¿Usarás la app solo para vos o también para otras personas?',
                    description:
                        'Activa roles y dashboards comparativos cuando aplique.',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _professionalUseOptions
                          .map(
                            (item) => AppChoiceChip(
                              label: item,
                              selected: _professionalUse == item,
                              onSelected: (_) =>
                                  setState(() => _professionalUse = item),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  if (showProfessionalDetails) ...[
                    const SizedBox(height: 16),
                    _QuestionCard(
                      title: '¿Qué querés poder ver de otras personas?',
                      description: 'Define permisos de visualización.',
                      child: _MultiSelectWrap(
                        options: _visibilityOptions,
                        selected: _visibility,
                        onChanged: (item) => setState(
                          () => _toggleSelection(_visibility, item, null, true),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const _SectionTitle(title: '7️⃣ Integraciones automáticas'),
                  const SizedBox(height: 10),
                  _QuestionCard(
                    title: '¿Usás alguno de estos dispositivos?',
                    description:
                        'Solicitamos permisos correctos y priorizamos datos automáticos.',
                    child: _MultiSelectWrap(
                      options: _deviceOptions,
                      selected: _devices,
                      onChanged: (item) => setState(() {
                        if (item == 'Ninguno por ahora') {
                          _devices
                            ..clear()
                            ..add(item);
                          return;
                        }
                        _devices.remove('Ninguno por ahora');
                        _toggleSelection(_devices, item, null, true);
                      }),
                    ),
                  ),
                  if (showDataMergeQuestion) ...[
                    const SizedBox(height: 16),
                    _QuestionCard(
                      title:
                          '¿Querés que los datos automáticos reemplacen los manuales?',
                      description: 'Define reglas de consolidación de datos.',
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _dataMergeOptions
                            .map(
                              (item) => AppChoiceChip(
                                label: item,
                                selected: _dataMerge == item,
                                onSelected: (_) =>
                                    setState(() => _dataMerge = item),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const _SectionTitle(
                    title: '🧩 Resultado inmediato del onboarding',
                  ),
                  const SizedBox(height: 10),
                  _SummaryCard(
                    focusAreas: _focusAreas,
                    trainingLog: _trainingLog,
                    nutritionLog: _nutritionLog,
                    dailyTime: _dailyTime,
                    devices: _devices,
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    onPressed: _isSaving ? null : _submit,
                    icon: Icons.check_circle_rounded,
                    label: _existing == null
                        ? 'Comenzar con mi plan'
                        : 'Actualizar preferencias',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleSelection(
    Set<String> selection,
    String value, [
    int? max,
    bool allowEmpty = false,
  ]) {
    if (selection.contains(value)) {
      selection.remove(value);
      if (selection.isEmpty && !allowEmpty) {
        selection.add(value);
      }
      return;
    }
    if (max != null && selection.length >= max) {
      return;
    }
    selection.add(value);
  }

  String _mapSessionsToFrequency(int sessions) {
    if (sessions >= 5) return '5+ veces por semana';
    if (sessions >= 3) return '3–4 veces por semana';
    if (sessions >= 1) return '1–2 veces por semana';
    return 'Variable';
  }

  int _mapFrequencyToSessions(String frequency) {
    switch (frequency) {
      case '5+ veces por semana':
        return 5;
      case '3–4 veces por semana':
        return 3;
      case '1–2 veces por semana':
        return 2;
      case 'Variable':
      default:
        return 3;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final repository = RepositoryScope.of(context);
    final primaryGoal = _focusAreas.join(' + ');
    final preferences = UserPreferences(
      id: _existing?.id ?? 'current-user',
      primaryGoal: primaryGoal,
      experienceLevel: _contextStatus,
      targetSessionsPerWeek: _mapFrequencyToSessions(_trainingFrequency),
      modePreference: _trainingLog,
    );

    await repository.savePreferences(preferences, sync: true);

    if (!mounted) return;
    setState(() => _isSaving = false);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Perfil inicial configurado'),
        content: _SummaryDialogContent(
          focusAreas: _focusAreas,
          trainingLog: _trainingLog,
          nutritionLog: _nutritionLog,
          dailyTime: _dailyTime,
          devices: _devices,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Preferencias guardadas: $primaryGoal')),
    );

    Navigator.of(context).pushReplacementNamed('/home');
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.hasData});

  final bool hasData;

  @override
  Widget build(BuildContext context) {
    final description = hasData
        ? 'Podés editar estas respuestas cuando quieras, pero cambiarán las estadísticas históricas.'
        : 'Máximo 3 minutos. Cada respuesta activa módulos, métricas y reportes relevantes.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Configura tu experiencia',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _PrinciplesCard extends StatelessWidget {
  const _PrinciplesCard();

  @override
  Widget build(BuildContext context) {
    return SummaryCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _PrincipleRow(
            title: 'Máx. 3–5 minutos (ideal < 3)',
            subtitle: 'Nada de relleno: cada pregunta tiene impacto real.',
          ),
          _PrincipleRow(
            title: 'Progresivo',
            subtitle: 'Preguntas inteligentes que se adaptan a lo anterior.',
          ),
          _PrincipleRow(
            title: 'Editable después',
            subtitle: 'Dejamos claro que afecta estadísticas y reportes.',
          ),
        ],
      ),
    );
  }
}

class _PrincipleRow extends StatelessWidget {
  const _PrincipleRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textMuted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        fontFamily: 'Inter',
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SummaryCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(color: AppColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MultiSelectWrap extends StatelessWidget {
  const _MultiSelectWrap({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.maxSelection,
  });

  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onChanged;
  final int? maxSelection;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options
          .map(
            (item) => AppChoiceChip(
              label: item,
              selected: selected.contains(item),
              onSelected: (_) => onChanged(item),
            ),
          )
          .toList(),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.label,
    required this.controller,
    required this.hint,
  });

  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.focusAreas,
    required this.trainingLog,
    required this.nutritionLog,
    required this.dailyTime,
    required this.devices,
  });

  final Set<String> focusAreas;
  final String trainingLog;
  final String nutritionLog;
  final String dailyTime;
  final Set<String> devices;

  @override
  Widget build(BuildContext context) {
    final deviceText = devices.isEmpty
        ? 'Manual'
        : devices.contains('Ninguno por ahora')
        ? 'Manual'
        : 'Manual + ${devices.join(', ')}';

    return SummaryCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Perfil inicial configurado',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 12),
          _SummaryLine(
            label: 'Enfoque principal',
            value: focusAreas.join(' + '),
          ),
          _SummaryLine(
            label: 'Nivel de registro',
            value: 'Entrenamiento $trainingLog • Nutrición $nutritionLog',
          ),
          _SummaryLine(label: 'Registro diario estimado', value: dailyTime),
          _SummaryLine(label: 'Fuentes de datos', value: deviceText),
          const SizedBox(height: 10),
          const Text(
            'Los reportes se ajustarán automáticamente a este perfil.',
            style: TextStyle(color: AppColors.textMuted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '• $label: $value',
        style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
      ),
    );
  }
}

class _SummaryDialogContent extends StatelessWidget {
  const _SummaryDialogContent({
    required this.focusAreas,
    required this.trainingLog,
    required this.nutritionLog,
    required this.dailyTime,
    required this.devices,
  });

  final Set<String> focusAreas;
  final String trainingLog;
  final String nutritionLog;
  final String dailyTime;
  final Set<String> devices;

  @override
  Widget build(BuildContext context) {
    final deviceText = devices.isEmpty || devices.contains('Ninguno por ahora')
        ? 'Manual'
        : 'Manual + ${devices.join(', ')}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• Enfoque principal: ${focusAreas.join(' + ')}'),
        Text(
          '• Nivel de registro: Entrenamiento $trainingLog y nutrición $nutritionLog',
        ),
        Text('• Registro diario estimado: $dailyTime'),
        Text('• Fuentes de datos: $deviceText'),
        const SizedBox(height: 8),
        const Text('Los reportes se ajustarán automáticamente a este perfil.'),
      ],
    );
  }
}
