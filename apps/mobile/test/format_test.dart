import 'package:flutter_test/flutter_test.dart';
import 'package:lanka_maps/format.dart';

void main() {
  test('formatDuration', () {
    expect(formatDuration(20), '< 1 min');
    expect(formatDuration(243), '4 min');
    expect(formatDuration(3600), '1 h');
    expect(formatDuration(3900), '1 h 5 min');
  });

  test('formatDistance', () {
    expect(formatDistance(0.123), '120 m');
    expect(formatDistance(3.77), '3.8 km');
    expect(formatDistance(42.4), '42 km');
  });
}
