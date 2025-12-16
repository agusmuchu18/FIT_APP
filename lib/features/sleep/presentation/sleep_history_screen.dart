import 'package:flutter/material.dart';

import '../../../core/data/repositories.dart';
import '../../../core/domain/entities.dart';
import '../../../main.dart';
import '../../common/theme/app_colors.dart';
import '../../common/widgets/summary_card.dart';

class SleepHistoryScreen extends StatefulWidget {
  const SleepHistoryScreen({super.key});

  @override
  State<SleepHistoryScreen> createState() => _SleepHistoryScreenState();
}

class _SleepHistoryScreenState extends State<SleepHistoryScreen> {
  FitnessRepository? _repo;
  Future<List<SleepEntry>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ Acá sí se puede leer InheritedWidgets (RepositoryScope).
    _repo ??= RepositoryScope.of(context);
    _future ??= _repo!.getSleep();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _repo!.getSleep();
    });
  }

  DateTime _dateFor(SleepEntry e) =>
      DateTime.tryParse(e.id)?.toLocal() ?? e.meta.updatedAt.toLocal();

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  String _fmtTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '--:--';
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Historial de Sueño'),
      ),
      body: SafeArea(
        child: FutureBuilder<List<SleepEntry>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }

            final raw = snapshot.data ?? const <SleepEntry>[];
            final entries = raw.where((e) => !e.deleted).toList()
              ..sort((a, b) => _dateFor(b).compareTo(_dateFor(a)));

            if (entries.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SummaryCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.nightlight_round,
                            color: AppColors.textSecondary, size: 36),
                        const SizedBox(height: 10),
                        const Text(
                          'Todavía no hay registros',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Registrá una noche para ver tu historial acá.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/sleep/lite'),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Registrar (Lite)'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return RefreshIndicator.adaptive(
              onRefresh: _reload,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final e = entries[i];
                  final date = _dateFor(e);

                  return Dismissible(
                    key: ValueKey(e.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: const Color(0x33FF6A6A),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFFF6A6A)),
                    ),
                    confirmDismiss: (_) async {
                      return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Eliminar registro'),
                              content: const Text(
                                  'Se ocultará del historial (y se sincronizará si corresponde).'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                    },
                    onDismissed: (_) async {
                      final repo = _repo!;
                      await repo.saveSleep(e.markDeleted(), sync: true);
                      await _reload();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Registro eliminado')),
                      );
                    },
                    child: SummaryCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _fmtDate(date),
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  e.hours.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Text(
                                  'h',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
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
                                  e.quality.isEmpty ? '—' : e.quality,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.bedtime_rounded,
                                        size: 16,
                                        color: AppColors.textSecondary),
                                    const SizedBox(width: 6),
                                    Text(
                                      _fmtTime(e.bedtime),
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.wb_sunny_rounded,
                                        size: 16,
                                        color: AppColors.textSecondary),
                                    const SizedBox(width: 6),
                                    Text(
                                      _fmtTime(e.wakeTime),
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
