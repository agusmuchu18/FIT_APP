import 'dart:math' as math;

import 'package:flutter/material.dart';

Interval staggerInterval(int index, {double start = 0.0, double end = 0.6, double step = 0.1}) {
  final begin = (start + index * step).clamp(0.0, 1.0);
  final finish = (end + index * step).clamp(0.0, 1.0);
  return Interval(
    math.min(begin, finish),
    math.max(begin, finish),
  );
}
