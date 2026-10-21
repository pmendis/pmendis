import '../models/route.dart';
import 'route_tracker.dart';

/// Decides what to say, and when, as the user moves along a route.
///
/// Each maneuver gets at most three prompts, using Valhalla's verbal
/// instructions: an early alert ("In 400 meters, turn left onto …"), a final
/// prompt just before the turn, and a "Continue for …" after it.
class VoiceAnnouncer {
  VoiceAnnouncer(
    this.route, {
    required TravelMode mode,
    bool announceStart = true,
  }) : _alertMeters = switch (mode) {
         TravelMode.car => 500,
         TravelMode.bicycle => 200,
         TravelMode.walk => 100,
       },
       _finalMeters = switch (mode) {
         TravelMode.car => 80,
         TravelMode.bicycle => 40,
         TravelMode.walk => 20,
       } {
    if (!announceStart) _final.add(0);
  }

  final RouteOption route;
  final double _alertMeters;
  final double _finalMeters;
  final _alerted = <int>{};
  final _final = <int>{};
  final _post = <int>{};

  /// The next prompt to speak for [progress], or null to stay quiet.
  String? next(RouteProgress progress) {
    final maneuvers = route.maneuvers;
    final current = progress.currentManeuverIndex;

    if (current == 0 && _final.add(0)) {
      final start = maneuvers[0].verbalPre ?? maneuvers[0].instruction;
      // Skip the post prompt for the start: the alert comes soon enough.
      return start;
    }

    final last = maneuvers.length - 1;
    if (progress.arrived || current == last) {
      // Covers jumping straight to the destination without the final prompt.
      if (!_final.add(last)) return null;
      return maneuvers[last].verbalPre ?? maneuvers[last].instruction;
    }

    final next = progress.nextManeuverIndex;
    final m = maneuvers[next];
    final d = progress.distanceToNextManeuver;

    if (d <= _finalMeters) {
      _alerted.add(next);
      _post.add(current);
      if (_final.add(next)) return m.verbalPre ?? m.instruction;
      return null;
    }

    if (d <= _alertMeters) {
      _post.add(current);
      // Too close to say "in X meters" usefully once the final prompt is near.
      if (d > _finalMeters * 2 && _alerted.add(next)) {
        final alert = m.verbalAlert ?? m.instruction;
        return 'In ${spokenDistance(d)}, ${_lowerFirst(alert)}';
      }
      return null;
    }

    final post = maneuvers[current].verbalPost;
    if (current > 0 && post != null && _post.add(current)) return post;
    return null;
  }
}

String spokenDistance(double meters) {
  if (meters < 1000) {
    final rounded = meters < 100
        ? (meters / 10).round() * 10
        : (meters / 50).round() * 50;
    return '$rounded meters';
  }
  final km = (meters / 100).round() / 10;
  final text = km == km.roundToDouble()
      ? km.toStringAsFixed(0)
      : km.toStringAsFixed(1);
  return text == '1' ? '1 kilometer' : '$text kilometers';
}

String _lowerFirst(String s) =>
    s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
