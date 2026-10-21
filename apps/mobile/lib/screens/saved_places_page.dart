import 'package:flutter/material.dart';

import '../models/place.dart';
import '../storage/saved_places.dart';
import '../widgets/place_tiles.dart';

/// Home, Work and favourites. Tapping one returns it to show on the map.
class SavedPlacesPage extends StatelessWidget {
  const SavedPlacesPage({super.key, required this.saved});

  final SavedPlaces saved;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved places')),
      body: ListenableBuilder(
        listenable: saved,
        builder: (context, _) {
          void open(Place p) => Navigator.of(context).pop(p);
          Widget remove(Place p, SavedKind kind) => IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => saved.remove(p, kind),
          );

          final empty =
              saved.home == null &&
              saved.work == null &&
              saved.favourites.isEmpty;
          return ListView(
            children: [
              if (empty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No saved places yet. Open a place on the map and tap Save '
                    'to keep it here, or set it as Home or Work.',
                  ),
                ),
              if (saved.home != null)
                PlaceTile(
                  place: saved.home!,
                  label: 'Home',
                  icon: Icons.home_outlined,
                  onTap: () => open(saved.home!),
                  trailing: remove(saved.home!, SavedKind.home),
                ),
              if (saved.work != null)
                PlaceTile(
                  place: saved.work!,
                  label: 'Work',
                  icon: Icons.work_outline,
                  onTap: () => open(saved.work!),
                  trailing: remove(saved.work!, SavedKind.work),
                ),
              if (saved.favourites.isNotEmpty) const _Header('Favourites'),
              for (final p in saved.favourites)
                PlaceTile(
                  place: p,
                  icon: Icons.star_outline,
                  onTap: () => open(p),
                  trailing: remove(p, SavedKind.favourite),
                ),
              if (saved.recents.isNotEmpty) ...[
                _Header(
                  'Recent',
                  action: TextButton(
                    onPressed: saved.clearRecents,
                    child: const Text('Clear'),
                  ),
                ),
                for (final p in saved.recents)
                  PlaceTile(
                    place: p,
                    icon: Icons.history,
                    onTap: () => open(p),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text, {this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleSmall),
        ),
        ?action,
      ],
    ),
  );
}
