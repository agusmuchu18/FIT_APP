import 'package:flutter/material.dart';

import '../../../core/domain/entities.dart';
import '../../../main.dart';
import '../../common/theme/app_colors.dart';
import '../../common/widgets/summary_card.dart';
import '../domain/sleep_time_utils.dart';

class SleepHistoryScreen extends StatefulWidget {
  const SleepHistoryScreen({super.key});

  @override
  State<SleepHistoryScreen> createState() => _SleepHistoryScreenState();
}

class _SleepHistoryScreenState extends State<SleepHistoryScreen> {
  late Future<List<SleepEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = RepositoryScope.of(context).getSleep();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = RepositoryScope.of(context).getSleep();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Historial de sueño'),
      ),
      body: FutureBuilder<List<SleepEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          final entries = (snapshot.data ?? [])
              .where((e) => !e.deleted)
              .toList()
            ..sort((a, b) => sleepEntryDate(b).compareTo(sleepEntryDate(a)));

          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hotel_class, size: 48, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    const Text(
                      'Todavía no hay registros…',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Registra tu primera noche para ver el historial.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.pushNamed(context, '/sleep/lite'),
                      child: const Text('Registrar ahora'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Dismissible(
                    key: ValueKey(entry.id),
                    background: Container(
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.redAccent),
                    ),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) async {
                      return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Eliminar registro'),
                              content: const Text('¿Seguro que quieres eliminar este registro?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                    },
                    onDismissed: (_) => _deleteEntry(entry),
                    child: _HistoryRow(entry: entry, onTap: () => _showDetails(entry)),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteEntry(SleepEntry entry) async {
    final repository = RepositoryScope.of(context);
    await repository.saveSleep(entry.markDeleted(), sync: true);
    _refresh();
  }

  void _showDetails(SleepEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final date = sleepEntryDate(entry);
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${date.day}/${date.month}/${date.year}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Chip(
                    label: Text(entry.quality),
                    backgroundColor: AppColors.surface,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('${entry.hours.toStringAsFixed(1)} h'),
              const SizedBox(height: 4),
              Text('${entry.bedtime ?? '--'} → ${entry.wakeTime ?? '--'}'),
              if (entry.tags != null && entry.tags!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: entry.tags!
                      .map((t) => Chip(
                            label: Text(t),
                            backgroundColor: AppColors.surface,
                          ))
                      .toList(),
                ),
              ],
              if ((entry.notes ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(entry.notes!, style: const TextStyle(color: AppColors.textMuted)),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: const Text('Cerrar'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.onTap});

  final SleepEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = sleepEntryDate(entry);
    return GestureDetector(
      onTap: onTap,
      child: SummaryCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    _weekdayLabel(date),
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  Text(
                    date.day.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.hours.toStringAsFixed(1)} h · ${entry.quality}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.bedtime ?? '--'} → ${entry.wakeTime ?? '--'}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

String _weekdayLabel(DateTime date) {
  const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  return labels[date.weekday - 1];
}
