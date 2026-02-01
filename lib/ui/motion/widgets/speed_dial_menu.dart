import 'package:flutter/material.dart';

import '../../../features/common/theme/app_colors.dart';
import '../controllers/motion_durations.dart';
import '../motion_config.dart';
import '../utils/stagger.dart';

class SpeedDialMenu extends StatefulWidget {
  const SpeedDialMenu({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.onWorkout,
    required this.onMeal,
    required this.onSleep,
    required this.bottomOffset,
  });

  final bool isOpen;
  final VoidCallback onClose;
  final VoidCallback onWorkout;
  final VoidCallback onMeal;
  final VoidCallback onSleep;
  final double bottomOffset;

  @override
  State<SpeedDialMenu> createState() => _SpeedDialMenuState();
}

class _SpeedDialMenuState extends State<SpeedDialMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: MotionDurations.menu,
  );

  @override
  void initState() {
    super.initState();
    if (widget.isOpen) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant SpeedDialMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildMenuItem({
    required int index,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final interval = staggerInterval(index, start: 0.0, end: 0.6, step: 0.1);
    final curved = CurvedAnimation(
      parent: _controller,
      curve: interval,
      reverseCurve: interval,
    );
    final entrance = CurvedAnimation(
      parent: curved,
      curve: MotionConfig.entrance,
      reverseCurve: MotionConfig.exit,
    );

    final opacity = Tween<double>(begin: 0, end: 1).animate(entrance);
    final offset = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(entrance);
    final scale = Tween<double>(begin: 0.98, end: 1.0).animate(entrance);

    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(
        position: offset,
        child: ScaleTransition(
          scale: scale,
          child: GestureDetector(
            onTap: () {
              widget.onClose();
              onTap();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: AppColors.accentSecondary, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.value == 0) {
          return const SizedBox.shrink();
        }
        return Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: widget.onClose,
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: widget.bottomOffset,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMenuItem(
                        index: 0,
                        label: 'Registrar Entrenamiento',
                        icon: Icons.fitness_center_rounded,
                        onTap: widget.onWorkout,
                      ),
                      const SizedBox(height: 10),
                      _buildMenuItem(
                        index: 1,
                        label: 'Registrar Comida',
                        icon: Icons.restaurant_rounded,
                        onTap: widget.onMeal,
                      ),
                      const SizedBox(height: 10),
                      _buildMenuItem(
                        index: 2,
                        label: 'Registrar Sueño',
                        icon: Icons.nightlight_round,
                        onTap: widget.onSleep,
                      ),
                    ],
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
