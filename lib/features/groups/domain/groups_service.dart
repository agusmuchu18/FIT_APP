import 'dart:math';

import '../../../core/data/statistics_service.dart';
import '../../../core/domain/entities.dart';
import 'entities/group.dart';

class GroupsService {
  GroupsService({StatisticsService? statistics})
      : _statisticsFactory = () => statistics ?? StatisticsService() {
    _seed();
  }

  final StatisticsService Function() _statisticsFactory;
  final Map<String, Group> _groups = {};
  final Map<String, _MemberActivityData> _memberData = {};

  Future<List<Group>> fetchGroups() async {
    final groups = _groups.values.toList();
    return Future.wait(groups.map(_attachMetrics));
  }

  Future<Group?> getGroup(String id) async {
    final group = _groups[id];
    if (group == null) return null;
    return _attachMetrics(group);
  }

  Future<Group> createGroup(String name) async {
    final id = 'group-${DateTime.now().millisecondsSinceEpoch}';
    final group = Group(id: id, name: name, members: []);
    _groups[id] = group;
    return group;
  }

  Future<Group?> addMemberToGroup({
    required String groupId,
    required String name,
    required String role,
  }) async {
    final group = _groups[groupId];
    if (group == null) return null;

    final member = GroupMember(
      id: 'member-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      role: role,
    );

    final updatedMembers = [...group.members, member];
    _groups[groupId] = group.copyWith(members: updatedMembers);
    _memberData[member.id] = _generateSampleActivity();
    return _attachMetrics(_groups[groupId]!);
  }

  Future<Group> _attachMetrics(Group group) async {
    final members = await Future.wait(group.members.map(_memberWithMetrics));
    return group.copyWith(members: members);
  }

  Future<GroupMember> _memberWithMetrics(GroupMember member) async {
    final data = _memberData[member.id];
    if (data == null) return member;
    final metrics = await _calculateMetrics(data);
    return member.copyWith(metrics: metrics);
  }

  Future<GroupMemberMetrics> _calculateMetrics(_MemberActivityData data) async {
    final stats = _statisticsFactory();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(
      const Duration(days: 6),
    );

    final weeklyMinutes = _sumWorkoutMinutes(data.workouts, start, now);
    final averageDailyCalories = await _averageCaloriesPerDay(
      stats,
      data.meals,
      start,
      now,
    );
    final averageSleepHours = await _averageSleepHours(stats, data.sleep, start, now);

    return GroupMemberMetrics(
      weeklyWorkoutMinutes: weeklyMinutes,
      averageDailyCalories: averageDailyCalories,
      averageSleepHours: averageSleepHours,
    );
  }

  int _sumWorkoutMinutes(List<WorkoutEntry> workouts, DateTime start, DateTime end) {
    return workouts.where((entry) {
      final date = DateTime.tryParse(entry.id);
      if (date == null) return false;
      return !date.isBefore(start) && !date.isAfter(end);
    }).fold(0, (sum, entry) => sum + entry.durationMinutes);
  }

  Future<double> _averageCaloriesPerDay(
    StatisticsService stats,
    List<MealEntry> meals,
    DateTime start,
    DateTime end,
  ) async {
    final Map<DateTime, List<MealEntry>> mealsByDay = {};
    for (final meal in meals) {
      final date = DateTime.tryParse(meal.id);
      if (date == null) continue;
      if (date.isBefore(start) || date.isAfter(end)) continue;
      final day = DateTime(date.year, date.month, date.day);
      mealsByDay.putIfAbsent(day, () => []).add(meal);
    }

    for (var i = 0; i < 7; i++) {
      final day = DateTime(start.year, start.month, start.day).add(Duration(days: i));
      final dailyMeals = mealsByDay[day] ?? [];
      final totalCalories = dailyMeals.fold<int>(0, (sum, meal) => sum + meal.calories);
      final macros = dailyMeals.fold<Macros>(
        Macros(carbs: 0, protein: 0, fat: 0),
        (acc, meal) => Macros(
          carbs: acc.carbs + meal.macros.carbs,
          protein: acc.protein + meal.macros.protein,
          fat: acc.fat + meal.macros.fat,
        ),
      );

      await stats.recordNutritionMetrics(
        NutritionMetrics(date: day, totalCalories: totalCalories, macros: macros),
      );
    }

    final history = await stats.getNutritionHistory(days: 7);
    final totalCaloriesWeek = history.fold<int>(0, (sum, item) => sum + item.totalCalories);
    return totalCaloriesWeek / 7;
  }

