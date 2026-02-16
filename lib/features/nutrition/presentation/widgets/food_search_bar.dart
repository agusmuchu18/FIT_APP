import 'package:flutter/material.dart';

class FoodSearchBar extends StatelessWidget {
  const FoodSearchBar({super.key, required this.controller, required this.onChanged, required this.onClear});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Buscar alimentos o comidas…',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isNotEmpty ? IconButton(onPressed: onClear, icon: const Icon(Icons.close)) : null,
      ),
    );
  }
}
