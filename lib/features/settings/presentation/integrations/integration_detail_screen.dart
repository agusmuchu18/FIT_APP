import 'package:flutter/material.dart';

import 'integration_models.dart';

class IntegrationDetailScreen extends StatelessWidget {
  const IntegrationDetailScreen({
    super.key,
    required this.item,
    required this.status,
    required this.onConnect,
    required this.onDisconnect,
  });

  final IntegrationItem item;
  final IntegrationStatus status;
  final Future<void> Function() onConnect;
  final Future<void> Function() onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(item.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.25),
              ),
              child: Row(
                children: [
                  Icon(item.iconData, size: 34),
                  const SizedBox(width: 12),
                  Expanded(child: Text(item.description)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Datos que puede importar', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...item.importableData.map(
              (datum) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(datum)),
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (item.isAvailable)
              SizedBox(
                width: double.infinity,
                child: status.connected
                    ? OutlinedButton.icon(
                        onPressed: () async {
                          await onDisconnect();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.link_off_rounded),
                        label: const Text('Desconectar'),
                      )
                    : FilledButton.icon(
                        onPressed: () async {
                          await onConnect();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.link_rounded),
                        label: const Text('Conectar'),
                      ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.schedule_rounded),
                  label: const Text('Próximamente'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
