import 'package:flutter/material.dart';

enum IntegrationId {
  fitbit,
  ring,
  appleWatch,
  garmin,
  hrStrap,
  appleHealth,
  googleFit,
  whoop,
  oura,
  polar,
  suunto,
  catapult,
  openFoodFacts,
  myFitnessPal,
  cronometer,
  sleepCycle,
  strava,
  trainingPeaks,
}

enum IntegrationCategory {
  activityTraining,
  healthSensors,
  sleep,
  nutrition,
}

class IntegrationItem {
  const IntegrationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.isAvailable,
    required this.iconData,
    required this.description,
    required this.importableData,
  });

  final IntegrationId id;
  final String title;
  final String subtitle;
  final IntegrationCategory category;
  final bool isAvailable;
  final IconData iconData;
  final String description;
  final List<String> importableData;
}

class IntegrationStatus {
  const IntegrationStatus({
    this.enabled = false,
    this.connected = false,
    this.lastSync,
  });

  final bool enabled;
  final bool connected;
  final DateTime? lastSync;

  IntegrationStatus copyWith({
    bool? enabled,
    bool? connected,
    DateTime? lastSync,
  }) {
    return IntegrationStatus(
      enabled: enabled ?? this.enabled,
      connected: connected ?? this.connected,
      lastSync: lastSync ?? this.lastSync,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'connected': connected,
      'lastSync': lastSync?.toIso8601String(),
    };
  }

  factory IntegrationStatus.fromJson(Map<String, dynamic> json) {
    return IntegrationStatus(
      enabled: json['enabled'] == true,
      connected: json['connected'] == true,
      lastSync: DateTime.tryParse((json['lastSync'] ?? '') as String),
    );
  }
}
