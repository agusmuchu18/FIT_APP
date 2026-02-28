import 'package:flutter/material.dart';

import '../../common/theme/app_colors.dart';
import '../profile_social_models.dart';

class ProfileHero extends StatelessWidget {
  const ProfileHero({
    super.key,
    required this.displayName,
    required this.username,
    required this.subtitle,
    required this.stats,
    this.avatarProvider,
    required this.onAvatarTap,
  });

  final String displayName;
  final String username;
  final String subtitle;
  final List<ProfileStatItem> stats;
  final ImageProvider<Object>? avatarProvider;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Center(
          child: GestureDetector(
            onTap: onAvatarTap,
            child: Hero(
              tag: 'profile-avatar-hero',
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.28), blurRadius: 24, offset: const Offset(0, 12)),
                  ],
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: CircleAvatar(
                  radius: 58,
                  backgroundColor: AppColors.card,
                  backgroundImage: avatarProvider,
                  child: avatarProvider == null ? const Icon(Icons.person, size: 54, color: AppColors.textMuted) : null,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Column(
            children: [
              Text(displayName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(username, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.card.withOpacity(0.8), borderRadius: BorderRadius.circular(999)),
                child: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ProfileStatsRow(items: stats),
      ],
    );
  }
}

class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({super.key, required this.items});

  final List<ProfileStatItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: items
            .map(
              (item) => Expanded(
                child: _AnimatedStatValue(item: item),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _AnimatedStatValue extends StatelessWidget {
  const _AnimatedStatValue({required this.item});

  final ProfileStatItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
          child: Text(
            key: ValueKey(item.value),
            item.unit == null ? item.value : '${item.value} ${item.unit}',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 4),
        Text(item.label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }
}

class ProfilePhotoGrid extends StatelessWidget {
  const ProfilePhotoGrid({
    super.key,
    required this.photos,
    required this.onPhotoTap,
  });

  final List<ProfileProgressPhoto> photos;
  final ValueChanged<int> onPhotoTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: photos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) {
        final photo = photos[index];
        return InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => onPhotoTap(index),
          child: Hero(
            tag: 'progress-${photo.id}',
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.network(photo.url, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      photo.dateLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MinimalMetricCard extends StatelessWidget {
  const MinimalMetricCard({super.key, required this.item});

  final ProfileStatItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 20, offset: const Offset(0, 8))],
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(item.label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          Text(
            item.unit == null ? item.value : '${item.value} ${item.unit}',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class ProfilePRCard extends StatelessWidget {
  const ProfilePRCard({super.key, required this.item});

  final ProfilePRItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: AppColors.accentSecondary.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(item.icon, color: AppColors.accentSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.exercise, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text(item.detail, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Text(item.value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
