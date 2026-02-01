import 'package:flutter/material.dart';

import '../controllers/motion_durations.dart';
import '../motion_config.dart';

class AnimatedPlusXButton extends StatefulWidget {
  const AnimatedPlusXButton({
    super.key,
    required this.isOpen,
    required this.onTap,
    this.size = 54,
    this.color = const Color(0xFFF59E0B),
    this.iconColor = Colors.black,
  });

  final bool isOpen;
  final VoidCallback onTap;
  final double size;
  final Color color;
  final Color iconColor;

  @override
  State<AnimatedPlusXButton> createState() => _AnimatedPlusXButtonState();
}

class _AnimatedPlusXButtonState extends State<AnimatedPlusXButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: MotionDurations.micro,
  );

  late final Animation<double> _rotation = Tween<double>(
    begin: 0,
    end: 0.125,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: MotionConfig.entrance,
      reverseCurve: MotionConfig.exit,
    ),
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.0, end: 1.06),
      weight: 55,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.06, end: 1.0),
      weight: 45,
    ),
  ]).animate(
    CurvedAnimation(
      parent: _controller,
      curve: MotionConfig.pop,
      reverseCurve: MotionConfig.exit,
    ),
  );

  @override
  void didUpdateWidget(covariant AnimatedPlusXButton oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotation.value * 2 * 3.1415926535897932,
            child: Transform.scale(
              scale: _scale.value,
              child: child,
            ),
          );
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(Icons.add_rounded, color: widget.iconColor, size: 30),
        ),
      ),
    );
  }
}
