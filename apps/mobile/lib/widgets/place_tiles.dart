import 'package:flutter/material.dart';

import '../models/place.dart';
import '../storage/saved_places.dart';

/// A place row used in search results and saved lists.
class PlaceTile extends StatelessWidget {
  const PlaceTile({
    super.key,
    required this.place,
    required this.onTap,
    this.icon = Icons.place_outlined,
    this.label,
    this.trailing,
  });

  final Place place;
  final VoidCallback onTap;
  final IconData icon;

  /// Replaces the place name as the title, e.g. "Home".
  final String? label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final subtitle = label != null ? place.name : place.detail;
    return ListTile(
      leading: Icon(icon),
      title: Text(label ?? place.name),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// Home, Work, favourites and recents as tiles, for empty-search states.
List<Widget> savedPlaceTiles(
  SavedPlaces saved, {
  required ValueChanged<Place> onSelected,
  int maxRecents = SavedPlaces.maxRecents,
}) => [
  if (saved.home != null)
    PlaceTile(
      place: saved.home!,
      label: 'Home',
      icon: Icons.home_outlined,
      onTap: () => onSelected(saved.home!),
    ),
  if (saved.work != null)
    PlaceTile(
      place: saved.work!,
      label: 'Work',
      icon: Icons.work_outline,
      onTap: () => onSelected(saved.work!),
    ),
  for (final p in saved.favourites)
    PlaceTile(place: p, icon: Icons.star_outline, onTap: () => onSelected(p)),
  // Recents that are already listed above as Home, Work or a favourite are skipped.
  for (final p
      in saved.recents.where((p) => saved.kindsOf(p).isEmpty).take(maxRecents))
    PlaceTile(place: p, icon: Icons.history, onTap: () => onSelected(p)),
];

IconData savedKindIcon(SavedKind kind) => switch (kind) {
  SavedKind.home => Icons.home_outlined,
  SavedKind.work => Icons.work_outline,
  SavedKind.favourite => Icons.star_outline,
};

String savedKindLabel(SavedKind kind) => switch (kind) {
  SavedKind.home => 'Home',
  SavedKind.work => 'Work',
  SavedKind.favourite => 'Favourites',
};
