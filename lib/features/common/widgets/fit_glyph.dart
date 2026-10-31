import 'package:flutter/material.dart';

/// A compact, scalable icon family shared by the main navigation and modules.
enum FitGlyphKind {
  home,
  habits,
  community,
  profile,
  workout,
  routine,
  discover,
  history,
  settings,
  nutrition,
  sleep,
  arrowForward,
  add,
  check,
  search,
  chevronDown,
}

class FitGlyph extends StatelessWidget {
  const FitGlyph({super.key, required this.kind, this.size = 24, this.color});

  final FitGlyphKind kind;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _FitGlyphPainter(
          kind: kind,
          color:
              color ??
              IconTheme.of(context).color ??
              Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _FitGlyphPainter extends CustomPainter {
  const _FitGlyphPainter({required this.kind, required this.color});

  final FitGlyphKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final solid = Paint()..color = color;

    void stroke(List<Offset> points) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, line);
    }

    void dot(double x, double y, double radius) {
      canvas.drawCircle(Offset(x, y), radius, solid);
    }

    switch (kind) {
      case FitGlyphKind.home:
        stroke(const [Offset(3, 10), Offset(12, 3), Offset(21, 10)]);
        stroke(const [
          Offset(5, 9),
          Offset(5, 21),
          Offset(19, 21),
          Offset(19, 9),
        ]);
        stroke(const [
          Offset(10, 21),
          Offset(10, 15),
          Offset(14, 15),
          Offset(14, 21),
        ]);
      case FitGlyphKind.habits:
        canvas.drawCircle(const Offset(12, 12), 9, line);
        stroke(const [Offset(7.5, 12), Offset(10.5, 15), Offset(16.8, 8.7)]);
        dot(19.3, 4.5, 1.4);
      case FitGlyphKind.community:
        canvas.drawCircle(const Offset(8, 8), 2.8, line);
        canvas.drawCircle(const Offset(16.5, 9), 2.4, line);
        final shoulders = Path()
          ..moveTo(2.5, 19.5)
          ..cubicTo(2.5, 13, 13.5, 13, 13.5, 19.5)
          ..moveTo(14.5, 14.5)
          ..cubicTo(18.5, 13.2, 21.5, 15.5, 21.5, 19.5);
        canvas.drawPath(shoulders, line);
      case FitGlyphKind.profile:
        canvas.drawCircle(const Offset(12, 7.5), 3.5, line);
        final body = Path()
          ..moveTo(4.5, 20.5)
          ..cubicTo(4.5, 13.5, 19.5, 13.5, 19.5, 20.5);
        canvas.drawPath(body, line);
        stroke(const [Offset(8, 20.5), Offset(16, 20.5)]);
      case FitGlyphKind.workout:
        stroke(const [Offset(2, 12), Offset(22, 12)]);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4, 6, 3.5, 12),
            const Radius.circular(1),
          ),
          line,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(16.5, 6, 3.5, 12),
            const Radius.circular(1),
          ),
          line,
        );
        stroke(const [Offset(2, 9), Offset(2, 15)]);
        stroke(const [Offset(22, 9), Offset(22, 15)]);
      case FitGlyphKind.routine:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4, 2.5, 16, 19),
            const Radius.circular(3),
          ),
          line,
        );
        for (final y in [8.0, 12.5, 17.0]) {
          dot(8, y, 0.9);
          stroke([Offset(11, y), Offset(17, y)]);
        }
      case FitGlyphKind.discover:
        canvas.drawCircle(const Offset(12, 12), 9, line);
        stroke(const [
          Offset(15.5, 8.5),
          Offset(13.5, 13.5),
          Offset(8.5, 15.5),
          Offset(10.5, 10.5),
          Offset(15.5, 8.5),
        ]);
        dot(12, 12, 1);
      case FitGlyphKind.history:
        canvas.drawArc(
          const Rect.fromLTWH(3, 3, 18, 18),
          -1.7,
          5.15,
          false,
          line,
        );
        stroke(const [Offset(2.6, 5.3), Offset(3.4, 9.4), Offset(7.5, 8.5)]);
        stroke(const [Offset(12, 7), Offset(12, 12), Offset(16, 14)]);
      case FitGlyphKind.settings:
        stroke(const [Offset(3, 6), Offset(6, 6)]);
        stroke(const [Offset(10, 6), Offset(21, 6)]);
        stroke(const [Offset(3, 12), Offset(14, 12)]);
        stroke(const [Offset(18, 12), Offset(21, 12)]);
        stroke(const [Offset(3, 18), Offset(8, 18)]);
        stroke(const [Offset(12, 18), Offset(21, 18)]);
        for (final center in [
          const Offset(8, 6),
          const Offset(16, 12),
          const Offset(10, 18),
        ]) {
          canvas.drawCircle(center, 2, line);
        }
      case FitGlyphKind.nutrition:
        canvas.drawCircle(const Offset(12, 12), 6.5, line);
        canvas.drawCircle(const Offset(12, 12), 3.5, line);
        stroke(const [Offset(2.5, 4), Offset(2.5, 20)]);
        stroke(const [Offset(20.5, 4), Offset(20.5, 20)]);
        stroke(const [Offset(18.5, 4), Offset(22.5, 4)]);
      case FitGlyphKind.sleep:
        final crescent = Path()
          ..moveTo(17.2, 3.5)
          ..cubicTo(8.4, 4.4, 7.7, 16.2, 16.6, 18.5)
          ..cubicTo(6, 23, 0.5, 11, 7.6, 4.9)
          ..cubicTo(10.4, 2.5, 13.5, 2, 17.2, 3.5);
        canvas.drawPath(crescent, line);
        dot(19.5, 8.5, 1.1);
      case FitGlyphKind.arrowForward:
        stroke(const [Offset(3, 12), Offset(20, 12)]);
        stroke(const [Offset(13, 5), Offset(20, 12), Offset(13, 19)]);
      case FitGlyphKind.add:
        stroke(const [Offset(12, 4), Offset(12, 20)]);
        stroke(const [Offset(4, 12), Offset(20, 12)]);
      case FitGlyphKind.check:
        stroke(const [Offset(4, 12), Offset(9, 17), Offset(20, 6)]);
      case FitGlyphKind.search:
        canvas.drawCircle(const Offset(10.5, 10.5), 6.5, line);
        stroke(const [Offset(15.5, 15.5), Offset(21, 21)]);
      case FitGlyphKind.chevronDown:
        stroke(const [Offset(5, 9), Offset(12, 16), Offset(19, 9)]);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FitGlyphPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}
