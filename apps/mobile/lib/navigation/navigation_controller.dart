import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/place.dart';
import '../models/route.dart';
import '../services/routing_service.dart';
import 'position_source.dart';
import 'route_tracker.dart';
import 'speech.dart';
import 'voice_announcer.dart';

/// Runs one turn-by-turn navigation session: follows location fixes along the
/// route, speaks prompts, and fetches a new route when the user goes off it.
class NavigationController extends ChangeNotifier {
  NavigationController({
    required this.routing,
    required this.speech,
    required this.isVoiceEnabled,
    this.routeAvoid = _noAvoid,
    this.rerouteCooldown = const Duration(seconds: 10),
  });

  final RoutingService routing;
  final Speech speech;
  final bool Function() isVoiceEnabled;
  final RouteAvoid Function() routeAvoid;
  final Duration rerouteCooldown;

  static RouteAvoid _noAvoid() => const RouteAvoid();

  RouteOption? _route;
  Place? _destination;
  TravelMode _mode = TravelMode.car;
  bool _simulated = false;
  RouteTracker? _tracker;
  VoiceAnnouncer? _announcer;
  PositionSource? _source;
  StreamSubscription<LocationFix>? _sub;
  RouteProgress? _progress;
  LocationFix? _lastFix;
  bool _rerouting = false;
  String? _rerouteError;
  DateTime? _lastReroute;
  int _session = 0;

  bool get isActive => _route != null;
  RouteOption? get route => _route;
  Place? get destination => _destination;
  TravelMode get mode => _mode;
  bool get isSimulated => _simulated;
  RouteProgress? get progress => _progress;
  bool get isRerouting => _rerouting;
  String? get rerouteError => _rerouteError;
  bool get hasArrived => _progress?.arrived ?? false;

  /// Direction to point the map: device heading when moving, else the route's.
  double get heading => _lastFix?.heading ?? _progress?.bearing ?? 0;

  Maneuver? get nextManeuver {
    final p = _progress, r = _route;
    if (p == null || r == null) return r?.maneuvers.first;
    return r.maneuvers[p.nextManeuverIndex.clamp(0, r.maneuvers.length - 1)];
  }

  /// The maneuver after [nextManeuver], when it follows closely.
  Maneuver? get thenManeuver {
    final p = _progress, r = _route;
    if (p == null || r == null) return null;
    final i = p.nextManeuverIndex + 1;
    if (i >= r.maneuvers.length) return null;
    final gap = r.maneuvers[p.nextManeuverIndex].lengthKm * 1000;
    return gap < 300 ? r.maneuvers[i] : null;
  }

  Future<void> start({
    required RouteOption route,
    required Place destination,
    required TravelMode mode,
    required PositionSource source,
    bool simulated = false,
  }) async {
    await stop();
    final session = ++_session;
    _route = route;
    _destination = destination;
    _mode = mode;
    _simulated = simulated;
    _setRoute(route, announceStart: true);
    _source = source;
    _sub = source.start().listen((fix) {
      if (session == _session) _onFix(fix);
    }, onError: (_) {});
    notifyListeners();
  }

  Future<void> stop() async {
    _session++;
    await _sub?.cancel();
    _sub = null;
    await _source?.stop();
    _source = null;
    await speech.stop();
    final wasActive = isActive;
    _route = null;
    _destination = null;
    _tracker = null;
    _announcer = null;
    _progress = null;
    _lastFix = null;
    _rerouting = false;
    _rerouteError = null;
    _lastReroute = null;
    if (wasActive) notifyListeners();
  }

  void _setRoute(RouteOption route, {required bool announceStart}) {
    _route = route;
    _tracker = RouteTracker(route);
    _announcer = VoiceAnnouncer(
      route,
      mode: _mode,
      announceStart: announceStart,
    );
  }

  void _onFix(LocationFix fix) {
    final tracker = _tracker;
    if (tracker == null) return;
    _lastFix = fix;
    final wasArrived = hasArrived;
    final progress = tracker.update(fix.position, accuracy: fix.accuracy);
    _progress = progress;

    if (progress.offRoute && !progress.arrived) {
      _maybeReroute(fix);
    } else if (!wasArrived) {
      final prompt = _announcer?.next(progress);
      if (prompt != null) _say(prompt);
    }
    notifyListeners();
  }

  Future<void> _maybeReroute(LocationFix fix) async {
    final now = DateTime.now();
    if (_rerouting ||
        (_lastReroute != null &&
            now.difference(_lastReroute!) < rerouteCooldown)) {
      return;
    }
    final destination = _destination!;
    final session = _session;
    _rerouting = true;
    _rerouteError = null;
    _lastReroute = now;
    _say('Rerouting.');
    notifyListeners();
    try {
      final routes = await routing.route(
        fix.position,
        destination.location,
        mode: _mode,
        avoid: routeAvoid(),
        alternates: 0,
        heading: fix.heading,
        originRadius: fix.accuracy,
      );
      if (session != _session) return;
      _setRoute(routes.first, announceStart: false);
      _progress = _tracker!.update(fix.position, accuracy: fix.accuracy);
      final first = routes.first.maneuvers.first;
      final prompt = first.verbalPre ?? first.instruction;
      _say(prompt);
    } catch (e) {
      if (session != _session) return;
      _rerouteError = 'Could not find a new route';
    } finally {
      if (session == _session) {
        _rerouting = false;
        notifyListeners();
      }
    }
  }

  void _say(String text) {
    if (isVoiceEnabled()) speech.speak(text);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
