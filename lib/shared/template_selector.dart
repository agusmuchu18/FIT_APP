import 'package:flutter/material.dart';

import '../features/common/theme/app_colors.dart';

class TemplateSelector extends StatelessWidget {
  const TemplateSelector({
    super.key,
    required this.templates,
    required this.onSelected,
    this.title = 'Plantillas',
    this.onDeleted,
  });

  final List<String> templates;
  final ValueChanged<String> onSelected;
  final String title;
  final ValueChanged<String>? onDeleted;

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: templates
              .map(
                (template) => InputChip(
                  label: Text(
                    template,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => onSelected(template),
                  onDeleted:
                      onDeleted == null ? null : () => onDeleted!(template),
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: Colors.transparent),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  deleteIconColor: AppColors.textMuted,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
