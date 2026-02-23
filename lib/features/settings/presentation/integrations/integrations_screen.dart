import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/data/app_preferences.dart';
import '../../../../core/integrations/fitbit_service.dart';
import '../../../../core/integrations/google_fit_service.dart';
import '../../../../core/integrations/healthkit_service.dart';
import 'integration_detail_screen.dart';
import 'integration_models.dart';
import 'widgets/integration_section_card.dart';
import 'widgets/integration_tile.dart';
import 'widgets/integrations_filter_chips.dart';

class IntegrationsSettingsScreen extends StatefulWidget {
  const IntegrationsSettingsScreen({super.key});

  @override
  State<IntegrationsSettingsScreen> createState() => _IntegrationsSettingsScreenState();
}

class _IntegrationsSettingsScreenState extends State<IntegrationsSettingsScreen> {
  AppPreferences? _prefs;
  final TextEditingController _searchController = TextEditingController();
  IntegrationsFilter _selectedFilter = IntegrationsFilter.all;
  Map<IntegrationId, IntegrationStatus> _statuses = {};

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() => setState(() {}));
  }

  Future<void> _load() async {
    final prefs = await AppPreferences.load();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _statuses = prefs.integrationStatuses;
    });
  }

  Future<void> _persist(IntegrationId id, IntegrationStatus status) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final updated = {..._statuses, id: status};
    await prefs.setIntegrationStatuses(updated);
    if (!mounted) return;
    setState(() => _statuses = updated);
  }

  IntegrationStatus _statusFor(IntegrationId id) => _statuses[id] ?? const IntegrationStatus();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allItems = _allItems;
    final sections = _buildSections(allItems);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Integraciones'),
        actions: [
          IconButton(
            onPressed: _showHelp,
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Ayuda',
          ),
        ],
      ),
      body: _prefs == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar integración…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 12),
                IntegrationsFilterChips(
                  selected: _selectedFilter,
                  onChanged: (value) => setState(() => _selectedFilter = value),
                ),
                const SizedBox(height: 12),
                ...sections,
              ],
            ),
    );
  }

  List<Widget> _buildSections(List<IntegrationItem> items) {
    final grouped = <IntegrationCategory, List<IntegrationItem>>{
      IntegrationCategory.activityTraining: [],
      IntegrationCategory.healthSensors: [],
      IntegrationCategory.sleep: [],
      IntegrationCategory.nutrition: [],
    };

    for (final item in items.where(_passesFilters)) {
      grouped[item.category]!.add(item);
    }

    final out = <Widget>[];
    grouped.forEach((category, list) {
      if (list.isEmpty) return;
      out.add(
        IntegrationSectionCard(
          title: _categoryTitle(category),
          children: [
            for (int i = 0; i < list.length; i++) ...[
              IntegrationTile(
                item: list[i],
                status: _statusFor(list[i].id),
                onTap: () => _openDetail(list[i]),
                onConnect: () => _handleConnect(list[i]),
              ),
              if (i != list.length - 1) Divider(color: Colors.white.withOpacity(0.08)),
            ]
          ],
        ),
      );
    });

    if (out.isEmpty) {
      out.add(const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: Text('No encontramos integraciones para ese filtro.')),
      ));
    }
    return out;
  }

  bool _passesFilters(IntegrationItem item) {
    final query = _searchController.text.trim().toLowerCase();
    final matchesSearch = query.isEmpty || item.title.toLowerCase().contains(query);
    if (!matchesSearch) return false;

    if (_selectedFilter == IntegrationsFilter.connected && !_statusFor(item.id).connected) {
      return false;
    }

    switch (_selectedFilter) {
      case IntegrationsFilter.all:
      case IntegrationsFilter.connected:
        return true;
      case IntegrationsFilter.fitness:
      case IntegrationsFilter.sports:
        return item.category == IntegrationCategory.activityTraining;
      case IntegrationsFilter.health:
        return item.category == IntegrationCategory.healthSensors;
      case IntegrationsFilter.sleep:
        return item.category == IntegrationCategory.sleep;
      case IntegrationsFilter.nutrition:
        return item.category == IntegrationCategory.nutrition;
    }
  }

  Future<void> _handleConnect(IntegrationItem item) async {
    if (!item.isAvailable) {
      _showSoonDialog(item);
      return;
    }

    bool success = false;
    switch (item.id) {
      case IntegrationId.appleHealth:
        if (!Platform.isIOS) {
          _showSoonDialog(item, message: 'Apple Health requiere iOS para conectarse.');
          return;
        }
        final service = HealthKitService();
        success = await service.hasPermissions() || await service.requestPermissions();
        break;
      case IntegrationId.googleFit:
        if (!Platform.isAndroid) {
          _showSoonDialog(item, message: 'Google Fit requiere Android para conectarse.');
          return;
        }
        final service = GoogleFitService();
        success = await service.hasPermissions() || await service.requestPermissions();
        break;
      case IntegrationId.fitbit:
        final service = FitbitService();
        success = await service.hasPermissions() || await service.requestPermissions();
        break;
      default:
        success = true;
    }

    if (!success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo completar la conexión.')));
      return;
    }

    await _persist(item.id, IntegrationStatus(enabled: true, connected: true, lastSync: DateTime.now()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.title} conectado.')));
  }

  Future<void> _disconnect(IntegrationItem item) async {
    await _persist(item.id, const IntegrationStatus(enabled: false, connected: false));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.title} desconectado.')));
  }

  Future<void> _openDetail(IntegrationItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IntegrationDetailScreen(
          item: item,
          status: _statusFor(item.id),
          onConnect: () => _handleConnect(item),
          onDisconnect: () => _disconnect(item),
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  void _showSoonDialog(IntegrationItem item, {String? message}) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message ?? 'Esta integración estará disponible pronto.'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ayuda'),
        content: const Text('Conectá tus apps y dispositivos para importar actividad, salud, sueño y nutrición automáticamente.'),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar'))],
      ),
    );
  }

  String _categoryTitle(IntegrationCategory category) {
    switch (category) {
      case IntegrationCategory.activityTraining:
        return 'Actividad & Entrenamiento';
      case IntegrationCategory.healthSensors:
        return 'Salud & Sensores';
      case IntegrationCategory.sleep:
        return 'Sueño';
      case IntegrationCategory.nutrition:
        return 'Nutrición';
    }
  }
}

