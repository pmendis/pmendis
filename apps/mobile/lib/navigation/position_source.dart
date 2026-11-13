import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'geo.dart';

class LocationFix {
  const LocationFix({
    required this.position,
    this.heading,
    this.speed = 0,
    this.accuracy = 0,
  });

  final LatLng position;

  /// Direction of travel in degrees, when the device knows it.
  final double? heading;

  /// Meters per second.
  final double speed;

  /// Horizontal accuracy radius in meters.
  final double accuracy;
}

abstract class PositionSource {
  /// Starts producing fixes. Called once per source.
  Stream<LocationFix> start();

  Future<void> stop();
}

/// Live GPS, kept running in the background while navigating.
class GpsPositionSource implements PositionSource {
  StreamSubscription<Position>? _sub;
  final _controller = StreamController<LocationFix>();

  @override
  Stream<LocationFix> start() {
    _sub = Geolocator.getPositionStream(locationSettings: _settings()).listen(
      (p) => _controller.add(
        LocationFix(
          position: LatLng(p.latitude, p.longitude),
          heading: p.heading >= 0 && p.speed > 1 ? p.heading : null,
          speed: p.speed < 0 ? 0 : p.speed,
          accuracy: p.accuracy,
        ),
      ),
      onError: _controller.addError,
    );
    return _controller.stream;
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    await _controller.close();
  }

  static LocationSettings _settings() {
    if (kIsWeb) {
      return const LocationSettings(accuracy: LocationAccuracy.best);
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          intervalDuration: const Duration(seconds: 1),
          // Keeps updates coming with the screen off or the app in the
          // background, shown to the user as a persistent notification.
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Lanka Maps',
            notificationText: 'Navigation is running',
            enableWakeLock: true,
            setOngoing: true,
          ),
        );
      case TargetPlatform.iOS:
        return AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.automotiveNavigation,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
        );
      default:
        return const LocationSettings(accuracy: LocationAccuracy.best);
    }
  }
}

/// Drives along a route line at a steady speed. Used to preview navigation
/// when the start isn't the user's real position, and for testing.
class SimulatedPositionSource implements PositionSource {
  SimulatedPositionSource(
    this.line, {
    required this.metersPerSecond,
    this.tick = const Duration(seconds: 1),
  }) : _cumulative = cumulativeDistances(line);

  final List<LatLng> line;
  final double metersPerSecond;
  final Duration tick;
  final List<double> _cumulative;
  Timer? _timer;
  final _controller = StreamController<LocationFix>();

  @override
  Stream<LocationFix> start() {
    var traveled = 0.0;
    void emit() {
      if (_controller.isClosed) return;
      final at = pointAlong(line, _cumulative, traveled);
      _controller.add(
        LocationFix(
          position: at.point,
          heading: at.bearing,
          speed: metersPerSecond,
          accuracy: 5,
        ),
      );
      if (traveled >= _cumulative.last) {
        _timer?.cancel();
        return;
      }
      traveled += metersPerSecond * tick.inMilliseconds / 1000;
    }

    // First fix right away so the UI has a position immediately.
    scheduleMicrotask(emit);
    _timer = Timer.periodic(tick, (_) => emit());
    return _controller.stream;
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    await _controller.close();
  }
}
