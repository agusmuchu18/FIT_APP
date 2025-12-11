import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/domain/entities.dart';
import '../../../main.dart';
import '../../common/theme/app_colors.dart';
import '../../common/widgets/summary_card.dart';

class SleepRegularityScreen extends StatelessWidget {
  const SleepRegularityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = RepositoryScope.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Regularidad del Sueño'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: FutureBuilder<List<SleepEntry>>(
            future: repository.getSleep(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator.adaptive(),
                );
              }

              final entries = snapshot.data ?? <SleepEntry>[];
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final lastWeekStart = today.subtract(const Duration(days: 6));
              final previousWeekStart = today.subtract(const Duration(days: 13));
              final previousWeekEnd = today.subtract(const Duration(days: 7));

              final currentRegularity = _regularityStdDev(
                lastWeekStart,
                today,
                entries,
              ).round();
              final previousRegularity = _regularityStdDev(
                previousWeekStart,
                previousWeekEnd,
                entries,
              ).round();
              final delta = (currentRegularity - previousRegularity).abs();
              final improved = currentRegularity <= previousRegularity;

              final recentEntries = entries
                  .where((entry) {
                    final date = _dateOnly(DateTime.tryParse(entry.id) ?? today);
                    return !date.isBefore(lastWeekStart) && !date.isAfter(today);
                  })
                  .toList()
                ..sort((a, b) => b.id.compareTo(a.id));

              return ListView(
                children: [
                  SummaryCard(
                    minHeight: 170,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Variabilidad semanal',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$currentRegularity min',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    color: Color(0xFF7CF4FF),
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: improved
                                    ? const Color(0x1A34D27B)
                                    : const Color(0x1AFF6A6A),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    improved
                                        ? Icons.arrow_downward_rounded
                                        : Icons.arrow_upward_rounded,
                                    color: improved
                                        ? const Color(0xFF34D27B)
                                        : const Color(0xFFFF6A6A),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$delta min vs semana previa',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Cuanto menor sea la variabilidad, más consistente es tu rutina de sueño.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SummaryCard(
                    minHeight: 200,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Últimos registros',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (recentEntries.isEmpty)
                          const Text(
                            'Aún no hay registros suficientes para calcular la regularidad.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          )
                        else
                          ...recentEntries.take(7).map(
                            (entry) {
                              final date = _dateOnly(
                                DateTime.tryParse(entry.id) ?? today,
                              );
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            _weekdayLabel(date),
                                            style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            date.day.toString().padLeft(2, '0'),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
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
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.bedtime,
                                                size: 16,
                                                color: AppColors.textSecondary,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Hora de dormir: ${_formatTime(entry.bedtime)}',
                                                style: const TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.wb_sunny_outlined,
                                                size: 16,
                                                color: AppColors.textSecondary,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Despertar: ${_formatTime(entry.wakeTime)}',
                                                style: const TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SummaryCard(
                    minHeight: 160,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Consejos rápidos',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                          ),
                        ),
                        SizedBox(height: 10),
                        _TipRow(
                          icon: Icons.schedule_rounded,
                          label: 'Acuéstate y despierta en una ventana de 30 min diaria.',
                        ),
                        SizedBox(height: 8),
                        _TipRow(
                          icon: Icons.no_food,
                          label: 'Evita comidas pesadas 2 horas antes de dormir.',
                        ),
                        SizedBox(height: 8),
                        _TipRow(
                          icon: Icons.bedroom_baby_outlined,
                          label: 'Reduce la luz brillante 60 minutos antes de acostarte.',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  double _regularityStdDev(
    DateTime start,
    DateTime end,
    List<SleepEntry> entries,
  ) {
    final times = <int>[];
    for (final entry in entries) {
      final date = _dateOnly(DateTime.tryParse(entry.id) ?? DateTime.now());
      if (date.isBefore(start) || date.isAfter(end)) continue;
      final bedMinutes = _parseMinutes(entry.bedtime);
      final wakeMinutes = _parseMinutes(entry.wakeTime);
      if (bedMinutes != null) times.add(bedMinutes);
      if (wakeMinutes != null) times.add(wakeMinutes);
    }
    if (times.length < 2) return 0;
    final mean = times.reduce((a, b) => a + b) / times.length;
    final variance = times
            .map((t) => math.pow(t - mean, 2))
            .reduce((a, b) => a + b) /
        times.length;
    return math.sqrt(variance);
  }

  int? _parseMinutes(String? time) {
    if (time == null || time.isEmpty) return null;
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    if (hours == null || minutes == null) return null;
    return hours * 60 + minutes;
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  String _weekdayLabel(DateTime date) {
    const names = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return names[date.weekday - 1];
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '--:--';
    final parts = time.split(':');
    if (parts.length < 2) return time;
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
