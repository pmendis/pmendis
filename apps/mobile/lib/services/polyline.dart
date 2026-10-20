import 'package:maplibre_gl/maplibre_gl.dart';

/// Decodes an encoded polyline (Google algorithm). Valhalla uses precision 6.
List<LatLng> decodePolyline(String encoded, {int precision = 6}) {
  final factor = _pow10(precision);
  final points = <LatLng>[];
  var index = 0, lat = 0, lng = 0;

  int nextValue() {
    var result = 0, shift = 0, byte = 0;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }

  while (index < encoded.length) {
    lat += nextValue();
    lng += nextValue();
    points.add(LatLng(lat / factor, lng / factor));
  }
  return points;
}

int _pow10(int n) {
  var v = 1;
  for (var i = 0; i < n; i++) {
    v *= 10;
  }
  return v;
}
