import 'package:flutter/material.dart';

import '../integration_models.dart';
import '../integration_readiness.dart';

class IntegrationTile extends StatelessWidget {
  const IntegrationTile({
    super.key,
    required this.item,
    required this.status,
    required this.onTap,
    required this.onConnect,
  });

  final IntegrationItem item;
  final IntegrationStatus status;
  final VoidCallback onTap;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final connected = status.connected;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(item.iconData),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildStatusAction(context, connected),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusAction(BuildContext context, bool connected) {
    if (!IntegrationReadiness.canConnect(item.id)) {
      return Text(
        IntegrationReadiness.label(item.id),
        style: Theme.of(context).textTheme.labelLarge,
      );
    }

    if (connected) {
      return Chip(
        avatar: const Icon(Icons.check, size: 16),
        label: const Text('Conectado'),
        backgroundColor: Colors.green.withOpacity(0.18),
      );
    }

    return FilledButton.tonal(
      onPressed: onConnect,
      style: FilledButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: const Text('Conectar'),
    );
  }
}
