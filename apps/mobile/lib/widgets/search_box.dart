import 'package:flutter/material.dart';

import '../models/place.dart';
import '../services/geocoder.dart';
import '../storage/saved_places.dart';
import 'place_search.dart';
import 'place_tiles.dart';

/// The floating search bar: search results while typing, and saved and
/// recent places when focused with nothing typed.
class SearchBox extends StatefulWidget {
  const SearchBox({
    super.key,
    required this.geocoder,
    required this.saved,
    required this.onSelected,
    required this.onMenu,
  });

  final Geocoder geocoder;
  final SavedPlaces saved;
  final ValueChanged<Place> onSelected;
  final VoidCallback onMenu;

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late final _search = PlaceSearch(widget.geocoder);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _select(Place place) {
    _controller.clear();
    _search.clear();
    // primaryFocus also covers web, where the tap can leave focus elsewhere.
    _focus.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onSelected(place);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_search, widget.saved]),
      builder: (context, _) {
        final typing = _search.query.trim().length >= 2;
        final suggestions = !typing && _focus.hasFocus
            ? savedPlaceTiles(widget.saved, onSelected: _select, maxRecents: 5)
            : const <Widget>[];
        final results = typing
            ? [
                if (_search.error != null)
                  ListTile(dense: true, title: Text(_search.error!)),
                for (final place in _search.results)
                  PlaceTile(place: place, onTap: () => _select(place)),
              ]
            : suggestions;

        return Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _controller,
                focusNode: _focus,
                onChanged: (text) => _search.query = text,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) {
                  if (_search.results.isNotEmpty) {
                    _select(_search.results.first);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Search places in Sri Lanka',
                  prefixIcon: IconButton(
                    tooltip: 'Menu',
                    icon: const Icon(Icons.menu),
                    onPressed: widget.onMenu,
                  ),
                  suffixIcon: _search.loading
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _controller.text.isEmpty
                      ? const Icon(Icons.search)
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _controller.clear();
                            _search.clear();
                          },
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              if (results.isNotEmpty) ...[
                const Divider(height: 1),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: results,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
