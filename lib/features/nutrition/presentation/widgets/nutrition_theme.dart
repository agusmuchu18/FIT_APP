import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

class NutritionTheme extends StatelessWidget {
  const NutritionTheme({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Theme(data: AppTheme.workoutFor(Theme.of(context)), child: child);
}
