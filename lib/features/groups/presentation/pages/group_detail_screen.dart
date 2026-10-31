import 'group_entry_form.dart';

import 'package:flutter/material.dart';

import '../../domain/entities/group.dart';
import '../../domain/groups_service.dart';

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  final String groupId;
  final String groupName;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late Future<Group?> _groupFuture;

  @override
  void initState() {
    super.initState();
    _groupFuture = groupsService.getGroup(widget.groupId);
  }

  Future<void> _addMember() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => GroupEntryForm(
        member: true,
        onSave: (name, role) async {
          final group = await groupsService.addMemberToGroup(
            groupId: widget.groupId,
            name: name,
            role: role,
          );
          if (group == null) throw StateError('Grupo no disponible');
        },
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        _groupFuture = groupsService.getGroup(widget.groupId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        actions: [
          IconButton(
            onPressed: () => setState(() {
              _groupFuture = groupsService.getGroup(widget.groupId);
            }),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recargar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'group_add_member_fab',
        onPressed: _addMember,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Agregar atleta'),
      ),
      body: SafeArea(
        child: FutureBuilder<Group?>(
          future: _groupFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'No se pudo leer el grupo. Tus datos se conservan.',
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _groupFuture = groupsService.getGroup(widget.groupId);
                        }),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'No se encontró el grupo',
                      style: textTheme.titleMedium,
                    ),
                  ],
                ),
              );
            }

            final group = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resumen de miembros',
                          style: textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Los atletas agregados son contactos de este grupo local. Sus entrenamientos, alimentación y sueño permanecen privados hasta que compartan datos expresamente.',
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            _Pill(
                              icon: Icons.timer_rounded,
                              label: 'Minutos 7 días',
                            ),
                            _Pill(
                              icon: Icons.local_fire_department_rounded,
                              label: 'Calorías diarias',
                            ),
                            _Pill(
                              icon: Icons.bedtime_rounded,
                              label: 'Horas de sueño',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...group.members.map(
                  (member) =>
                      _MemberCard(member: member, colorScheme: colorScheme),
                ),
                const SizedBox(height: 80),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member, required this.colorScheme});

  final GroupMember member;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final metrics = member.metrics;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    member.name.characters.first,
                    style: textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.name, style: textTheme.titleMedium),
                      Text(member.role, style: textTheme.bodyMedium),
                    ],
                  ),
                ),
                const Icon(Icons.more_vert_rounded),
              ],
            ),
            const SizedBox(height: 12),
            if (metrics == null)
              const Text(
                'Sin métricas compartidas. Agregar un contacto no concede acceso a sus datos.',
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.timer_rounded,
                      label: 'Minutos (7d)',
                      value: '${metrics.weeklyWorkoutMinutes} min',
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Calorías promedio',
                      value:
                          '${metrics.averageDailyCalories.toStringAsFixed(0)} kcal',
                      color: Colors.deepOrange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.bedtime_rounded,
                      label: 'Sueño promedio',
                      value:
                          '${metrics.averageSleepHours.toStringAsFixed(1)} h',
                      color: Colors.indigo,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(label, style: textTheme.bodySmall),
          Text(value, style: textTheme.titleMedium?.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(icon, size: 18, color: colorScheme.primary),
      label: Text(label),
      backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.4),
      side: BorderSide(color: colorScheme.primaryContainer),
    );
  }
}
