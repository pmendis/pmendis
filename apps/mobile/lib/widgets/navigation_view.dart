import 'package:flutter/material.dart';

import '../format.dart';
import '../models/route.dart';
import '../navigation/navigation_controller.dart';
import 'route_panel.dart' show maneuverIcon;

/// The instruction card at the top of the screen while navigating.
class NavigationBanner extends StatelessWidget {
  const NavigationBanner({super.key, required this.nav});

  final NavigationController nav;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final next = nav.nextManeuver;
    final then = nav.thenManeuver;
    final progress = nav.progress;
    final onColor = scheme.onPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: scheme.primary,
          elevation: 4,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: nav.isRerouting
                ? Row(
                    children: [
                      SizedBox.square(
                        dimension: 28,
                        child: CircularProgressIndicator(
                          color: onColor,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Rerouting…',
                        style: text.titleLarge?.copyWith(color: onColor),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(
                        next == null
                            ? Icons.navigation
                            : maneuverIcon(next.type),
                        size: 48,
                        color: onColor,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (progress != null && !nav.hasArrived)
                              Text(
                                formatDistance(
                                  progress.distanceToNextManeuver / 1000,
                                ),
                                style: text.headlineMedium?.copyWith(
                                  color: onColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            Text(
                              _instruction(next),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleMedium?.copyWith(color: onColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (then != null && !nav.isRerouting)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Material(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Then'),
                    const SizedBox(width: 6),
                    Icon(maneuverIcon(then.type), size: 20),
                  ],
                ),
              ),
            ),
          ),
        if (nav.rerouteError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Chip(
              avatar: const Icon(Icons.wifi_off, size: 18),
              label: Text(nav.rerouteError!),
            ),
          ),
        if (nav.isSimulated)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Chip(
              avatar: Icon(Icons.smart_toy_outlined, size: 18),
              label: Text('Simulated drive'),
            ),
          ),
      ],
    );
  }

  /// Valhalla's arrival instruction reads "You have arrived…", so until the
  /// user actually arrives show its "You will arrive…" form instead.
  String _instruction(Maneuver? next) {
    if (next == null) return 'Waiting for location…';
    if (next.isArrival && !nav.hasArrived) {
      return next.verbalAlert ?? 'Destination ahead';
    }
    return next.instruction;
  }
}

/// Time, distance and arrival time, plus controls, at the bottom.
class NavigationFooter extends StatelessWidget {
  const NavigationFooter({
    super.key,
    required this.nav,
    required this.voiceOn,
    required this.following,
    required this.onToggleVoice,
    required this.onToggleOverview,
    required this.onExit,
  });

  final NavigationController nav;
  final bool voiceOn;
  final bool following;
  final VoidCallback onToggleVoice;
  final VoidCallback onToggleOverview;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = nav.progress;
    final route = nav.route;
    final seconds = progress?.remainingSeconds ?? route?.timeSeconds ?? 0;
    final meters = progress?.remainingMeters ?? (route?.lengthKm ?? 0) * 1000;
    final eta = TimeOfDay.fromDateTime(
      DateTime.now().add(Duration(seconds: seconds.round())),
    ).format(context);

    return Material(
      elevation: 6,
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          child: nav.hasArrived
              ? Row(
                  children: [
                    Icon(
                      Icons.flag,
                      color: theme.colorScheme.primary,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'You have arrived',
                            style: theme.textTheme.titleLarge,
                          ),
                          if (nav.destination != null)
                            Text(
                              nav.destination!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    FilledButton(onPressed: onExit, child: const Text('Done')),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatDuration(seconds),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text('${formatDistance(meters / 1000)} · $eta'),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: voiceOn
                          ? 'Mute voice guidance'
                          : 'Unmute voice guidance',
                      icon: Icon(voiceOn ? Icons.volume_up : Icons.volume_off),
                      onPressed: onToggleVoice,
                    ),
                    IconButton(
                      tooltip: following
                          ? 'Route overview'
                          : 'Follow my position',
                      icon: Icon(
                        following ? Icons.alt_route : Icons.navigation,
                      ),
                      onPressed: onToggleOverview,
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                      ),
                      onPressed: onExit,
                      child: const Text('Exit'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
