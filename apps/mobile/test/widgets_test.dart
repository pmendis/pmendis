import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lanka_maps/main.dart';
import 'package:lanka_maps/models/place.dart';
import 'package:lanka_maps/models/route.dart';
import 'package:lanka_maps/navigation/navigation_controller.dart';
import 'package:lanka_maps/screens/place_picker_page.dart';
import 'package:lanka_maps/screens/saved_places_page.dart';
import 'package:lanka_maps/screens/settings_page.dart';
import 'package:lanka_maps/services/geocoding_service.dart';
import 'package:lanka_maps/services/routing_service.dart';
import 'package:lanka_maps/storage/app_settings.dart';
import 'package:lanka_maps/storage/saved_places.dart';
import 'package:lanka_maps/widgets/navigation_view.dart';
import 'package:lanka_maps/widgets/place_sheet.dart';
import 'package:lanka_maps/widgets/place_tiles.dart';
import 'package:lanka_maps/widgets/route_panel.dart';
import 'package:lanka_maps/widgets/save_place_sheet.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support.dart';

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(
    body: Align(alignment: Alignment.bottomCenter, child: child),
  ),
);

void main() {
  const museum = Place(
    name: 'Colombo National Museum',
    detail: 'Ward Place, Colombo',
    location: LatLng(6.9314, 79.8654),
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('place sheet shows the place and wires up its actions', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      _app(
        PlaceSheet(
          place: museum,
          savedAs: const {},
          distanceText: '2.1 km away',
          onDirections: () => calls.add('directions'),
          onSave: () => calls.add('save'),
          onGoogleMaps: () => calls.add('google'),
          onReport: () => calls.add('report'),
          onClose: () => calls.add('close'),
        ),
      ),
    );

    expect(find.text('Colombo National Museum'), findsOneWidget);
    expect(find.text('Ward Place, Colombo · 2.1 km away'), findsOneWidget);

    await tester.tap(find.text('Directions'));
    await tester.tap(find.text('Google Maps'));
    await tester.tap(find.text('Report a problem'));
    await tester.tap(find.byTooltip('Close'));
    await tester.tap(find.text('Save'));
    expect(calls, ['directions', 'google', 'report', 'close', 'save']);
  });

  testWidgets('route panel: Start needs a route and a start point', (
    tester,
  ) async {
    final route = await fixtureRoute();
    var started = 0, picked = 0;

    Widget panel({required List<RouteOption> routes, Place? origin}) => _app(
      RoutePanel(
        origin: origin,
        destination: museum,
        mode: TravelMode.car,
        routes: routes,
        selected: 0,
        loading: false,
        error: null,
        avoiding: const ['tolls'],
        onModeChanged: (_) {},
        onRouteSelected: (_) {},
        onSwap: () {},
        onClear: () {},
        onPickOrigin: () => picked++,
        onPickDestination: () {},
        onStart: () => started++,
        onGoogleMaps: () {},
      ),
    );

    await tester.pumpWidget(panel(routes: const []));
    await tester.tap(find.text('Choose start (or long-press the map)'));
    await tester.tap(find.text('Start'));
    expect(picked, 1);
    expect(started, 0);

    await tester.pumpWidget(
      panel(routes: [route], origin: Place.myLocation(fixtureFrom)),
    );
    expect(find.text('4 min'), findsOneWidget);
    expect(find.text('Avoiding tolls'), findsOneWidget);
    await tester.tap(find.text('Start'));
    expect(started, 1);
  });

  testWidgets('navigation banner and footer follow progress to arrival', (
    tester,
  ) async {
    final route = await fixtureRoute();
    final gps = ManualPositionSource();
    final nav = NavigationController(
      routing: RoutingService(
        baseUrl: 'http://gw',
        client: MockClient((_) async => http.Response(valhallaFixture, 200)),
      ),
      speech: FakeSpeech(),
      isVoiceEnabled: () => true,
    );
    var exits = 0;
    await tester.runAsync(
      () => nav.start(
        route: route,
        destination: museum,
        mode: TravelMode.car,
        source: gps,
        simulated: true,
      ),
    );

    Widget screen() => MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            NavigationBanner(nav: nav),
            const Spacer(),
            NavigationFooter(
              nav: nav,
              voiceOn: true,
              following: true,
              onToggleVoice: () {},
              onToggleOverview: () {},
              onExit: () => exits++,
            ),
          ],
        ),
      ),
    );

    await tester.runAsync(() async {
      gps.add(route.shape.first);
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpWidget(screen());
    expect(
      find.text('Turn left onto Ananda Coomaraswamy Mawatha.'),
      findsOneWidget,
    );
    expect(find.text('880 m'), findsOneWidget);
    expect(find.text('Simulated drive'), findsOneWidget);
    expect(find.text('4 min'), findsOneWidget);

    await tester.runAsync(() async {
      gps.add(route.shape[8]); // on Ward Place, the last street
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpWidget(screen());
    expect(find.text('You will arrive at your destination.'), findsOneWidget);
    expect(find.text('You have arrived'), findsNothing);

    await tester.runAsync(() async {
      gps.add(route.shape.last);
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpWidget(screen());
    expect(find.text('You have arrived'), findsOneWidget);
    await tester.tap(find.text('Done'));
    expect(exits, 1);
    await tester.runAsync(nav.stop);
  });

  testWidgets('save sheet toggles Home and favourites', (tester) async {
    final saved = SavedPlaces(await SharedPreferences.getInstance())
      ..save(
        const Place(name: 'Old home', location: LatLng(7, 80)),
        SavedKind.home,
      );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showSavePlaceSheet(context, place: museum, saved: saved),
            child: const Text('save'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();
    expect(find.text('Replaces Old home'), findsOneWidget);

    await tester.tap(find.text('Set as Home'));
    await tester.tap(find.text('Favourites'));
    await tester.pump();
    expect(saved.kindsOf(museum), {SavedKind.home, SavedKind.favourite});

    await tester.tap(find.text('Favourites'));
    await tester.pump();
    expect(saved.kindsOf(museum), {SavedKind.home});
  });

  testWidgets('saved suggestions do not repeat a favourite as a recent', (
    tester,
  ) async {
    final saved = SavedPlaces(await SharedPreferences.getInstance())
      ..save(museum, SavedKind.favourite)
      ..addRecent(museum)
      ..addRecent(
        const Place(name: 'Galle Face Green', location: LatLng(6.92, 79.84)),
      );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(children: savedPlaceTiles(saved, onSelected: (_) {})),
        ),
      ),
    );
    expect(find.text('Colombo National Museum'), findsOneWidget);
    expect(find.text('Galle Face Green'), findsOneWidget);
  });

  testWidgets('settings page toggles persist', (tester) async {
    final settings = AppSettings(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(settings: settings)),
    );
    expect(find.text('Server address'), findsOneWidget);
    for (final label in ['Voice guidance', 'Avoid tolls']) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pump();
    }

    await tester.ensureVisible(find.text('Dark'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(settings.avoidTolls, isTrue);
    expect(settings.voiceGuidance, isFalse);
    expect(settings.themeMode, ThemeMode.dark);
  });

  testWidgets('saved places page lists, removes and opens places', (
    tester,
  ) async {
    final saved = SavedPlaces(await SharedPreferences.getInstance())
      ..save(museum, SavedKind.home)
      ..addRecent(museum);
    Place? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              opened = await Navigator.of(context).push<Place>(
                MaterialPageRoute(
                  builder: (_) => SavedPlacesPage(saved: saved),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove'));
    await tester.pump();
    expect(saved.home, isNull);
    expect(find.text('Home'), findsNothing);

    await tester.tap(find.text('Colombo National Museum'));
    await tester.pumpAndSettle();
    expect(opened?.name, museum.name);
  });

  testWidgets('place picker offers your location and returns search results', (
    tester,
  ) async {
    final saved = SavedPlaces(await SharedPreferences.getInstance());
    final geocoder = GeocodingService(
      baseUrl: 'http://gw',
      client: MockClient(
        (_) async => http.Response(
          '[{"lat":"6.93","lon":"79.86","name":"Viharamahadevi Park",'
          '"display_name":"Viharamahadevi Park, Colombo, Sri Lanka"}]',
          200,
        ),
      ),
    );
    final result = Completer<Place?>();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result.complete(
              await Navigator.of(context).push<Place>(
                MaterialPageRoute(
                  builder: (_) => PlacePickerPage(
                    title: 'Choose start',
                    geocoder: geocoder,
                    saved: saved,
                    myLocation: Place.myLocation(fixtureFrom),
                  ),
                ),
              ),
            ),
            child: const Text('pick'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    expect(find.text('Your location'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'park');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Viharamahadevi Park'));
    await tester.pumpAndSettle();

    final place = await result.future;
    expect(place!.name, 'Viharamahadevi Park');
    expect(saved.recents.single.name, 'Viharamahadevi Park');
  });

  testWidgets('startup errors are shown instead of a stuck splash', (
    tester,
  ) async {
    await tester.pumpWidget(
      StartupErrorApp(error: Exception('prefs unavailable')),
    );
    expect(find.text('Lanka Maps could not start'), findsOneWidget);
    expect(find.textContaining('prefs unavailable'), findsOneWidget);
  });
}
