/// Flutter counterparts of docs/design/DESIGN_SYSTEM.md (p.space / s.shape).
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class AppShape {
  static const small = 8.0;
  static const control = 12.0;
  static const card = 16.0;
  static const overlay = 24.0;
}

/// Existing Design System roles, shared by charts and decorative media.
abstract final class AppVisual {
  static const chartAreaOpacity = .12;
  static const scrimOpacity = .64;
  static const motionNormal = Duration(milliseconds: 200);
}
