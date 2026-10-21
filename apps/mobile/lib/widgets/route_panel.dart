import 'package:flutter/material.dart';

import '../format.dart';
import '../models/place.dart';
import '../models/route.dart';

/// Directions panel: start/end, travel mode, route choices, steps, Start.
class RoutePanel extends StatelessWidget {
  const RoutePanel({
    super.key,
    required this.origin,
    required this.destination,
    required this.mode,
    required this.routes,
    required this.selected,
    required this.loading,
    required this.error,
    required this.onModeChanged,
    required this.onRouteSelected,
    required this.onSwap,
    required this.onClear,
    required this.onPickOrigin,
    required this.onPickDestination,
    required this.onStart,
    required this.onGoogleMaps,
    this.avoiding = const [],
  });

  final Place? origin;
  final Place? destination;
  final TravelMode mode;
  final List<RouteOption> routes;
  final int selected;
  final bool loading;
  final String? error;

  /// Settings in effect, shown so a strange route has an explanation.
  final List<String> avoiding;
  final ValueChanged<TravelMode> onModeChanged;
  final ValueChanged<int> onRouteSelected;
  final VoidCallback onSwap;
  final VoidCallback onClear;
  final VoidCallback onPickOrigin;
  final VoidCallback onPickDestination;
  final VoidCallback onStart;
  final VoidCallback onGoogleMaps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final route = routes.isEmpty ? null : routes[selected];

    return Material(
      elevation: 6,
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Endpoint(
                              icon: Icons.trip_origin,
                              color: Colors.green.shade700,
                              label:
                                  origin?.name ??
                                  'Choose start (or long-press the map)',
                              muted: origin == null,
                              onTap: onPickOrigin,
                            ),
                            _Endpoint(
                              icon: Icons.place,
                              color: Colors.red.shade700,
                              label: destination?.name ?? 'Choose destination',
                              muted: destination == null,
                              onTap: onPickDestination,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Swap start and destination',
                        icon: const Icon(Icons.swap_vert),
                        onPressed: origin != null && destination != null
                            ? onSwap
                            : null,
                      ),
                      IconButton(
                        tooltip: 'Close directions',
                        icon: const Icon(Icons.close),
                        onPressed: onClear,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<TravelMode>(
                    segments: const [
                      ButtonSegment(
                        value: TravelMode.car,
                        icon: Icon(Icons.directions_car),
                        label: Text('Drive'),
                      ),
                      ButtonSegment(
                        value: TravelMode.bicycle,
                        icon: Icon(Icons.directions_bike),
                        label: Text('Cycle'),
                      ),
                      ButtonSegment(
                        value: TravelMode.walk,
                        icon: Icon(Icons.directions_walk),
                        label: Text('Walk'),
                      ),
                    ],
                    selected: {mode},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => onModeChanged(s.single),
                  ),
                  const SizedBox(height: 12),
                  if (loading) const LinearProgressIndicator(),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  for (var i = 0; i < routes.length; i++)
                    _RouteChoice(
                      route: routes[i],
                      label: i == 0 ? 'Best route' : 'Alternative $i',
                      selected: i == selected,
                      onTap: () => onRouteSelected(i),
                    ),
                  if (avoiding.isNotEmpty && routes.isNotEmpty)
                    Text(
                      'Avoiding ${avoiding.join(', ')}',
                      style: theme.textTheme.bodySmall,
                    ),
                  if (route != null)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text('Steps (${route.maneuvers.length})'),
                      children: [
                        for (final m in route.maneuvers)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(maneuverIcon(m.type)),
                            title: Text(m.instruction),
                            trailing: m.lengthKm > 0
                                ? Text(formatDistance(m.lengthKm))
                                : null,
                          ),
                      ],
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: route != null && origin != null
                          ? onStart
                          : null,
                      icon: const Icon(Icons.navigation),
                      label: const Text('Start'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: destination != null ? onGoogleMaps : null,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Google Maps'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Endpoint extends StatelessWidget {
  const _Endpoint({
    required this.icon,
    required this.color,
    required this.label,
    required this.muted,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: muted
                    ? theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )
                    : theme.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteChoice extends StatelessWidget {
  const _RouteChoice({
    required this.route,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final RouteOption route;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final notes = [if (route.hasToll) 'Tolls', if (route.hasFerry) 'Ferry'];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? scheme.primaryContainer : null,
      child: ListTile(
        onTap: onTap,
        title: Text(
          formatDuration(route.timeSeconds),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text([label, ...notes].join(' · ')),
        trailing: Text(formatDistance(route.lengthKm)),
      ),
    );
  }
}

/// Icon for a Valhalla maneuver type.
IconData maneuverIcon(int type) => switch (type) {
  1 || 2 || 3 => Icons.trip_origin,
  4 || 5 || 6 => Icons.flag,
  9 => Icons.turn_slight_right,
  10 => Icons.turn_right,
  11 => Icons.turn_sharp_right,
  12 => Icons.u_turn_right,
  13 => Icons.u_turn_left,
  14 => Icons.turn_sharp_left,
  15 => Icons.turn_left,
  16 => Icons.turn_slight_left,
  18 || 20 || 23 => Icons.ramp_right,
  19 || 21 || 24 => Icons.ramp_left,
  25 => Icons.merge,
  26 || 27 => Icons.roundabout_right,
  28 || 29 => Icons.directions_boat,
  _ => Icons.straight,
};
