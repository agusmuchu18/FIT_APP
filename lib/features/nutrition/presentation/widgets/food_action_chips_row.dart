import 'package:flutter/material.dart';

class FoodActionChipsRow extends StatelessWidget {
  const FoodActionChipsRow({
    super.key,
    required this.draftCount,
    required this.onDraftTap,
    required this.onTemplatesTap,
    required this.onCopyLastTap,
    required this.onCreateTap,
  });

  final int draftCount;
  final VoidCallback onDraftTap;
  final VoidCallback onTemplatesTap;
  final VoidCallback onCopyLastTap;
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ActionChip(label: Text('Borrador ($draftCount)'), onPressed: onDraftTap),
          const SizedBox(width: 8),
          ActionChip(label: const Text('Plantillas'), onPressed: onTemplatesTap),
          const SizedBox(width: 8),
          ActionChip(label: const Text('Copiar último'), onPressed: onCopyLastTap),
          const SizedBox(width: 8),
          ActionChip(label: const Text('Crear alimento'), onPressed: onCreateTap),
        ],
      ),
    );
  }
}
