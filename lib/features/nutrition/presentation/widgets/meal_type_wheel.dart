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

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.36, initialPage: MealType.values.indexOf(widget.selected));
  }

  @override
  void didUpdateWidget(covariant MealTypeWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _controller.animateToPage(MealType.values.indexOf(widget.selected), duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: PageView.builder(
        controller: _controller,
        itemCount: MealType.values.length,
        onPageChanged: (i) => widget.onChanged(MealType.values[i]),
        itemBuilder: (context, index) {
          final type = MealType.values[index];
          final selected = type == widget.selected;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? AppColors.accentFood.withOpacity(0.25) : AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: selected ? AppColors.accentFood : AppColors.border),
            ),
            alignment: Alignment.center,
            child: Text(
              mealTypeLabel(type),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: selected ? AppColors.textPrimary : AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          );
        },
      ),
    );
  }
}
