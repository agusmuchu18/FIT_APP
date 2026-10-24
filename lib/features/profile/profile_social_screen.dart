import '../workout/presentation/widgets/workout_report_widgets.dart';
import '../workout/presentation/widgets/workout_units_host.dart';
import '../workout/presentation/workout_insights_screen.dart';
import '../workout/presentation/workout_profile_summary.dart';
import '../workout/domain/training_units.dart';
import '../workout/data/workout_repository.dart';
import '../workout/presentation/workout_records_panel.dart';

import 'dart:ui';

import 'package:flutter/material.dart';

import '../common/theme/app_colors.dart';
import 'profile_controller.dart';
import 'body_measurements_screen.dart';
import 'profile_settings_screen.dart';
import 'profile_social_models.dart';
import 'widgets/profile_social_widgets.dart';

class ProfileSocialScreen extends StatefulWidget {
  static List<ProfileProgressPhoto> get _photos =>
      _ProfileSocialScreenState._photos;
  const ProfileSocialScreen({
    super.key,
    this.repository,
    this.now,
    this.photos,
    this.active = true,
  });
  final WorkoutRepository? repository;
  final DateTime? now;
  final List<ProfileProgressPhoto>? photos;
  final bool active;
  @override
  State<ProfileSocialScreen> createState() => _ProfileSocialScreenState();
}

