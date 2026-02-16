import 'package:flutter/material.dart';

class PaywallSheet extends StatelessWidget {
  const PaywallSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(context: context, builder: (_) => const PaywallSheet());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('FIT PRO', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text('• Cálculo por gramos\n• Más precisión\n• Insights avanzados'),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: () {/* TODO purchase callback */}, child: const Text('Ver planes'))),
      ]),
    );
  }
}
