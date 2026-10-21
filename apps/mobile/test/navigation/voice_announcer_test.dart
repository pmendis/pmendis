import 'package:flutter_test/flutter_test.dart';
import 'package:lanka_maps/models/route.dart';
import 'package:lanka_maps/navigation/geo.dart';
import 'package:lanka_maps/navigation/route_tracker.dart';
import 'package:lanka_maps/navigation/voice_announcer.dart';

import '../support.dart';

void main() {
  Future<List<String>> drive(TravelMode mode) async {
    final route = await fixtureRoute();
    final tracker = RouteTracker(route);
    final announcer = VoiceAnnouncer(route, mode: mode);
    final cumulative = cumulativeDistances(route.shape);
    final prompts = <String>[];
    for (var d = 0.0; d <= cumulative.last + 10; d += 10) {
      final p = tracker.update(pointAlong(route.shape, cumulative, d).point);
      final prompt = announcer.next(p);
      if (prompt != null) prompts.add(prompt);
    }
    return prompts;
  }

  test(
    'driving: alert, final prompt and continue for every maneuver',
    () async {
      expect(await drive(TravelMode.car), [
        'Drive east on Galle Road.',
        'In 500 meters, turn left onto Ananda Coomaraswamy Mawatha.',
        'Turn left onto Ananda Coomaraswamy Mawatha.',
        'Continue for 1.5 kilometers.',
        'In 500 meters, turn right onto Havelock Road.',
        'Turn right onto Havelock Road.',
        'Continue for 900 meters.',
        'In 500 meters, turn left onto Ward Place.',
        'Turn left onto Ward Place.',
        'Continue for 700 meters.',
        'In 500 meters, you will arrive at your destination.',
        'You have arrived at your destination.',
      ]);
    },
  );

  test('walking uses shorter warning distances', () async {
    final prompts = await drive(TravelMode.walk);
    final alerts = prompts.where((p) => p.startsWith('In ')).toList();
    expect(alerts, hasLength(4));
    for (final alert in alerts) {
      final meters = int.parse(
        RegExp(r'^In (\d+) meters').firstMatch(alert)!.group(1)!,
      );
      expect(meters, lessThanOrEqualTo(100));
    }
    expect(prompts.toSet(), hasLength(prompts.length)); // never repeats
  });

  test('can skip the opening instruction after a reroute', () async {
    final route = await fixtureRoute();
    final announcer = VoiceAnnouncer(
      route,
      mode: TravelMode.car,
      announceStart: false,
    );
    final p = RouteTracker(route).update(route.shape.first);
    expect(announcer.next(p), isNull);
  });

  test('announces arrival when jumping straight to the destination', () async {
    final route = await fixtureRoute();
    final tracker = RouteTracker(route);
    final announcer = VoiceAnnouncer(
      route,
      mode: TravelMode.car,
      announceStart: false,
    );
    final p = tracker.update(route.shape.last);
    expect(p.arrived, isTrue);
    expect(announcer.next(p), 'You have arrived at your destination.');
    expect(announcer.next(tracker.update(route.shape.last)), isNull);
  });

  test('spokenDistance rounds like a person would', () {
    expect(spokenDistance(43), '40 meters');
    expect(spokenDistance(487), '500 meters');
    expect(spokenDistance(1000), '1 kilometer');
    expect(spokenDistance(1460), '1.5 kilometers');
    expect(spokenDistance(12040), '12 kilometers');
  });
}
