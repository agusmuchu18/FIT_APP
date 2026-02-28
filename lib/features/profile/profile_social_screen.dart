import 'dart:ui';

import 'package:flutter/material.dart';

import '../common/theme/app_colors.dart';
import 'profile_controller.dart';
import 'profile_settings_screen.dart';
import 'profile_social_models.dart';
import 'widgets/profile_social_widgets.dart';

class ProfileSocialScreen extends StatelessWidget {
  const ProfileSocialScreen({super.key});

  static final List<ProfileProgressPhoto> _photos = [
    const ProfileProgressPhoto(id: 'p1', url: 'https://picsum.photos/300/420?1', dateLabel: '10 Mar 2026'),
    const ProfileProgressPhoto(id: 'p2', url: 'https://picsum.photos/300/420?2', dateLabel: '18 Mar 2026'),
    const ProfileProgressPhoto(id: 'p3', url: 'https://picsum.photos/300/420?3', dateLabel: '27 Mar 2026'),
    const ProfileProgressPhoto(id: 'p4', url: 'https://picsum.photos/300/420?4', dateLabel: '03 Abr 2026'),
    const ProfileProgressPhoto(id: 'p5', url: 'https://picsum.photos/300/420?5', dateLabel: '11 Abr 2026'),
    const ProfileProgressPhoto(id: 'p6', url: 'https://picsum.photos/300/420?6', dateLabel: '19 Abr 2026'),
  ];

  static const List<ProfileStatItem> _heroStats = [
    ProfileStatItem(label: 'Entrenos', value: '148'),
    ProfileStatItem(label: 'Racha', value: '12', unit: 'días'),
    ProfileStatItem(label: 'Peso', value: '77.8', unit: 'kg'),
    ProfileStatItem(label: 'Último PR', value: '120', unit: 'kg'),
  ];

  static const List<ProfileStatItem> _metrics = [
    ProfileStatItem(label: 'Adherencia semanal', value: '92', unit: '%'),
    ProfileStatItem(label: 'Volumen promedio', value: '14.2', unit: 't/sem'),
    ProfileStatItem(label: 'Descanso medio', value: '7.6', unit: 'h'),
    ProfileStatItem(label: 'Recuperación', value: 'Óptima'),
  ];

  static const List<ProfilePRItem> _prs = [
    ProfilePRItem(exercise: 'Sentadilla', value: '140 kg', detail: '5 reps · Hace 4 días', icon: Icons.fitness_center_rounded),
    ProfilePRItem(exercise: 'Press banca', value: '105 kg', detail: '3 reps · Hace 1 semana', icon: Icons.sports_gymnastics_rounded),
    ProfilePRItem(exercise: 'Peso muerto', value: '180 kg', detail: '2 reps · Hace 9 días', icon: Icons.bolt_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 410,
              backgroundColor: AppColors.background,
              actions: [
                IconButton(
                  onPressed: () => Navigator.of(context).pushNamed('/settings'),
                  icon: const Icon(Icons.settings_rounded),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xCC4A6BFF), Color(0x995D43FF), Color(0x3336D0B4), AppColors.background],
                          stops: [0, 0.35, 0.7, 1],
                        ),
                      ),
                    ),
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(color: Colors.black.withOpacity(0.16)),
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
                                  username: '@fit_user',
                                  subtitle: 'En definición',
                                  avatarProvider: avatar == null ? null : MemoryImage(avatar),
                                  stats: _heroStats,
                                  onAvatarTap: () => Navigator.of(context).push(_avatarViewerRoute(context, avatar == null ? null : MemoryImage(avatar))),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.background.withOpacity(0.92),
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                  ),
                  child: const TabBar(
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
              ),
            ),
            SliverFillRemaining(
              child: TabBarView(
                children: [
                  _PhotosTab(photos: _photos),
                  _StatsTab(metrics: _metrics),
                  _PRsTab(items: _prs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
  const _StatsTab({required this.metrics});

  final List<ProfileStatItem> metrics;

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      child: GridView.builder(
        itemCount: widget.metrics.length,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
        ),
        itemBuilder: (context, index) {
          final metric = widget.metrics[index];
          return MinimalMetricCard(item: metric);
        },
      ),
    );
  }
}

class _PRsTab extends StatefulWidget {
  const _PRsTab({required this.items});

  final List<ProfilePRItem> items;

  @override
  State<_PRsTab> createState() => _PRsTabState();
}

class _PRsTabState extends State<_PRsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      itemCount: widget.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => ProfilePRCard(item: widget.items[index]),
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
