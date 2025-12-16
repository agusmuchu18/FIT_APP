import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/domain/entities.dart';
import '../../../main.dart';
import '../../common/theme/app_colors.dart';
import '../../common/widgets/summary_card.dart';
import '../domain/sleep_time_utils.dart';

class SleepOverviewScreen extends StatefulWidget {
  const SleepOverviewScreen({super.key});

  @override
  State<SleepOverviewScreen> createState() => _SleepOverviewScreenState();
}

class _SleepOverviewScreenState extends State<SleepOverviewScreen> {
  FitnessRepository? _repository;
  Future<_OverviewData>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository ??= RepositoryScope.of(context);
    _future ??= _load(_repository!);
  }

  Future<_OverviewData> _load(FitnessRepository repository) async {
    final sleep = await repository.getSleep();
    final prefs = await repository.getPreferences();
    return _OverviewData(entries: sleep, prefs: prefs);
  }

  Future<void> _refresh() async {
    final repo = _repository!;
    setState(() {
      _future = _load(repo);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Sueño'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_toggle_off_outlined),
            onPressed: () => Navigator.pushNamed(context, '/sleep/history'),
          ),
        ],
      ),
      body: FutureBuilder<_OverviewData>(
        future: _future,
        builder: (context, snapshot) {
          if (_future == null) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          final data = snapshot.data;
          if (data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SummaryCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.textSecondary),
                      const SizedBox(height: 8),
                      const Text('No se pudo cargar Sueño',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      const Text('Probá refrescar o volver a entrar.',
                          style: TextStyle(color: AppColors.textMuted)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _refresh,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final entries = data.entries
              .where((e) => !e.deleted)
              .toList()
            ..sort((a, b) => sleepEntryDate(b).compareTo(sleepEntryDate(a)));

          final recent = entries.take(14).toList();
          final lastSeven = _filterByDays(entries, 7);
          final lastEntry = entries.isNotEmpty ? entries.first : null;
          final double avg7Days = lastSeven.isEmpty
              ? 0.0
              : lastSeven.map((e) => e.hours).reduce((a, b) => a + b) /
                  lastSeven.length;
          final goal = data.prefs?.preferredSleep ?? 8.0;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (lastEntry != null)
                  _LastNightCard(
                    entry: lastEntry,
                    avgHours: avg7Days,
                  ),
                const SizedBox(height: 16),
                _TrendCard(entries: lastSeven),
                const SizedBox(height: 16),
                _ConsistencyCard(entries: lastSeven),
                const SizedBox(height: 16),
                _DebtCard(entries: lastSeven, goal: goal),
                const SizedBox(height: 16),
                _QuickActions(),
                const SizedBox(height: 24),
                _MiniHistory(entries: recent.take(5).toList()),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LastNightCard extends StatelessWidget {
  const _LastNightCard({required this.entry, required this.avgHours});

  final SleepEntry entry;
  final double avgHours;

  @override
  Widget build(BuildContext context) {
    final bedtime = entry.bedtime ?? '--';
    final wakeTime = entry.wakeTime ?? '--';
    final delta = entry.hours - avgHours;
    final deltaText = delta >= 0
        ? '+${delta.toStringAsFixed(1)} h vs 7d'
        : '${delta.toStringAsFixed(1)} h vs 7d';

    return SummaryCard(
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
                    'Última noche',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.hours.toStringAsFixed(1)} h · ${entry.quality}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$bedtime → $wakeTime',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: delta >= 0
                      ? const Color(0x1A34D27B)
                      : const Color(0x1AFF6A6A),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  deltaText,
                  style: TextStyle(
                    color: delta >= 0
                        ? const Color(0xFF34D27B)
                        : const Color(0xFFFF6A6A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.entries});

  final List<SleepEntry> entries;

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final spots = <BarChartGroupData>[];
    for (var i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final entry = entries.firstWhere(
        (e) => _sameDay(sleepEntryDate(e), day),
        orElse: () => _empty,
      );
      final hours = entry.id.isEmpty ? 0.0 : entry.hours;
      spots.add(
        BarChartGroupData(
          x: 6 - i,
          barRods: [
            BarChartRodData(
              toY: hours,
              color: AppColors.accentSecondary,
              borderRadius: BorderRadius.circular(6),
              width: 14,
            ),
          ],
        ),
      );
    }

    return SummaryCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tendencia (7 días)',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final day = today.subtract(Duration(days: 6 - value.toInt()));
                        const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
                        return Text(
                          labels[day.weekday - 1],
                          style: const TextStyle(color: AppColors.textMuted),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: spots,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsistencyCard extends StatelessWidget {
  const _ConsistencyCard({required this.entries});

  final List<SleepEntry> entries;

  @override
  Widget build(BuildContext context) {
    final bedMinutes = entries
        .map((e) => parseHHmmToMinutes(e.bedtime))
        .whereType<int>()
        .toList();
    final wakeMinutes = entries
        .map((e) => parseHHmmToMinutes(e.wakeTime))
        .whereType<int>()
        .toList();
    final midSleep = entries
        .map((e) => computeMidSleepMinutes(
              bedMin: parseHHmmToMinutes(e.bedtime),
              wakeMin: parseHHmmToMinutes(e.wakeTime),
            ))
        .whereType<int>()
        .toList();

    final bedStd = circularStdDevMinutes(bedMinutes).round();
    final wakeStd = circularStdDevMinutes(wakeMinutes).round();
    final totalStd = ((bedStd + wakeStd) / 2).round();

    double? socialJetLag() {
      final weekdays = entries
          .where((e) => sleepEntryDate(e).weekday <= 5)
          .map((e) => computeMidSleepMinutes(
                bedMin: parseHHmmToMinutes(e.bedtime),
                wakeMin: parseHHmmToMinutes(e.wakeTime),
              ))
          .whereType<int>()
          .toList();
      final weekend = entries
          .where((e) => sleepEntryDate(e).weekday > 5)
          .map((e) => computeMidSleepMinutes(
                bedMin: parseHHmmToMinutes(e.bedtime),
                wakeMin: parseHHmmToMinutes(e.wakeTime),
              ))
          .whereType<int>()
          .toList();
      if (weekdays.isEmpty || weekend.isEmpty) return null;
      final weekdayAvg = weekdays.reduce((a, b) => a + b) / weekdays.length;
      final weekendAvg = weekend.reduce((a, b) => a + b) / weekend.length;
      return (weekdayAvg - weekendAvg).abs() / 60;
    }

    return SummaryCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Consistencia',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _metricTile('Acueste', '$bedStd min'),
              const SizedBox(width: 12),
              _metricTile('Despertar', '$wakeStd min'),
              const SizedBox(width: 12),
              _metricTile('Promedio', '$totalStd min'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            socialJetLag() != null
                ? 'Social jet lag: ${socialJetLag()!.toStringAsFixed(1)} h'
                : 'Social jet lag: insuficiente datos',
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({required this.entries, required this.goal});

  final List<SleepEntry> entries;
  final double goal;

  @override
  Widget build(BuildContext context) {
    final debt = entries.fold<double>(0, (sum, e) => sum + (goal - e.hours).clamp(0, 24));

    return SummaryCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deuda de sueño',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${debt.toStringAsFixed(1)} h en 7 días',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Objetivo: ${goal.toStringAsFixed(1)}h por noche. La deuda acumula las horas faltantes.',
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SummaryCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acciones rápidas',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ActionChip(
                label: 'Registrar Lite',
                icon: Icons.flash_on,
                onTap: () => Navigator.pushNamed(context, '/sleep/lite'),
              ),
              _ActionChip(
                label: 'Registrar Pro',
                icon: Icons.insights,
                onTap: () => Navigator.pushNamed(context, '/sleep/pro'),
              ),
              _ActionChip(
                label: 'Regularidad',
                icon: Icons.track_changes,
                onTap: () => Navigator.pushNamed(context, '/sleep/regularity'),
              ),
              _ActionChip(
                label: 'Historial',
                icon: Icons.history,
                onTap: () => Navigator.pushNamed(context, '/sleep/history'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniHistory extends StatelessWidget {
  const _MiniHistory({required this.entries});

  final List<SleepEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    return SummaryCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Historial rápido',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/sleep/history'),
                child: const Text('Ver todo'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _weekdayLabel(sleepEntryDate(e)),
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                        Text(
                          sleepEntryDate(e).day.toString().padLeft(2, '0'),
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
                          '${e.hours.toStringAsFixed(1)} h · ${e.quality}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        Text(
                          '${e.bedtime ?? '--'} → ${e.wakeTime ?? '--'}',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.accentSecondary, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

Widget _metricTile(String title, String value) {
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
          Text(title, style: const TextStyle(color: AppColors.textMuted)),
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

List<SleepEntry> _filterByDays(List<SleepEntry> entries, int days) {
  final today = dateOnly(DateTime.now());
  final start = today.subtract(Duration(days: days - 1));
  return entries
      .where((e) {
        final date = sleepEntryDate(e);
        return !date.isBefore(start) && !date.isAfter(today);
      })
      .toList();
}

String _weekdayLabel(DateTime date) {
  const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  return labels[date.weekday - 1];
}

class _OverviewData {
  _OverviewData({required this.entries, required this.prefs});

  final List<SleepEntry> entries;
  final UserPreferences? prefs;
}

final _empty = SleepEntry(
  id: '',
  hours: 0,
  quality: '',
  bedtime: null,
  wakeTime: null,
  sleepDate: null,
  tags: [],
  qualityScore: null,
  meta: EntityMeta(
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    deleted: false,
    revision: 0,
  ),
);