const List<IntegrationItem> _allItems = [
  IntegrationItem(
    id: IntegrationId.strava,
    title: 'Strava',
    subtitle: 'Rutas, actividades y rendimiento.',
    category: IntegrationCategory.activityTraining,
    isAvailable: false,
    iconData: Icons.route_rounded,
    description: 'Sincroniza entrenamientos al aire libre, segmentos y métricas de actividad.',
    importableData: ['Carreras y ciclismo', 'Distancia y ritmo', 'Frecuencia cardíaca'],
  ),
  IntegrationItem(
    id: IntegrationId.trainingPeaks,
    title: 'TrainingPeaks',
    subtitle: 'Planificación de cargas y sesiones.',
    category: IntegrationCategory.activityTraining,
    isAvailable: false,
    iconData: Icons.trending_up_rounded,
    description: 'Importa métricas de entrenamiento estructurado y cumplimiento de planificación.',
    importableData: ['TSS y carga', 'Sesiones completadas', 'Duración e intensidad'],
  ),
  IntegrationItem(
    id: IntegrationId.garmin,
    title: 'Garmin',
    subtitle: 'Actividad diaria y entrenamientos GPS.',
    category: IntegrationCategory.activityTraining,
    isAvailable: false,
    iconData: Icons.watch_rounded,
    description: 'Conecta tus métricas de Garmin Connect para ver actividad y rendimiento.',
    importableData: ['Pasos', 'Entrenamientos', 'Frecuencia cardíaca'],
  ),
  IntegrationItem(
    id: IntegrationId.suunto,
    title: 'Suunto',
    subtitle: 'Entrenamientos outdoor y multideporte.',
    category: IntegrationCategory.activityTraining,
    isAvailable: false,
    iconData: Icons.terrain_rounded,
    description: 'Importa actividades de montaña y sesiones multideporte.',
    importableData: ['Altimetría', 'Distancia', 'Pulsaciones'],
  ),
  IntegrationItem(
    id: IntegrationId.polar,
    title: 'Polar',
    subtitle: 'HRV, recuperación y sesiones.',
    category: IntegrationCategory.activityTraining,
    isAvailable: false,
    iconData: Icons.monitor_heart_rounded,
    description: 'Conecta datos de Polar Flow para seguimiento de cargas y recuperación.',
    importableData: ['Entrenamientos', 'Frecuencia cardíaca', 'Recuperación'],
  ),
  IntegrationItem(
    id: IntegrationId.catapult,
    title: 'Catapult Sports',
    subtitle: 'Métricas de alto rendimiento.',
    category: IntegrationCategory.activityTraining,
    isAvailable: false,
    iconData: Icons.sports_soccer_rounded,
    description: 'Integra métricas de rendimiento usadas en deportes de equipo.',
    importableData: ['Player load', 'Aceleraciones', 'Distancias de alta intensidad'],
  ),
  IntegrationItem(
    id: IntegrationId.fitbit,
    title: 'Fitbit (reloj)',
    subtitle: 'Pasos, calorías y actividad.',
    category: IntegrationCategory.activityTraining,
    isAvailable: true,
    iconData: Icons.fitness_center_rounded,
    description: 'Importa actividad, sueño y señales de salud desde Fitbit.',
    importableData: ['Pasos', 'Entrenamientos', 'Sueño básico'],
  ),
  IntegrationItem(
    id: IntegrationId.whoop,
    title: 'Whoop (reloj)',
    subtitle: 'Strain, recuperación y sueño.',
    category: IntegrationCategory.activityTraining,
    isAvailable: false,
    iconData: Icons.bolt_rounded,
    description: 'Integra métricas de strain y recuperación para optimizar entrenamiento.',
    importableData: ['Strain', 'Recovery score', 'Sueño'],
  ),
  IntegrationItem(
    id: IntegrationId.appleWatch,
    title: 'Apple Watch',
    subtitle: 'Actividad y anillos diarios.',
    category: IntegrationCategory.activityTraining,
    isAvailable: false,
    iconData: Icons.watch,
    description: 'Sincroniza actividad registrada por Apple Watch.',
    importableData: ['Move/Exercise/Stand', 'Entrenamientos', 'Pulsaciones'],
  ),
  IntegrationItem(
    id: IntegrationId.appleHealth,
    title: 'Apple Health',
    subtitle: 'Hub de salud en iPhone.',
    category: IntegrationCategory.healthSensors,
    isAvailable: true,
    iconData: Icons.health_and_safety_rounded,
    description: 'Permite leer entrenamientos, sueño, pasos y nutrición desde HealthKit.',
    importableData: ['Pasos', 'Sueño', 'Entrenamientos', 'Nutrición'],
  ),
  IntegrationItem(
    id: IntegrationId.googleFit,
    title: 'Google Fit',
    subtitle: 'Actividad y métricas en Android.',
    category: IntegrationCategory.healthSensors,
    isAvailable: true,
    iconData: Icons.favorite_rounded,
    description: 'Conecta Google Fit para sincronizar actividad y métricas de bienestar.',
    importableData: ['Pasos', 'Puntos cardio', 'Entrenamientos', 'Sueño'],
  ),
  IntegrationItem(
    id: IntegrationId.hrStrap,
    title: 'Pechera cardíaca (HR strap)',
    subtitle: 'Frecuencia cardíaca de alta precisión.',
    category: IntegrationCategory.healthSensors,
    isAvailable: false,
    iconData: Icons.sensors_rounded,
    description: 'Conecta bandas pectorales para capturar pulsaciones en tiempo real.',
    importableData: ['Frecuencia cardíaca en vivo', 'Zonas de pulso', 'Promedio por sesión'],
  ),
  IntegrationItem(
    id: IntegrationId.ring,
    title: 'Anillo pulsaciones',
    subtitle: 'Lecturas continuas de pulso.',
    category: IntegrationCategory.healthSensors,
    isAvailable: false,
    iconData: Icons.radio_button_checked_rounded,
    description: 'Sincroniza sensores en formato anillo para métricas de pulso y recuperación.',
    importableData: ['Pulso basal', 'Variabilidad cardíaca', 'Tendencias diarias'],
  ),
  IntegrationItem(
    id: IntegrationId.oura,
    title: 'Oura Ring',
    subtitle: 'Sueño y recuperación avanzada.',
    category: IntegrationCategory.healthSensors,
    isAvailable: false,
    iconData: Icons.nightlight_round,
    description: 'Conecta Oura para métricas de descanso, readiness y recuperación.',
    importableData: ['Sleep score', 'Readiness score', 'Frecuencia nocturna'],
  ),
  IntegrationItem(
    id: IntegrationId.sleepCycle,
    title: 'Sleep Cycle',
    subtitle: 'Calidad de sueño y despertares.',
    category: IntegrationCategory.sleep,
    isAvailable: false,
    iconData: Icons.bedtime_rounded,
    description: 'Importa análisis de ciclos de sueño y consistencia nocturna.',
    importableData: ['Duración de sueño', 'Calidad', 'Hora de dormir/despertar'],
  ),
  IntegrationItem(
    id: IntegrationId.openFoodFacts,
    title: 'Open Food Facts',
    subtitle: 'Base colaborativa de alimentos.',
    category: IntegrationCategory.nutrition,
    isAvailable: false,
    iconData: Icons.qr_code_scanner_rounded,
    description: 'Escanea productos y sincroniza datos nutricionales en tu registro.',
    importableData: ['Macros por producto', 'Ingredientes', 'Información por código de barras'],
  ),
  IntegrationItem(
    id: IntegrationId.myFitnessPal,
    title: 'MyFitnessPal',
    subtitle: 'Registro nutricional completo.',
    category: IntegrationCategory.nutrition,
    isAvailable: false,
    iconData: Icons.restaurant_menu_rounded,
    description: 'Trae comidas y objetivos calóricos desde MyFitnessPal.',
    importableData: ['Comidas registradas', 'Calorías diarias', 'Macros'],
  ),
  IntegrationItem(
    id: IntegrationId.cronometer,
    title: 'Cronometer',
    subtitle: 'Micronutrientes y macros detallados.',
    category: IntegrationCategory.nutrition,
    isAvailable: false,
    iconData: Icons.pie_chart_outline_rounded,
    description: 'Integra datos nutricionales avanzados y micronutrientes.',
    importableData: ['Macros', 'Vitaminas y minerales', 'Consumo diario'],
  ),
];
