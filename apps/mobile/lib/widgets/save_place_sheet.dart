import 'package:flutter/material.dart';

import '../models/place.dart';
import '../storage/saved_places.dart';
import 'place_tiles.dart';

/// Bottom sheet to save [place] as Home, Work and/or a favourite.
Future<void> showSavePlaceSheet(
  BuildContext context, {
  required Place place,
  required SavedPlaces saved,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) => ListenableBuilder(
    listenable: saved,
    builder: (context, _) {
      final kinds = saved.kindsOf(place);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Save ${place.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final kind in SavedKind.values)
              CheckboxListTile(
                secondary: Icon(savedKindIcon(kind)),
                title: Text(
                  kind == SavedKind.favourite
                      ? 'Favourites'
                      : 'Set as ${savedKindLabel(kind)}',
                ),
                subtitle: switch (kind) {
                  SavedKind.home
                      when saved.home != null && !kinds.contains(kind) =>
                    Text('Replaces ${saved.home!.name}'),
                  SavedKind.work
                      when saved.work != null && !kinds.contains(kind) =>
                    Text('Replaces ${saved.work!.name}'),
                  _ => null,
                },
                value: kinds.contains(kind),
                onChanged: (on) =>
                    on! ? saved.save(place, kind) : saved.remove(place, kind),
              ),
          ],
        ),
      );
    },
  ),
);
