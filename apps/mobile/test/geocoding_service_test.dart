import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lanka_maps/services/geocoding_service.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  // Real Nominatim 5.3 responses from the Colombo test extract.
  final searchFixture = File(
    'test/fixtures/nominatim_search.json',
  ).readAsStringSync();
  final reverseFixture = File(
    'test/fixtures/nominatim_reverse.json',
  ).readAsStringSync();

  GeocodingService serviceReturning(String body, {List<Uri>? requests}) =>
      GeocodingService(
        baseUrl: 'http://gw',
        client: MockClient((req) async {
          requests?.add(req.url);
          return http.Response.bytes(utf8.encode(body), 200);
        }),
      );

  test('search limits results to Sri Lanka and parses places', () async {
    final requests = <Uri>[];
    final places = await serviceReturning(
      searchFixture,
      requests: requests,
    ).search(' museum ');

    expect(requests.single.path, '/geocode/search');
    expect(requests.single.queryParameters, containsPair('q', 'museum'));
    expect(requests.single.queryParameters, containsPair('countrycodes', 'lk'));
    expect(places, hasLength(1));
    expect(places.single.name, 'Colombo National Museum');
    expect(places.single.detail, 'Ward Place, Colombo, Sri Lanka');
    expect(places.single.location.latitude, closeTo(6.9314, 1e-9));
    expect(places.single.location.longitude, closeTo(79.8654, 1e-9));
  });

  test('blank search makes no request', () async {
    final requests = <Uri>[];
    final places = await serviceReturning(
      '[]',
      requests: requests,
    ).search('  ');
    expect(places, isEmpty);
    expect(requests, isEmpty);
  });

  test('reverse names a tapped point but keeps its coordinates', () async {
    const tapped = LatLng(6.9311, 79.8651);
    final place = await serviceReturning(reverseFixture).reverse(tapped);

    expect(place!.name, 'Havelock Road');
    expect(place.detail, 'Colombo, Sri Lanka');
    expect(place.location, tapped);
  });

  test('reverse returns null when nothing is found', () async {
    final place = await serviceReturning(
      '{"error":"Unable to geocode"}',
    ).reverse(const LatLng(6, 80));
    expect(place, isNull);
  });

  test('reverse ignores country-level matches', () async {
    final place = await serviceReturning(
      '{"lat":"8.08","lon":"80.43","place_rank":4,"name":"Sri Lanka",'
      '"display_name":"Sri Lanka"}',
    ).reverse(const LatLng(8.5, 81));
    expect(place, isNull);
  });
}
