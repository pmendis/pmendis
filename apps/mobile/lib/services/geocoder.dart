import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/place.dart';

/// Place search and reverse lookup, whichever service provides it.
abstract class Geocoder {
  Future<List<Place>> search(String query);

  /// The nearest named place, or null when nothing is close enough.
  Future<Place?> reverse(LatLng location);
}
