import 'package:flutter/material.dart';

import '../models/place.dart';
import '../services/geocoder.dart';
import '../storage/saved_places.dart';
import '../widgets/place_search.dart';
import '../widgets/place_tiles.dart';

/// Full-screen search used to choose a route's start or destination.
class PlacePickerPage extends StatefulWidget {
  const PlacePickerPage({
    super.key,
    required this.title,
    required this.geocoder,
    required this.saved,
    this.myLocation,
  });

  final String title;
  final Geocoder geocoder;
  final SavedPlaces saved;

  /// Offered as the first choice when known.
  final Place? myLocation;

  @override
  State<PlacePickerPage> createState() => _PlacePickerPageState();
}

class _PlacePickerPageState extends State<PlacePickerPage> {
  late final _search = PlaceSearch(widget.geocoder);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _pick(Place place) {
    if (!place.isMyLocation) widget.saved.addRecent(place);
    Navigator.of(context).pop(place);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          onChanged: (text) => _search.query = text,
          decoration: InputDecoration(
            hintText: widget.title,
            border: InputBorder.none,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([_search, widget.saved]),
        builder: (context, _) {
          final typing = _search.query.trim().length >= 2;
          return ListView(
            children: [
              if (_search.loading) const LinearProgressIndicator(),
              if (!typing) ...[
                if (widget.myLocation != null)
                  ListTile(
                    leading: const Icon(Icons.my_location),
                    title: const Text('Your location'),
                    onTap: () => _pick(widget.myLocation!),
                  ),
                ...savedPlaceTiles(widget.saved, onSelected: _pick),
              ] else ...[
                if (_search.error != null)
                  ListTile(title: Text(_search.error!)),
                for (final place in _search.results)
                  PlaceTile(place: place, onTap: () => _pick(place)),
              ],
            ],
          );
        },
      ),
    );
  }
}
