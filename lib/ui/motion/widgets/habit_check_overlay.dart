import 'package:flutter/material.dart';

import '../controllers/motion_durations.dart';
import '../motion_config.dart';
import 'animated_check_painter.dart';

class HabitCheckOverlay extends StatefulWidget {
  const HabitCheckOverlay({
    super.key,
    this.size = 34,
    this.color = const Color(0xFF19C37D),
    this.strokeWidth = 3,
    this.holdDuration = MotionDurations.checkHold,
  });

  final double size;
  final Color color;
  final double strokeWidth;
  final Duration holdDuration;

  @override
  State<HabitCheckOverlay> createState() => HabitCheckOverlayState();
}

class HabitCheckOverlayState extends State<HabitCheckOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: MotionDurations.check,
  );

  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: MotionConfig.entrance,
    reverseCurve: MotionConfig.exit,
  );

  late final Animation<double> _opacity = Tween<double>(
    begin: 0,
    end: 1,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: MotionConfig.entrance,
      reverseCurve: MotionConfig.exit,
    ),
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 0.9,
    end: 1.0,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: MotionConfig.pop,
      reverseCurve: MotionConfig.exit,
    ),
  );

  Future<void> play() async {
    if (!mounted) return;
    _controller
      ..stop()
      ..reset();
    await _controller.forward();
    if (!mounted) return;
    await Future.delayed(widget.holdDuration);
    if (mounted) {
      await _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FadeTransition(
        opacity: _opacity,
        child: ScaleTransition(
          scale: _scale,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: AnimatedCheckPainter(
              progress: _progress,
              color: widget.color,
              strokeWidth: widget.strokeWidth,
            ),
          ),
        ),
      ),
    );
  }
}