class _ProfileSocialScreenState extends State<ProfileSocialScreen> {
  late WorkoutRepository _repository;
  WorkoutProfileSummary? _training;
  var _loading = true;
  bool _failed = false;
  var _generation = 0;
  var _needsRefresh = true;
  DateTime? _loadedDay;
  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? WorkoutRepository();
    _repository.historyRevision.addListener(_loadTraining);
    _loadTraining();
  }

  @override
  void didUpdateWidget(covariant ProfileSocialScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _generation++;
      _training = null;
      _loading = true;
      _failed = false;
      _loadedDay = null;
      _repository.historyRevision.removeListener(_loadTraining);
      _repository = widget.repository ?? WorkoutRepository();
      _repository.historyRevision.addListener(_loadTraining);
      _loadTraining();
    } else if (oldWidget.now != widget.now) {
      _loadTraining();
    } else if (!oldWidget.active &&
        widget.active &&
        (_needsRefresh ||
            _failed ||
            !DateUtils.isSameDay(_loadedDay, widget.now ?? DateTime.now()))) {
      _loadTraining();
    } else if (oldWidget.active && !widget.active && _loading) {
      _generation++;
      _needsRefresh = true;
    }
  }

  @override
  void dispose() {
    _generation++;
    _repository.historyRevision.removeListener(_loadTraining);
    super.dispose();
  }

  Future<void> _loadTraining() async {
    if (!widget.active) {
      _needsRefresh = true;
      return;
    }
    _needsRefresh = false;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
      _training = null;
    });
    try {
      final index = await _repository.performanceIndex();
      if (!mounted ||
          generation != _generation ||
          !_repository.isCurrentScope) {
        return;
      }
      setState(() {
        _training = WorkoutProfileSummary.fromIndex(index, now: widget.now);
        _loadedDay = DateUtils.dateOnly(widget.now ?? DateTime.now());
        _loading = false;
      });
    } catch (_) {
      if (mounted && generation == _generation && _repository.isCurrentScope) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  List<ProfileStatItem> get _heroStats {
    final data = _training,
        empty = _loading ? '…' : '—',
        units = WorkoutUnits.of(context),
        mark = data?.latestRecord;
    return [
      ProfileStatItem(
        label: 'Entrenos',
        value: data == null ? empty : '${data.allSessions}',
      ),
      ProfileStatItem(
        label: 'Series (30d)',
        value: data == null ? empty : '${data.recent.sets}',
      ),
      ProfileStatItem(
        label: 'Días (30d)',
        value: data == null ? empty : '${data.recent.sessionsByDay.length}',
      ),
      ProfileStatItem(
        label: 'Última marca',
        value: mark == null
            ? data == null
                  ? empty
                  : '—'
            : TrainingUnits.number(units.metricValue(mark.unit, mark.value)),
        unit: mark == null ? null : units.metricUnit(mark.unit),
      ),
    ];
  }

  List<ProfileStatItem> get _metrics {
    final stats = _training?.recent,
        units = WorkoutUnits.of(context),
        empty = _loading ? '…' : '—';
    return [
      ProfileStatItem(
        label: 'Frecuencia (30d)',
        value: stats == null
            ? empty
            : TrainingUnits.number(stats.weeklyFrequency),
        unit: stats == null ? null : 'sesiones/sem',
      ),
      ProfileStatItem(
        label: 'Volumen externo (30d)',
        value: stats == null
            ? empty
            : TrainingUnits.number(units.weight.fromKg(stats.volume)),
        unit: stats == null ? null : '${units.weight.label}·rep',
      ),
      ProfileStatItem(
        label: 'Tiempo registrado (30d)',
        value: stats == null
            ? empty
            : stats.knownDurations == 0
            ? 'Sin registro'
            : workoutDuration(Duration(seconds: stats.durationSeconds)),
      ),
      ProfileStatItem(
        label: 'Duración media (30d)',
        value: stats == null
            ? empty
            : stats.averageDurationSeconds == null
            ? 'Sin registro comparable'
            : workoutDuration(
                Duration(seconds: stats.averageDurationSeconds!.round()),
              ),
      ),
    ];
  }

  void _openTrainingInsights() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          WorkoutInsightsScreen(repository: _repository, now: widget.now),
    ),
  );

  static const List<ProfileProgressPhoto> _photos = [];

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final tabHeight = MediaQuery.textScalerOf(context).scale(20) + 32;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          actions: [
            IconButton(
              onPressed: () => Navigator.of(context).pushNamed('/settings'),
              icon: const Icon(Icons.settings_rounded),
            ),
          ],
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerScrolled) => [
            SliverToBoxAdapter(child: _profileHeader(context, intrinsic: true)),
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverPersistentHeader(
                pinned: true,
                delegate: _ProfileTrainingTabs(
                  height: tabHeight,
                  child: _profileTabs(context, compact, tabHeight),
                ),
              ),
            ),
          ],
          // The pinned tab strip is opaque and has a known, text-scaled extent.
          // Reserve its absorbed overlap outside each lazy inner list so content
          // never paints underneath the controls, including after header collapse.
          body: Padding(
            padding: EdgeInsets.only(top: tabHeight),
            child: TabBarView(
              children: [
                _PhotosTab(photos: widget.photos ?? _photos),
                _StatsTab(
                  metrics: _metrics,
                  training: _training,
                  loading: _loading,
                  failed: _failed,
                  onRetry: _loadTraining,
                  onOpen: _openTrainingInsights,
                ),
                WorkoutRecordsPanel(
                  key: ObjectKey(_repository),
                  repository: _repository,
                  primary: true,
                  active: widget.active,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileHeader(BuildContext context, {required bool intrinsic}) =>
      ClipRect(
        child: Stack(
          fit: intrinsic ? StackFit.loose : StackFit.expand,
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xCC4A6BFF),
                      Color(0x995D43FF),
                      Color(0x3336D0B4),
                      AppColors.background,
                    ],
                    stops: [0, 0.35, 0.7, 1],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(color: Colors.black.withOpacity(0.16)),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 8),
                child: ValueListenableBuilder<String>(
                  valueListenable: ProfileController.instance.displayName,
                  builder: (context, name, _) {
                    return ValueListenableBuilder(
                      valueListenable: ProfileController.instance.avatarBytes,
                      builder: (context, avatar, __) {
                        return ProfileHero(
                          displayName: name,
                          username: 'Perfil privado',
                          subtitle: 'Solo vos',
                          avatarProvider: avatar == null
                              ? null
                              : MemoryImage(avatar),
                          stats: _heroStats,
                          onAvatarTap: () => Navigator.of(context).push(
                            _avatarViewerRoute(
                              context,
                              avatar == null ? null : MemoryImage(avatar),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
  Widget _profileTabs(BuildContext context, bool compact, double tabHeight) =>
      SizedBox(
        height: tabHeight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
          ),
          child: TabBar(
            isScrollable: compact,
            tabAlignment: compact ? TabAlignment.start : TabAlignment.fill,
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textMuted,
            indicator: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            tabs: [
              Tab(text: 'Fotos'),
              Tab(text: 'Estadísticas'),
              Tab(text: 'PRs'),
            ],
          ),
        ),
      );

  Route<void> _avatarViewerRoute(BuildContext context, ImageProvider<Object>? avatarProvider) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => ProfileAvatarFullscreen(imageProvider: avatarProvider),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic), child: child);
      },
    );
  }
}

class _PhotosTab extends StatefulWidget {
  const _PhotosTab({required this.photos});

  final List<ProfileProgressPhoto> photos;

  @override
  State<_PhotosTab> createState() => _PhotosTabState();
}

class _PhotosTabState extends State<_PhotosTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.photos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: ProfilePhotoGrid(
        photos: widget.photos,
        onPhotoTap: (index) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProgressPhotoViewerScreen(
                photos: widget.photos,
                initialIndex: index,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatsTab extends StatefulWidget {
  const _StatsTab({
    required this.metrics,
    required this.training,
    required this.loading,
    required this.failed,
    required this.onRetry,
    required this.onOpen,
  });
  final List<ProfileStatItem> metrics;
  final WorkoutProfileSummary? training;
  final bool loading, failed;
  final VoidCallback onRetry, onOpen;
  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.loading) {
      return const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Cargando estadísticas de entrenamiento',
        ),
      );
    }
    if (widget.failed) {
      return ListView(
        primary: true,
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'No se pudieron leer tus entrenamientos. Tus registros se conservan. Reintentá para ver tus estadísticas.',
          ),
          TextButton(
            onPressed: widget.onRetry,
            child: const Text('Reintentar estadísticas'),
          ),
        ],
      );
    }
    final stats = widget.training!.recent, mark = widget.training!.latestRecord;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth < 360 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3
            ? 1
            : 2;
        final width =
            (constraints.maxWidth - 32 - 12 * (columns - 1)) / columns;
        return ListView(
          primary: true,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.straighten_outlined),
              label: const Text('Medidas corporales privadas'),
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => const BodyMeasurementsScreen(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tu entrenamiento · últimos 30 días',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (stats.sessions.isEmpty)
              const Text('Sin sesiones guardadas en los últimos 30 días.'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final item in widget.metrics)
                  SizedBox(
                    width: width,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            120 * MediaQuery.textScalerOf(context).scale(1),
                      ),
                      child: MinimalMetricCard(item: item),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Duración disponible en ${stats.knownDurations} de ${stats.sessions.length} sesiones. La media requiere el mismo criterio de medición.',
            ),
            const Text(
              'El tiempo sin pausas incluye los descansos. No estima tiempo efectivo de ejercicio ni recuperación.',
            ),
            if (stats.ambiguousVolumes > 0)
              const Text(
                'Volumen conocido parcial: las cargas antiguas sin clasificación se excluyen.',
              ),
            if (stats.unknownCompletion)
              const Text(
                'Incluye registros antiguos sin confirmación de finalización; no certifican récords.',
              ),
            const SizedBox(height: 16),
            Text(
              mark == null
                  ? 'Todavía no hay marcas verificables.'
                  : 'Última marca vigente: ${mark.exerciseName} · ${mark.kind.label} · ${mark.loadLabel} · ${workoutDate(mark.date)}${mark.estimated ? '. Es una estimación, no un máximo medido.' : ''}',
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: widget.onOpen,
              icon: const Icon(Icons.insights_outlined),
              label: const Text('Ver análisis de entrenamiento'),
            ),
          ],
        );
      },
    );
  }
}

