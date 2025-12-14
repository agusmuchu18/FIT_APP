import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'food_search_controller.dart';

class FoodSearchPage extends StatelessWidget {
  const FoodSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<FoodSearchController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Buscar alimentos (USDA)')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar (ej: apple, chicken breast)',
                border: OutlineInputBorder(),
              ),
              onChanged: context.read<FoodSearchController>().onQueryChanged,
            ),
            const SizedBox(height: 12),
            if (c.isLoading) const LinearProgressIndicator(),
            if (c.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  c.error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: c.results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final item = c.results[i];
                  return ListTile(
                    title: Text(item.description),
                    subtitle: Text([
                      if (item.dataType != null) item.dataType!,
                      if (item.brandOwner != null) item.brandOwner!,
                      'FDC: ${item.fdcId}',
                    ].join(' • ')),
                    onTap: () async {
                      // IMPORTANTE: details solo cuando toca (liviano)
                      final json = await context
                          .read<FoodSearchController>()
                          .getDetails(item.fdcId);

                      if (!context.mounted) return;

                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FoodDetailsPage(detailsJson: json),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FoodDetailsPage extends StatelessWidget {
  const FoodDetailsPage({super.key, required this.detailsJson});

  final Map<String, dynamic> detailsJson;

  @override
  Widget build(BuildContext context) {
    final name = (detailsJson['description'] ?? detailsJson['dataType'] ?? 'Detalle')
        .toString();

    final nutrients = (detailsJson['foodNutrients'] as List?) ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: nutrients.length,
        itemBuilder: (_, i) {
          final n = nutrients[i] as Map<String, dynamic>;
          final amount = n['amount'];
          final nutrient = (n['nutrient'] as Map<String, dynamic>?) ?? const {};
          final number = nutrient['number']?.toString() ?? '';
          final nName = nutrient['name']?.toString() ?? 'Nutrient';
          final unit = nutrient['unitName']?.toString() ?? '';
          return ListTile(
            title: Text('$nName ($number)'),
            trailing: Text('${amount ?? '-'} $unit'),
          );
        },
      ),
    );
  }
}
