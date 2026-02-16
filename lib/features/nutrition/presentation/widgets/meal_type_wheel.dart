import 'package:flutter/material.dart';

import '../../../common/theme/app_colors.dart';
import '../../domain/models.dart';

class MealTypeWheel extends StatefulWidget {
  const MealTypeWheel({super.key, required this.selected, required this.onChanged});

  final MealType selected;
  final ValueChanged<MealType> onChanged;

  @override
  State<MealTypeWheel> createState() => _MealTypeWheelState();
}

class _MealTypeWheelState extends State<MealTypeWheel> {
  late final PageController _controller;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _page = MealType.values.indexOf(widget.selected).toDouble();
    _controller = PageController(initialPage: _page.toInt(), viewportFraction: 0.36)
      ..addListener(() {
        setState(() {
          _page = _controller.page ?? _page;
        });
      });
  }

  @override
  void didUpdateWidget(covariant MealTypeWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      final target = MealType.values.indexOf(widget.selected);
      if ((_page - target).abs() > 0.01) {
        _controller.animateToPage(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
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
    return SizedBox(
      height: 52,
      child: PageView.builder(
        controller: _controller,
        itemCount: MealType.values.length,
        onPageChanged: (index) => widget.onChanged(MealType.values[index]),
        itemBuilder: (context, index) {
          final type = MealType.values[index];
          final delta = (_page - index).abs().clamp(0.0, 1.0);
          final selected = delta < 0.2;
          final scale = 1 - (delta * 0.18);
          final opacity = 1 - (delta * 0.45);

          return Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: selected ? AppColors.accentFood : AppColors.border),
                    color: selected ? AppColors.accentFood.withOpacity(0.25) : Colors.transparent,
                  ),
                  child: Text(
                    mealTypeLabel(type),
                    style: TextStyle(
                      color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
