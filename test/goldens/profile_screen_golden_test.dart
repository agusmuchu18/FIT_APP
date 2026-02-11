import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fit_app/features/profile/profile_screen.dart';

void main() {
  testWidgets('ProfileScreen golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));

    await tester.pumpWidget(
      const MaterialApp(home: ProfileScreen()),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ProfileScreen),
      matchesGoldenFile('profile_screen.png'),
    );
  });
}