class ProgressPhotoViewerScreen extends StatefulWidget {
  const ProgressPhotoViewerScreen({super.key, required this.photos, required this.initialIndex});

  final List<ProfileProgressPhoto> photos;
  final int initialIndex;

  @override
  State<ProgressPhotoViewerScreen> createState() => _ProgressPhotoViewerScreenState();
}

class _ProgressPhotoViewerScreenState extends State<ProgressPhotoViewerScreen> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (value) => setState(() => _currentIndex = value),
            itemBuilder: (context, index) {
              final photo = widget.photos[index];
              return Center(
                child: Hero(
                  tag: 'progress-${photo.id}',
                  child: InteractiveViewer(
                    minScale: 0.9,
                    maxScale: 3.2,
                    child: Image.network(photo.url, fit: BoxFit.contain),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            left: 12,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 30,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.44),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.photos[_currentIndex].dateLabel,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class ProfileAvatarFullscreen extends StatefulWidget {
  const ProfileAvatarFullscreen({super.key, this.imageProvider});

  final ImageProvider<Object>? imageProvider;

  @override
  State<ProfileAvatarFullscreen> createState() => _ProfileAvatarFullscreenState();
}

class _ProfileAvatarFullscreenState extends State<ProfileAvatarFullscreen> {
  double _dragOffset = 0;

  @override
  Widget build(BuildContext context) {
    final opacity = (1 - (_dragOffset.abs() / 280)).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        onVerticalDragUpdate: (details) {
          setState(() => _dragOffset += details.primaryDelta ?? 0);
        },
        onVerticalDragEnd: (details) {
          if (_dragOffset.abs() > 120 || (details.primaryVelocity ?? 0).abs() > 900) {
            Navigator.of(context).pop();
            return;
          }
          setState(() => _dragOffset = 0);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          color: Colors.black.withOpacity(opacity),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Transform.translate(
                  offset: Offset(0, _dragOffset),
                  child: GestureDetector(
                    onTap: () {},
                    child: Hero(
                      tag: 'profile-avatar-hero',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: widget.imageProvider == null
                            ? Container(
                                width: 320,
                                height: 320,
                                color: AppColors.card,
                                child: const Icon(Icons.person, size: 140, color: AppColors.textMuted),
                              )
                            : Image(image: widget.imageProvider!, width: 340, height: 340, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 12,
                right: 16,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileSettingsScreen())),
                  icon: const Icon(Icons.photo_camera_outlined, color: Colors.white),
                  label: const Text('Cambiar foto', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class ProgressPhotosGalleryScreen extends StatelessWidget {
  const ProgressPhotosGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fotos de progreso')),
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: ProfilePhotoGrid(
          photos: ProfileSocialScreen._photos,
          onPhotoTap: (index) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProgressPhotoViewerScreen(
                  photos: ProfileSocialScreen._photos,
                  initialIndex: index,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ProfileActivityHistoryScreen extends StatelessWidget {
  const ProfileActivityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de actividad')),
      body: const Center(
        child: Text('Próximamente: historial completo de actividad', style: TextStyle(color: AppColors.textMuted)),
      ),
    );
  }
}

class _ProfileTrainingTabs extends SliverPersistentHeaderDelegate {
  _ProfileTrainingTabs({required this.height, required this.child});
  final double height;
  final Widget child;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;
  @override
  bool shouldRebuild(covariant _ProfileTrainingTabs old) =>
      height != old.height || child != old.child;
}
