import 'package:flutter/material.dart';

class ProfileProgressPhoto {
  const ProfileProgressPhoto({
    required this.id,
    required this.url,
    required this.dateLabel,
  });

  final String id;
  final String url;
  final String dateLabel;
}

class ProfileStatItem {
  const ProfileStatItem({required this.label, required this.value, this.unit});

  final String label;
  final String value;
  final String? unit;
}

class ProfilePRItem {
  const ProfilePRItem({
    required this.exercise,
    required this.value,
    required this.detail,
    required this.icon,
  });

  final String exercise;
  final String value;
  final String detail;
  final IconData icon;
}
