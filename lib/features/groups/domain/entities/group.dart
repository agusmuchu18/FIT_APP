import '../../../../core/domain/entities.dart';

class Group {
  Group({
    required this.id,
    required this.name,
    required this.members,
  });

  final String id;
  final String name;
  final List<GroupMember> members;

  Group copyWith({
    String? name,
    List<GroupMember>? members,
  }) {
    return Group(
      id: id,
      name: name ?? this.name,
      members: members ?? this.members,
    );
  }
}

class GroupMember {
  GroupMember({
    required this.id,
    required this.name,
    required this.role,
    this.metrics,
  });

  final String id;
  final String name;
  final String role;
  final GroupMemberMetrics? metrics;

  GroupMember copyWith({
    String? name,
    String? role,
    GroupMemberMetrics? metrics,
  }) {
    return GroupMember(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      metrics: metrics ?? this.metrics,
    );
  }
}

class GroupMemberMetrics {
  const GroupMemberMetrics({
    required this.weeklyWorkoutMinutes,
    required this.averageDailyCalories,
    required this.averageSleepHours,
  });

  final int weeklyWorkoutMinutes;
  final double averageDailyCalories;
  final double averageSleepHours;
}
