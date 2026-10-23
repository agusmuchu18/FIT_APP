import 'group_entry_form.dart';

import 'package:flutter/material.dart';

import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/summary_card.dart';
import '../../domain/entities/group.dart';
import '../../domain/groups_service.dart';
import 'group_detail_screen.dart';

class GroupsListScreen extends StatefulWidget {
  const GroupsListScreen({super.key});

  @override
  State<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends State<GroupsListScreen> {
  late Future<List<Group>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _groupsFuture = groupsService.fetchGroups();
  }

  Future<void> _createGroup(BuildContext context) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => GroupEntryForm(
        member: false,
        onSave: (name, _) async {
          await groupsService.createGroup(name);
        },
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        _groupsFuture = groupsService.fetchGroups();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Grupos de atletas',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: AppColors.textPrimary,
            onPressed: () => setState(() { _groupsFuture = groupsService.fetchGroups(); }),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'groups_create_fab',
        onPressed: () => _createGroup(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Crear grupo'),
        backgroundColor: const Color(0xFF1E2A3D),
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: Container(
          color: AppColors.background,
          child: FutureBuilder<List<Group>>(
            future: _groupsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator.adaptive());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.error_outline, size: 32, color: AppColors.textPrimary),
                      SizedBox(height: 8),
                      Text(
                        'No se pudieron cargar los grupos',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final groups = snapshot.data ?? [];
              if (groups.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.groups_2_rounded, size: 48, color: AppColors.accentSecondary),
                      SizedBox(height: 12),
                      Text(
                        'Crea tu primer grupo',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Organiza atletas y sigue su progreso en un solo lugar.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: groups.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return _GroupCard(group: group);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GroupDetailScreen(groupId: group.id, groupName: group.name),
          ),
        ),
        child: SummaryCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2A3D),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.group_work_rounded,
                      color: AppColors.accentSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${group.members.length} atletas',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: group.members.take(3).map((member) {
                  return Chip(
                    label: Text(
                      member.name,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    avatar: const Icon(Icons.person_rounded, size: 18, color: AppColors.textSecondary),
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: Colors.transparent),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
