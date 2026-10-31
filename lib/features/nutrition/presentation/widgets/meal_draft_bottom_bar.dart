import 'package:flutter/material.dart';

import '../../../common/theme/app_colors.dart';
import '../../domain/models.dart';

class MealDraftBottomBar extends StatelessWidget {
  const MealDraftBottomBar({
    super.key,
    required this.draft,
    required this.bump,
    required this.onTap,
  });

  final MealDraft draft;
  final bool bump;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final totals = draft.totals;
    return AnimatedScale(
      scale: bump && !MediaQuery.disableAnimationsOf(context) ? 1.04 : 1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              draft.itemCount == 0
                  ? 'Seleccioná un alimento para empezar'
                  : '${draft.itemCount} alimentos · ${MacroValues.display(totals.kcal, decimals: 0)} kcal · ${MacroValues.display(totals.protein, decimals: 0)} g proteína',
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: draft.itemCount == 0 ? null : onTap,
              child: const Text('Revisar y registrar'),
            ),
          ],
        ),
      ),
    );
  }
}
