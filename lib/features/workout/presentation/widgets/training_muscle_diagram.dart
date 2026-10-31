import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/workout_analytics.dart';

/// Schematic vector map. Broad catalogue groups remain broad; color represents
/// recorded direct sets, never activation, fatigue or predicted recovery.
class TrainingMuscleDiagram extends StatelessWidget {
  const TrainingMuscleDiagram({
    super.key,
    required this.muscles,
    required this.onSelected,
  });
  final Map<TrainingMuscle, MuscleTrainingSummary> muscles;
  final ValueChanged<TrainingMuscle> onSelected;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.center,
        children: [
          for (final back in [false, true])
            Column(
              children: [
                Text(back ? 'Vista posterior' : 'Vista anterior'),
                Semantics(
                  label:
                      'Mapa muscular esquemático ${back ? 'posterior' : 'anterior'}. Los mismos datos están en la lista accesible inferior.',
                  image: true,
                  child: GestureDetector(
                    onTapUp: (event) {
                      final point = Offset(
                        event.localPosition.dx / 160,
                        event.localPosition.dy / 320,
                      );
                      for (final region in _regions(back).entries) {
                        if (region.value.any((p) => p.contains(point))) {
                          onSelected(region.key);
                          break;
                        }
                      }
                    },
                    child: CustomPaint(
                      size: const Size(160, 320),
                      painter: _MusclePainter(
                        back,
                        muscles,
                        Theme.of(context).colorScheme,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      const SizedBox(height: 12),
      const Text(
        'Color: series directas confirmadas, en escala relativa al período. Esquema por grupos del catálogo; no representa activación, hipertrofia, fatiga ni recuperación.',
      ),
    ],
  );
}

Path _shape(List<(double, double)> points) {
  final path = Path();
  for (var i = 0; i < points.length; i++) {
    final current = Offset(points[i].$1, points[i].$2),
        before = Offset(
          points[(i + points.length - 1) % points.length].$1,
          points[(i + points.length - 1) % points.length].$2,
        ),
        after = Offset(
          points[(i + 1) % points.length].$1,
          points[(i + 1) % points.length].$2,
        );
    final enter = Offset.lerp(current, before, .16)!,
        leave = Offset.lerp(current, after, .16)!;
    if (i == 0) {
      path.moveTo(enter.dx, enter.dy);
    } else {
      path.lineTo(enter.dx, enter.dy);
    }
    path.quadraticBezierTo(current.dx, current.dy, leave.dx, leave.dy);
  }
  return path..close();
}

Map<TrainingMuscle, List<Path>> _regions(bool back) {
  Path rect(double left, double top, double width, double height) =>
      Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, width, height),
          const Radius.circular(.025),
        ),
      );
  return {
    TrainingMuscle.shoulders: [
      rect(.23, .16, .13, .08),
      rect(.64, .16, .13, .08),
    ],
    if (!back)
      TrainingMuscle.chest: [
        _shape([(.36, .18), (.49, .19), (.49, .28), (.36, .27)]),
        _shape([(.51, .19), (.64, .18), (.64, .27), (.51, .28)]),
      ],
    if (back)
      TrainingMuscle.back: [
        _shape([(.36, .24), (.49, .21), (.49, .38), (.42, .39)]),
        _shape([(.51, .21), (.64, .24), (.58, .39), (.51, .38)]),
      ],
    if (back)
      TrainingMuscle.trapezius: [
        _shape([(.41, .13), (.59, .13), (.63, .20), (.50, .25), (.37, .20)]),
      ],
    if (back) TrainingMuscle.lowerBack: [rect(.42, .39, .16, .08)],
    if (!back) TrainingMuscle.core: [rect(.43, .30, .14, .16)],
    if (!back)
      TrainingMuscle.obliques: [
        rect(.36, .30, .06, .15),
        rect(.58, .30, .06, .15),
      ],
    (back ? TrainingMuscle.triceps : TrainingMuscle.biceps): [
      rect(.22, .25, .10, .13),
      rect(.68, .25, .10, .13),
    ],
    TrainingMuscle.forearms: [
      rect(.18, .40, .09, .14),
      rect(.73, .40, .09, .14),
    ],
    if (back)
      TrainingMuscle.glutes: [
        rect(.35, .48, .14, .09),
        rect(.51, .48, .14, .09),
      ],
    (back ? TrainingMuscle.hamstrings : TrainingMuscle.quads): [
      rect(.34, .58, .13, .18),
      rect(.53, .58, .13, .18),
    ],
    if (!back)
      TrainingMuscle.adductors: [
        rect(.47, .54, .025, .15),
        rect(.505, .54, .025, .15),
      ],
    if (!back)
      TrainingMuscle.hipFlexors: [
        rect(.36, .48, .11, .07),
        rect(.53, .48, .11, .07),
      ],
    TrainingMuscle.calves: [rect(.35, .79, .10, .14), rect(.55, .79, .10, .14)],
  };
}

class _MusclePainter extends CustomPainter {
  _MusclePainter(this.back, this.muscles, this.scheme);
  final bool back;
  final Map<TrainingMuscle, MuscleTrainingSummary> muscles;
  final ColorScheme scheme;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width, size.height);
    final outline = Paint()
      ..color = scheme.outlineVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = .007;
    final skin = Paint()..color = scheme.surfaceContainerHighest;
    final body = _shape([
      (.42, .12),
      (.35, .16),
      (.23, .16),
      (.20, .26),
      (.18, .40),
      (.13, .55),
      (.24, .57),
      (.30, .37),
      (.34, .32),
      (.36, .46),
      (.32, .58),
      (.32, .77),
      (.33, .96),
      (.45, .96),
      (.49, .72),
      (.51, .72),
      (.55, .96),
      (.67, .96),
      (.68, .77),
      (.68, .58),
      (.64, .46),
      (.66, .32),
      (.70, .37),
      (.76, .57),
      (.87, .55),
      (.82, .40),
      (.80, .26),
      (.77, .16),
      (.65, .16),
      (.58, .12),
    ]);
    canvas.drawPath(body, skin);
    canvas.drawPath(body, outline);
    final head = Path()..addOval(const Rect.fromLTWH(.42, .01, .16, .11));
    canvas.drawPath(head, skin);
    canvas.drawPath(head, outline);
    final maxSets = math.max(
      1,
      muscles.values.fold<int>(0, (n, m) => math.max(n, m.directSets)),
    );
    for (final entry in _regions(back).entries) {
      final count = muscles[entry.key]?.directSets ?? 0;
      final paint = Paint()
        ..color = count == 0
            ? scheme.outlineVariant
            : Color.lerp(
                scheme.primaryContainer,
                scheme.primary,
                count / maxSets,
              )!;
      for (final path in entry.value) {
        canvas.drawPath(path, paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MusclePainter old) =>
      old.back != back || old.muscles != muscles || old.scheme != scheme;
}
