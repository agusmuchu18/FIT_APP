import 'dart:ui';

import 'package:flutter/material.dart';

import '../common/theme/app_colors.dart';
import 'profile_controller.dart';
import 'profile_settings_screen.dart';
import 'widgets/profile_social_widgets.dart';

class ProfileProgressPhoto {
  const ProfileProgressPhoto({
    required this.id,
    required this.url,
    required this.dateLabel,
    this.tag,
  });

  final String id;
  final String url;
  final String dateLabel;
  final String? tag;
}

class ProfileSocialScreen extends StatelessWidget {
  const ProfileSocialScreen({super.key});

  static final List<ProfileProgressPhoto> _photos = [
    const ProfileProgressPhoto(id: 'p1', url: 'https://picsum.photos/300/420?1', dateLabel: '10 Mar 2026', tag: 'Semana 1'),
    const ProfileProgressPhoto(id: 'p2', url: 'https://picsum.photos/300/420?2', dateLabel: '18 Mar 2026', tag: 'Semana 2'),
    const ProfileProgressPhoto(id: 'p3', url: 'https://picsum.photos/300/420?3', dateLabel: '27 Mar 2026', tag: 'Semana 3'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 230,
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
                        colors: [Color(0x99276EF1), Color(0x334CD6B8), AppColors.background],
                      ),
                    ),
                  ),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(color: Colors.black.withOpacity(0.14)),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: ValueListenableBuilder<String>(
                          valueListenable: ProfileController.instance.displayName,
                          builder: (context, name, _) {
                            return ValueListenableBuilder(
                              valueListenable: ProfileController.instance.avatarBytes,
                              builder: (context, avatar, __) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.accentSecondary.withOpacity(0.6))),
                                      child: CircleAvatar(
                                        radius: 40,
                                        backgroundColor: AppColors.card,
                                        backgroundImage: avatar == null ? null : MemoryImage(avatar),
                                        child: avatar == null ? const Icon(Icons.person, size: 36, color: AppColors.textMuted) : null,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 21, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 4),
                                          const Text('@fit_user', style: TextStyle(color: AppColors.textMuted)),
                                          const SizedBox(height: 6),
                                          const Text('Contá algo sobre vos…', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FilledButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileSettingsScreen())),
                        style: FilledButton.styleFrom(shape: const StadiumBorder(), backgroundColor: AppColors.accentSecondary),
                        child: const Text('Editar perfil'),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        onPressed: () {},
                        icon: const Icon(Icons.share_rounded),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.accentSecondary.withOpacity(0.18), borderRadius: BorderRadius.circular(999)),
                        child: const Text('Premium activo', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                      )
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 132,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: const [
                        HighlightCard(title: 'Objetivo actual', description: 'Bajar grasa sin perder fuerza', icon: Icons.flag_rounded, progress: 0.62),
                        HighlightCard(title: 'Enfoque semanal', description: 'Prioridad: espalda', icon: Icons.fitness_center_rounded),
                        HighlightCard(title: 'Racha / constancia', description: 'Vas 4 días seguidos', icon: Icons.local_fire_department_rounded),
                        HighlightCard(title: 'Última actividad', description: 'Entrenaste hoy', icon: Icons.bolt_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(
                    title: 'Fotos de progreso',
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      TextButton(onPressed: () => Navigator.of(context).pushNamed('/profile/progress_photos'), child: const Text('Ver todas')),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {},
                        style: FilledButton.styleFrom(shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                        child: const Text('+ Agregar'),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: _photos.isEmpty
                        ? _ProgressEmptyState(onAdd: () {})
                        : SizedBox(
                            key: const ValueKey('photos'),
                            height: 172,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: _photos
                                  .map((photo) => ProgressPhotoCard(
                                        image: NetworkImage(photo.url),
                                        dateLabel: photo.dateLabel,
                                        tag: photo.tag,
                                        heroTag: 'progress-${photo.id}',
                                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                          builder: (_) => ProgressPhotoViewerScreen(photo: photo),
                                        )),
                                      ))
                                  .toList(),
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(
                    title: 'Actividad reciente',
                    trailing: TextButton(
                      onPressed: () => Navigator.of(context).pushNamed('/profile/activity'),
                      child: const Text('Ver historial'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const ActivityTile(icon: Icons.fitness_center_rounded, title: 'Entrenaste Torso (45 min)', subtitle: 'Hoy · 08:20'),
                  const ActivityTile(icon: Icons.nightlight_round, title: 'Completaste hábitos de sueño', subtitle: 'Ayer · 22:43'),
                  const ActivityTile(icon: Icons.emoji_events_rounded, title: 'Nuevo PR en dominadas', subtitle: 'Ayer · 18:10'),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.trailing});

  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18))),
        trailing,
      ],
    );
  }
}

class _ProgressEmptyState extends StatelessWidget {
  const _ProgressEmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('empty'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Column(
        children: [
          Icon(Icons.photo_library_outlined, color: Colors.white.withOpacity(0.72)),
          const SizedBox(height: 8),
          const Text('Todavía no hay fotos de progreso', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Guardá tus cambios y compará tu evolución semana a semana.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 10),
          FilledButton(onPressed: onAdd, child: const Text('Agregar primera foto')),
        ],
      ),
    );
  }
}

class ProgressPhotoViewerScreen extends StatelessWidget {
  const ProgressPhotoViewerScreen({super.key, required this.photo});

  final ProfileProgressPhoto photo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: Hero(
          tag: 'progress-${photo.id}',
          child: InteractiveViewer(
            child: Image.network(photo.url, fit: BoxFit.contain),
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
    final photos = ProfileSocialScreen._photos;
    return Scaffold(
      appBar: AppBar(title: const Text('Fotos de progreso')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.72),
        itemCount: photos.length,
        itemBuilder: (context, index) {
          final photo = photos[index];
          return InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProgressPhotoViewerScreen(photo: photo))),
            child: Hero(
              tag: 'progress-${photo.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(photo.url, fit: BoxFit.cover),
              ),
            ),
          );
        },
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
