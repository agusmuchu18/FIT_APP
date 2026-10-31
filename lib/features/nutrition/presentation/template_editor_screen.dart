import 'package:flutter/material.dart';

import 'nutrition_editor_screens.dart';

/// Retains the existing named route and uses the canonical ingredient editor.
class TemplateEditorScreen extends StatelessWidget {
  const TemplateEditorScreen({super.key});
  @override
  Widget build(BuildContext context) => const NutritionRecipeEditor();
}
