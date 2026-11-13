import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lanka_maps/services/photon_geocoder.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

// Photon's GeoJSON response format (https://github.com/komoot/photon#search);
// the CI workflow checks the live service still returns these keys.
const _search = '''
{"type":"FeatureCollection","features":[
 {"type":"Feature","geometry":{"type":"Point","coordinates":[80.6337,7.2906]},
  "properties":{"osm_type":"R","osm_id":1,"osm_key":"place","osm_value":"city","type":"city",
   "name":"Kandy","state":"Central Province","country":"Sri Lanka","countrycode":"LK"}},
 {"type":"Feature","geometry":{"type":"Point","coordinates":[79.8612,6.9271]},
  "properties":{"osm_type":"N","osm_id":2,"osm_key":"tourism","osm_value":"museum","type":"house",
   "name":"Colombo National Museum","street":"Sir Marcus Fernando Mawatha","district":"Cinnamon Gardens",
   "city":"Colombo","state":"Western Province","postcode":"00700","country":"Sri Lanka","countrycode":"LK"}},
 {"type":"Feature","geometry":{"type":"Point","coordinates":[79.85,6.93]},
  "properties":{"osm_type":"W","osm_id":3,"osm_key":"building","osm_value":"yes","type":"house",
   "housenumber":"12","street":"Galle Road","city":"Colombo","country":"Sri Lanka","countrycode":"LK"}}
]}
''';

void main() {
  PhotonGeocoder geocoder(String body, {List<Uri>? requests}) => PhotonGeocoder(
    baseUrl: 'https://photon.example',
    client: MockClient((req) async {
      requests?.add(req.url);
      return http.Response.bytes(utf8.encode(body), 200);
    }),
  );

  test('search is limited to Sri Lanka and parses names and addresses', () async {
    final requests = <Uri>[];
    final places = await geocoder(
      _search,
      requests: requests,
    ).search(' Kandy ');

    expect(requests.single.path, '/api');
    expect(requests.single.queryParameters, containsPair('q', 'Kandy'));
    expect(
      requests.single.queryParameters,
      containsPair('bbox', '79.3,5.7,82.1,10.1'),
    );
    expect(requests.single.queryParameters, containsPair('lang', 'en'));

    expect(places, hasLength(3));
    expect(places[0].name, 'Kandy');
    expect(places[0].detail, 'Central Province, Sri Lanka');
    expect(places[0].location.latitude, closeTo(7.2906, 1e-9));
    expect(places[0].location.longitude, closeTo(80.6337, 1e-9));

    expect(places[1].name, 'Colombo National Museum');
    expect(
      places[1].detail,
      'Sir Marcus Fernando Mawatha, Cinnamon Gardens, Colombo, Western Province, Sri Lanka',
    );

    // No name: the street address stands in for it.
    expect(places[2].name, 'Galle Road 12');
    expect(places[2].detail, 'Colombo, Sri Lanka');
  });

  test('blank search makes no request', () async {
    final requests = <Uri>[];
    expect(await geocoder(_search, requests: requests).search('  '), isEmpty);
    expect(requests, isEmpty);
  });

  test('reverse names a tapped point but keeps its coordinates', () async {
    const tapped = LatLng(6.9272, 79.8613);
    final place = await geocoder(_search).reverse(tapped);
    expect(place!.name, 'Kandy');
    expect(place.location, tapped);
  });

  test('reverse returns null when nothing is nearby', () async {
    final place = await geocoder(
      '{"type":"FeatureCollection","features":[]}',
    ).reverse(const LatLng(8, 81));
    expect(place, isNull);
  });

  test('surfaces HTTP errors', () async {
    final g = PhotonGeocoder(
      baseUrl: 'https://photon.example',
      client: MockClient((_) async => http.Response('busy', 503)),
    );
    expect(() => g.search('Kandy'), throwsException);
  });
}
