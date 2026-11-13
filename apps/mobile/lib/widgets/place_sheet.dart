import 'package:flutter/material.dart';

import '../models/place.dart';
import '../storage/saved_places.dart';

/// Details and actions for a selected place.
class PlaceSheet extends StatelessWidget {
  const PlaceSheet({
    super.key,
    required this.place,
    required this.savedAs,
    required this.onDirections,
    required this.onSave,
    required this.onGoogleMaps,
    required this.onReport,
    required this.onClose,
    this.distanceText,
  });

  final Place place;
  final Set<SavedKind> savedAs;

  /// e.g. "4.2 km away", when the user's position is known.
  final String? distanceText;
  final VoidCallback onDirections;
  final VoidCallback onSave;
  final VoidCallback onGoogleMaps;
  final VoidCallback onReport;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [?place.detail, ?distanceText].join(' · ');

    return Material(
      elevation: 6,
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        place.name,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                  ),
                ],
              ),
              if (subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12, top: 2),
                  child: Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: onDirections,
                    icon: const Icon(Icons.directions),
                    label: const Text('Directions'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onSave,
                    icon: Icon(
                      savedAs.isEmpty ? Icons.bookmark_border : Icons.bookmark,
                    ),
                    label: Text(savedAs.isEmpty ? 'Save' : 'Saved'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onGoogleMaps,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Google Maps'),
                  ),
                  TextButton.icon(
                    onPressed: onReport,
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Report a problem'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
