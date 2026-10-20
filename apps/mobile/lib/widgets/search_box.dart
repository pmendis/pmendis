import 'dart:async';

import 'package:flutter/material.dart';

import '../models/place.dart';
import '../services/geocoding_service.dart';

/// Search field with debounced suggestions shown underneath.
class SearchBox extends StatefulWidget {
  const SearchBox({
    super.key,
    required this.geocoder,
    required this.onSelected,
  });

  final GeocodingService geocoder;
  final ValueChanged<Place> onSelected;

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  int _requestId = 0;
  List<Place> _results = const [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    if (text.trim().length < 2) {
      _requestId++;
      setState(() {
        _results = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(text));
  }

  Future<void> _search(String text) async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.geocoder.search(text);
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = results;
        _loading = false;
        _error = results.isEmpty ? 'No places found' : null;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = const [];
        _loading = false;
        _error = 'Search is unavailable';
      });
    }
  }

  void _select(Place place) {
    _requestId++;
    _controller.clear();
    _focus.unfocus();
    setState(() {
      _results = const [];
      _error = null;
    });
    widget.onSelected(place);
  }

  @override
  Widget build(BuildContext context) {
    final showResults = _results.isNotEmpty || _error != null;
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
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              if (_results.isNotEmpty) _select(_results.first);
            },
            decoration: InputDecoration(
              hintText: 'Search places in Sri Lanka',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _controller.clear();
                        _onChanged('');
                      },
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          if (showResults) const Divider(height: 1),
          if (_error != null) ListTile(dense: true, title: Text(_error!)),
          if (_results.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final place in _results)
                    ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(place.name),
                      subtitle: place.detail == null
                          ? null
                          : Text(
                              place.detail!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: () => _select(place),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
