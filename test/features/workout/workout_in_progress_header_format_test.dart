import 'package:fit_app/features/workout/presentation/widgets/workout_in_progress_header.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatVolume', () {
    test('formats values according to compact rules', () {
      expect(formatVolume(9500), '9,500');
      expect(formatVolume(10000), '10.0K');
      expect(formatVolume(12600), '12.6K');
      expect(formatVolume(99999), '100.0K');
      expect(formatVolume(100000), '100K');
      expect(formatVolume(126000), '126K');
      expect(formatVolume(1200000), '1.2M');
    });
  });
}
