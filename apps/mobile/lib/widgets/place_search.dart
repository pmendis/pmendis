import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/place.dart';
import '../services/geocoding_service.dart';

/// Debounced place search shared by the search bar and the place picker.
class PlaceSearch extends ChangeNotifier {
  PlaceSearch(this._geocoder);

  final GeocodingService _geocoder;
  Timer? _debounce;
  int _requestId = 0;

  String _query = '';
  List<Place> results = const [];
  bool loading = false;
  String? error;

  String get query => _query;

  set query(String text) {
    _query = text;
    _debounce?.cancel();
    if (text.trim().length < 2) {
      _requestId++;
      results = const [];
      loading = false;
      error = null;
      notifyListeners();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(text));
  }

  void clear() => query = '';

  Future<void> _search(String text) async {
    final id = ++_requestId;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final found = await _geocoder.search(text);
      if (id != _requestId) return;
      results = found;
      error = found.isEmpty ? 'No places found' : null;
    } catch (_) {
      if (id != _requestId) return;
      results = const [];
      error = 'Search is unavailable';
    }
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _requestId++;
    super.dispose();
  }
}
