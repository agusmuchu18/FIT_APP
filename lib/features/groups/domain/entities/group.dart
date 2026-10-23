class Group {
  Group({
    required this.id,
    required this.name,
    required this.members,
  });

  final String id;
  final String name;
  final List<GroupMember> members;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'members': members.map((m) => m.toJson()).toList(),
  };
  factory Group.fromJson(Map<String, dynamic> json) {
    final id = json['id'], name = json['name'], members = json['members'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        members is! List) {
      throw const FormatException('Grupo inválido');
    }
    final parsed = members
        .map((m) => GroupMember.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList();
    if (parsed.map((m) => m.id).toSet().length != parsed.length) {
      throw const FormatException('Miembros duplicados');
    }
    return Group(id: id, name: name, members: parsed);
  }

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

  // Persist identity only. No generated or implicitly authorized health metrics.
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'role': role};
  factory GroupMember.fromJson(Map<String, dynamic> json) {
    final id = json['id'], name = json['name'], role = json['role'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        role is! String) {
      throw const FormatException('Miembro inválido');
    }
    return GroupMember(id: id, name: name, role: role);
  }

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
