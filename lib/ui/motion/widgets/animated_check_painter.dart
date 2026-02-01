import 'package:flutter/material.dart';

class AnimatedCheckPainter extends CustomPainter {
  AnimatedCheckPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 3,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final start = Offset(size.width * 0.18, size.height * 0.52);
    final mid = Offset(size.width * 0.42, size.height * 0.72);
    final end = Offset(size.width * 0.82, size.height * 0.32);

    final value = progress.value.clamp(0.0, 1.0);
    final firstPhase = (value * 2).clamp(0.0, 1.0);
    final secondPhase = ((value - 0.5) * 2).clamp(0.0, 1.0);

    final path = Path();
    if (value <= 0.5) {
      final current = Offset.lerp(start, mid, firstPhase)!;
      path.moveTo(start.dx, start.dy);
      path.lineTo(current.dx, current.dy);
    } else {
      final current = Offset.lerp(mid, end, secondPhase)!;
      path.moveTo(start.dx, start.dy);
      path.lineTo(mid.dx, mid.dy);
      path.lineTo(current.dx, current.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant AnimatedCheckPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