  Future<double> _averageSleepHours(
    StatisticsService stats,
    List<SleepEntry> sleepEntries,
    DateTime start,
    DateTime end,
  ) async {
    for (final entry in sleepEntries) {
      final date = DateTime.tryParse(entry.id);
      if (date == null) continue;
      if (date.isBefore(start) || date.isAfter(end)) continue;
      await stats.recordSleepInsights(entry);
    }

    final entries = await stats.getSleepEntries(days: 7);
    if (entries.isEmpty) return 0;
    final totalHours = entries.fold<double>(0, (sum, entry) => sum + entry.hours);
    return totalHours / entries.length;
  }

  void _seed() {
    final team = Group(
      id: 'group-elite',
      name: 'Equipo élite',
      members: [
        GroupMember(id: 'member-andrea', name: 'Andrea Gómez', role: 'Velocista'),
        GroupMember(id: 'member-julián', name: 'Julián Rivas', role: 'Fuerza'),
        GroupMember(id: 'member-marcela', name: 'Marcela Ríos', role: 'Resistencia'),
      ],
    );

    _groups[team.id] = team;

    _memberData['member-andrea'] = _generateSampleActivity(intensityFactor: 1.2);
    _memberData['member-julián'] = _generateSampleActivity(intensityFactor: 1.6);
    _memberData['member-marcela'] = _generateSampleActivity(intensityFactor: 1.1);
  }

  _MemberActivityData _generateSampleActivity({double intensityFactor = 1.0}) {
    final now = DateTime.now();
    final random = Random(intensityFactor.hashCode);

    final workouts = List<WorkoutEntry>.generate(7, (index) {
      final date = now.subtract(Duration(days: index));
      final duration = (30 + random.nextInt(25)) * intensityFactor;
      return WorkoutEntry(
        id: date.toIso8601String(),
        name: 'Sesión ${index + 1}',
        durationMinutes: duration.round(),
        intensity: ['Baja', 'Moderado', 'Alta'][random.nextInt(3)],
      );
    });

    final meals = List<MealEntry>.generate(14, (index) {
      final date = now.subtract(Duration(hours: index * 10));
      final calories = 450 + random.nextInt(350);
      return MealEntry(
        id: date.toIso8601String(),
        title: 'Plan ${index + 1}',
        calories: (calories * intensityFactor).round(),
        macros: Macros(
          carbs: 50 + random.nextInt(40),
          protein: 25 + random.nextInt(30),
          fat: 15 + random.nextInt(20),
        ),
      );
    });

    final sleep = List<SleepEntry>.generate(7, (index) {
      final date = now.subtract(Duration(days: index));
      final hours = 6 + random.nextDouble() * 3;
      return SleepEntry(
        id: date.toIso8601String(),
        hours: double.parse(hours.toStringAsFixed(1)),
        quality: ['Excelente', 'Buena', 'Irregular'][random.nextInt(3)],
      );
    });

    return _MemberActivityData(workouts: workouts, meals: meals, sleep: sleep);
  }
}

class _MemberActivityData {
  _MemberActivityData({
    required this.workouts,
    required this.meals,
    required this.sleep,
  });

  final List<WorkoutEntry> workouts;
  final List<MealEntry> meals;
  final List<SleepEntry> sleep;
}

final groupsService = GroupsService();
