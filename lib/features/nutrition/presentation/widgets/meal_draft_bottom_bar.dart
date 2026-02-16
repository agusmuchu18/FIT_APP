import 'package:flutter/material.dart';

import '../../../common/theme/app_colors.dart';
import '../../domain/models.dart';

class MealDraftBottomBar extends StatelessWidget {
  const MealDraftBottomBar({super.key, required this.draft, required this.bump, required this.onTap});

  final MealDraft draft;
  final bool bump;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final totals = draft.totals;
    return AnimatedScale(
      scale: bump ? 1.04 : 1,
      duration: const Duration(milliseconds: 180),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Expanded(child: Text('${draft.itemCount} items · ${totals.kcal.round()} kcal · ${totals.protein.round()} P', maxLines: 1, overflow: TextOverflow.ellipsis)),
          FilledButton(onPressed: onTap, child: const Text('Ver / Editar')),
        ]),
      ),
    );
  }
}
