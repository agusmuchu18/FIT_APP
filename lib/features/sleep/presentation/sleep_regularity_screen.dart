import 'package:flutter/material.dart';

import '../../../core/domain/entities.dart';
import '../../../main.dart';
import '../../common/theme/app_colors.dart';
import '../../common/widgets/summary_card.dart';
import '../domain/sleep_time_utils.dart';

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
      body: FutureBuilder<List<SleepEntry>>(
        future: repository.getSleep(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          final entries = (snapshot.data ?? [])
              .where((e) => !e.deleted)
              .toList()
            ..sort((a, b) => sleepEntryDate(b).compareTo(sleepEntryDate(a)));

          final today = dateOnly(DateTime.now());
          final start = today.subtract(const Duration(days: 6));
          final filtered = entries
              .where((e) {
                final date = sleepEntryDate(e);
                return !date.isBefore(start) && !date.isAfter(today);
              })
              .toList();

          final bedTimes = filtered
              .map((e) => parseHHmmToMinutes(e.bedtime))
              .whereType<int>()
              .toList();
          final wakeTimes = filtered
              .map((e) => parseHHmmToMinutes(e.wakeTime))
              .whereType<int>()
              .toList();

          final bedStd = circularStdDevMinutes(bedTimes).round();
          final wakeStd = circularStdDevMinutes(wakeTimes).round();
          final overall = ((bedStd + wakeStd) / 2).round();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SummaryCard(
                minHeight: 170,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Consistencia semanal',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _MetricBox(label: 'Acueste', value: '$bedStd min'),
                        const SizedBox(width: 10),
                        _MetricBox(label: 'Despertar', value: '$wakeStd min'),
                        const SizedBox(width: 10),
                        _MetricBox(label: 'Total', value: '$overall min'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Desviación estándar circular: menor es mejor. Usa siempre la hora de despertar (día de la mañana).',
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
                    if (filtered.isEmpty)
                      const Text(
                        'Aún no hay registros suficientes para calcular la regularidad.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      )
                    else
                      ...filtered.take(7).map(
                        (entry) {
                          final date = sleepEntryDate(entry);
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
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
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
