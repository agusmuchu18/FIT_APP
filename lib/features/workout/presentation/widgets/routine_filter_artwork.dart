import 'package:flutter/material.dart';

/// Small code-native illustrations: no network/decode work or missing bitmap.
/// Anatomical drawings are schematic regional highlights, not clinical diagrams.
class RoutineFilterArtwork extends StatelessWidget {
  const RoutineFilterArtwork({
    super.key,
    required this.value,
    required this.muscle,
    this.size = 40,
  });
  final String value;
  final bool muscle;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _FilterPainter(
            value,
            muscle,
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
    ),
  );
}

class _FilterPainter extends CustomPainter {
  const _FilterPainter(this.value, this.muscle, this.accent, this.surface);
  final String value;
  final bool muscle;
  final Color accent, surface;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    canvas.drawCircle(const Offset(50, 50), 50, Paint()..color = surface);
    canvas.drawCircle(
      const Offset(50, 50),
      46,
      Paint()
        ..shader = RadialGradient(
          colors: [accent.withValues(alpha: .18), surface],
          center: const Alignment(0, -.2),
        ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),
    );
    final ink = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = accent;
    void line(double x, double y, double x2, double y2) =>
        canvas.drawLine(Offset(x, y), Offset(x2, y2), ink);
    void rect(double x, double y, double w, double h) => canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        const Radius.circular(3),
      ),
      ink,
    );
    void oval(
      double x,
      double y,
      double w,
      double h, [
      bool highlighted = false,
    ]) => canvas.drawOval(Rect.fromLTWH(x, y, w, h), highlighted ? fill : ink);
    if (muscle || value == 'bodyweight') {
      final neutral = Paint()
        ..color = const Color(0xff91a6b9).withValues(alpha: .5);
      final body = Path()
        ..moveTo(44, 29)
        ..lineTo(56, 29)
        ..lineTo(64, 32)
        ..lineTo(72, 49)
        ..lineTo(77, 62)
        ..lineTo(72, 64)
        ..lineTo(62, 48)
        ..lineTo(60, 43)
        ..lineTo(60, 58)
        ..lineTo(58, 67)
        ..lineTo(63, 89)
        ..lineTo(55, 89)
        ..lineTo(50, 71)
        ..lineTo(45, 89)
        ..lineTo(37, 89)
        ..lineTo(42, 67)
        ..lineTo(40, 58)
        ..lineTo(40, 43)
        ..lineTo(38, 48)
        ..lineTo(28, 64)
        ..lineTo(23, 62)
        ..lineTo(28, 49)
        ..lineTo(36, 32)
        ..close();
      canvas.drawCircle(const Offset(50, 20), 8, neutral);
      canvas.drawPath(body, neutral);
      final v = value.toLowerCase();
      void pair(double x, double y, double w, double h) {
        oval(x, y, w, h, true);
        oval(100 - x - w, y, w, h, true);
      }

      if (v.contains('pecho')) {
        pair(
          40,
          v.contains('superior')
              ? 32
              : v.contains('inferior')
              ? 40
              : 33,
          9,
          v.contains('superior') || v.contains('inferior') ? 5 : 12,
        );
      } else if (v.contains('espalda') || v.contains('trapecio')) {
        pair(
          40,
          v.contains('baja') ? 49 : 32,
          9,
          v.contains('baja')
              ? 10
              : v.contains('alta') || v.contains('trapecio')
              ? 12
              : 22,
        );
      } else if (v.contains('hombro') ||
          v.contains('deltoide') ||
          v.contains('rotadores')) {
        pair(34, 32, 8, 9);
      } else if (v.contains('bíceps') || v.contains('tríceps')) {
        pair(30, 40, 7, 13);
      } else if (v.contains('antebrazo')) {
        pair(26, 51, 6, 12);
      } else if (v.contains('glúteo')) {
        pair(40, 58, 9, v.contains('medios') ? 6 : 10);
      } else if (v.contains('pantorrilla')) {
        pair(38, 77, 7, 11);
      } else if (v.contains('aductores')) {
        pair(44, 65, 5, 12);
      } else if (v.contains('flexores')) {
        pair(43, 57, 6, 8);
      } else if (v.contains('cuádriceps') ||
          v.contains('isquio') ||
          v == 'piernas') {
        pair(40, 65, 8, v == 'piernas' ? 23 : 13);
      } else if (v.contains('oblicuos')) {
        pair(40, 46, 5, 13);
      } else if (v == 'core' || v == 'abdominales') {
        oval(45, 46, 10, 13, true);
      } else if (v == 'bodyweight' ||
          v.contains('cuerpo') ||
          v.contains('full')) {
        canvas.drawPath(body, Paint()..color = accent.withValues(alpha: .65));
      } else {
        // Non-anatomical objectives get distinct symbols, never a fake muscle.
        final symbol = v == 'cardio'
            ? Icons.favorite_border
            : v == 'movilidad'
            ? Icons.open_with
            : v == 'estabilidad'
            ? Icons.balance
            : Icons.help_outline;
        final paragraph = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(symbol.codePoint),
            style: TextStyle(
              fontFamily: symbol.fontFamily,
              package: symbol.fontPackage,
              fontSize: 27,
              color: accent,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        canvas.drawCircle(const Offset(50, 52), 18, Paint()..color = surface);
        paragraph.paint(
          canvas,
          Offset(50 - paragraph.width / 2, 52 - paragraph.height / 2),
        );
      }
      // Back-facing regions have a center spine; front-facing ones a sternum.
      if (v.contains('espalda') ||
          v.contains('trapecio') ||
          v.contains('glúteo') ||
          v.contains('isquio') ||
          v.contains('posterior') ||
          v.contains('tríceps')) {
        canvas.drawLine(
          const Offset(50, 32),
          const Offset(50, 60),
          Paint()
            ..color = surface
            ..strokeWidth = 1.5,
        );
      }
      return;
    }
    switch (value) {
      case 'barbell':
      case 'dumbbell':
        line(15, 50, 85, 50);
        rect(21, 30, 10, 40);
        rect(69, 30, 10, 40);
        if (value == 'barbell') {
          rect(13, 36, 8, 28);
          rect(79, 36, 8, 28);
        }
      case 'kettlebell':
        oval(35, 20, 30, 27);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(28, 40, 44, 39),
            const Radius.circular(16),
          ),
          fill,
        );
      case 'medicine_ball':
        oval(22, 22, 56, 56);
        line(50, 24, 50, 76);
        canvas.drawArc(
          const Rect.fromLTWH(31, 22, 38, 56),
          -1.4,
          2.8,
          false,
          ink,
        );
      case 'rope':
        final path = Path()
          ..moveTo(24, 24)
          ..cubicTo(10, 80, 50, 82, 49, 39)
          ..cubicTo(48, 17, 92, 20, 74, 78);
        canvas.drawPath(path, ink..strokeWidth = 5);
        line(22, 18, 26, 29);
        line(72, 75, 76, 84);
      case 'sled':
        line(20, 76, 83, 76);
        line(22, 76, 15, 68);
        line(29, 69, 69, 69);
        line(32, 66, 32, 25);
        line(69, 66, 69, 25);
        oval(41, 56, 20, 7);
        oval(41, 61, 20, 7);
        line(51, 57, 51, 44);
      case 'cable':
        line(28, 80, 28, 22);
        line(28, 22, 67, 22);
        oval(61, 18, 12, 12);
        line(67, 30, 67, 52);
        line(58, 57, 76, 57);
        rect(20, 58, 18, 20);
        line(28, 34, 28, 56);
      case 'machine':
      case 'smith':
        line(23, 80, 23, 22);
        line(77, 80, 77, 22);
        line(23, 22, 77, 22);
        line(18, 80, 83, 80);
        rect(34, 50, 31, 8);
        line(50, 58, 50, 76);
        line(23, 35, 77, 35);
        oval(31, 29, 10, 12);
        oval(59, 29, 10, 12);
      case 'bench':
        rect(19, 43, 62, 10);
        line(29, 54, 25, 76);
        line(71, 54, 75, 76);
      case 'band':
        canvas.save();
        canvas.translate(50, 50);
        canvas.rotate(-.6);
        oval(-16, -32, 32, 64);
        oval(-10, -28, 20, 56);
        canvas.restore();
      case 'carry':
        rect(16, 48, 20, 22);
        rect(64, 48, 20, 22);
        line(23, 48, 23, 41);
        line(29, 48, 29, 41);
        line(71, 48, 71, 41);
        line(77, 48, 77, 41);
        line(40, 28, 60, 28);
        line(53, 22, 60, 28);
        line(53, 34, 60, 28);
      default:
        // Explicit consistent fallback for catalogue extensions.
        rect(30, 30, 40, 40);
        line(39, 50, 61, 50);
        line(50, 39, 50, 61);
    }
  }

  @override
  bool shouldRepaint(_FilterPainter oldDelegate) =>
      value != oldDelegate.value ||
      muscle != oldDelegate.muscle ||
      accent != oldDelegate.accent ||
      surface != oldDelegate.surface;
}
