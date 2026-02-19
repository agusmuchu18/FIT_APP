import 'dart:math' as math;

import 'package:flutter/material.dart';

class RadarChartPainter extends CustomPainter {
  RadarChartPainter({
    required this.labels,
    required this.currentValues,
    this.previousValues,
    required this.accentColor,
  });

  final List<String> labels;
  final List<double> currentValues;
  final List<double>? previousValues;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty || currentValues.length != labels.length) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    if (radius <= 0) return;

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withOpacity(0.12);

    for (var ring = 1; ring <= 4; ring++) {
      final factor = ring / 4;
      final path = _polygonPath(center, radius * factor, List<double>.filled(labels.length, 1));
      canvas.drawPath(path, gridPaint);
    }

    final axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withOpacity(0.16);

    for (var i = 0; i < labels.length; i++) {
      final point = _pointAt(center, radius, i, labels.length, 1);
      canvas.drawLine(center, point, axisPaint);
    }

    if (previousValues != null && previousValues!.length == labels.length) {
      final previousPath = _polygonPath(center, radius, previousValues!);
      canvas.drawPath(
        previousPath,
        Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.white.withOpacity(0.07),
      );
      canvas.drawPath(
        previousPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withOpacity(0.28),
      );
    }

    final currentPath = _polygonPath(center, radius, currentValues);
    canvas.drawPath(
      currentPath,
      Paint()
        ..style = PaintingStyle.fill
        ..color = accentColor.withOpacity(0.26),
    );
    canvas.drawPath(
      currentPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accentColor.withOpacity(0.95),
    );
  }

  Path _polygonPath(Offset center, double radius, List<double> values) {
    final path = Path();
    for (var i = 0; i < labels.length; i++) {
      final point = _pointAt(center, radius, i, labels.length, values[i].clamp(0, 1).toDouble());
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  Offset _pointAt(Offset center, double radius, int index, int total, double value) {
    final angle = -math.pi / 2 + (2 * math.pi * index / total);
    return Offset(
      center.dx + math.cos(angle) * radius * value,
      center.dy + math.sin(angle) * radius * value,
    );
  }

  @override
  bool shouldRepaint(covariant RadarChartPainter oldDelegate) {
    return oldDelegate.currentValues != currentValues || oldDelegate.previousValues != previousValues || oldDelegate.accentColor != accentColor;
  }
}
