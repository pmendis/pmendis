import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app_services.dart';
import '../config.dart';
import '../format.dart';
import '../models/place.dart';
import '../models/route.dart';
import '../navigation/geo.dart';
import '../navigation/navigation_controller.dart';
import '../navigation/position_source.dart';
import '../services/backend.dart';
import '../services/external_navigation.dart';
import '../services/http_headers.dart';
import '../widgets/navigation_view.dart';
import '../widgets/place_sheet.dart';
import '../widgets/report_problem_dialog.dart';
import '../widgets/route_panel.dart';
import '../widgets/save_place_sheet.dart';
import '../widgets/search_box.dart';
import 'about_page.dart';
import 'place_picker_page.dart';
import 'saved_places_page.dart';
import 'settings_page.dart' show SettingsPage, showBackendDialog;

/// What the bottom of the screen is showing.
enum _View { browse, place, directions, navigating }

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  AppServices get _services => widget.services;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final NavigationController _nav;

  MapLibreMapController? _map;
  bool _layersReady = false;
  CameraPosition _camera = const CameraPosition(
    target: sriLankaCenter,
    zoom: 7,
  );

  Brightness? _styleBrightness;
  String? _style;
  String? _styleError;
  Backend? _loadedBackend;

  bool _locationGranted = false;
  LatLng? _myLocation;

  _View _view = _View.browse;
  Place? _place;
  Place? _origin;
  Place? _destination;
  late TravelMode _mode = _services.settings.travelMode;
  List<RouteOption> _routes = const [];
  int _selected = 0;
  bool _loading = false;
  String? _routeError;
  int _routeRequest = 0;
  late RouteAvoid _avoid = _services.settings.avoid;

  bool _following = true;
  LatLng? _lastFollowTarget;

  @override
  void initState() {
    super.initState();
    _nav = NavigationController(
      routing: _services.routing,
      speech: _services.speech,
      isVoiceEnabled: () => _services.settings.voiceGuidance,
      routeAvoid: () => _services.settings.avoid,
    )..addListener(_onNavigationChanged);
    _services.settings.addListener(_onSettingsChanged);
    _initLocation();
  }

  @override
  void dispose() {
    _services.settings.removeListener(_onSettingsChanged);
    _nav
      ..removeListener(_onNavigationChanged)
      ..dispose();
    _keepScreenOn(false);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (brightness != _styleBrightness) {
      _styleBrightness = brightness;
      _loadStyle(brightness);
    }
  }

  void _onSettingsChanged() {
    if (_services.settings.backend != _loadedBackend) {
      _loadStyle(_styleBrightness ?? Brightness.light);
    }
    final avoid = _services.settings.avoid;
    final changed =
        avoid.tolls != _avoid.tolls ||
        avoid.highways != _avoid.highways ||
        avoid.ferries != _avoid.ferries;
    _avoid = avoid;
    if (changed && _view == _View.directions) _updateRoute();
  }

  // ---------------------------------------------------------------- style

  /// Fetches the style from the gateway and points its tile URLs at it.
  /// Fetches the map style for the current data source. For an own server
  /// the style's tile URLs point back at that server.
  Future<void> _loadStyle(Brightness brightness) async {
    final backend = _services.settings.backend;
    final url = backend.styleUrl(brightness);
    _loadedBackend = backend;
    setState(() => _styleError = null);
    try {
      final res = await http
          .get(Uri.parse(url), headers: apiHeaders)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      if (!mounted) return;
      setState(() {
        _layersReady = false;
        _style = backend.isPublic
            ? res.body
            : res.body.replaceAll('{{BASE_URL}}', backend.serverUrl!);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _styleError = 'Cannot load the map from $url\n$e');
    }
  }

  Future<void> _onStyleLoaded() async {
    final map = _map;
    if (map == null) return;
    const empty = {'type': 'FeatureCollection', 'features': <Object>[]};
    await map.addGeoJsonSource('routes', empty);
    await map.addGeoJsonSource('endpoints', empty);
    await map.addGeoJsonSource('puck', empty);
    Future<void> addLine(
      String id,
      String color,
      double width,
      bool selected,
    ) => map.addLineLayer(
      'routes',
      id,
      LineLayerProperties(
        lineColor: color,
        lineWidth: width,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: [
        '==',
        ['get', 'selected'],
        selected,
      ],
    );
    await addLine('route-alternates', '#9aa5b1', 6, false);
    await addLine('route-casing', '#0b4fb3', 10, true);
    await addLine('route-selected', '#2a7bf6', 7, true);
    await map.addCircleLayer(
      'endpoints',
      'endpoints',
      const CircleLayerProperties(
        circleRadius: 8,
        circleColor: ['get', 'color'],
        circleStrokeColor: '#ffffff',
        circleStrokeWidth: 3,
      ),
    );
    await map.addCircleLayer(
      'puck',
      'puck',
      const CircleLayerProperties(
        circleRadius: 10,
        circleColor: '#1a73e8',
        circleStrokeColor: '#ffffff',
        circleStrokeWidth: 4,
      ),
    );
    _layersReady = true;
    await _syncMap();
  }

  /// Pushes routes, markers and the navigation puck into the map sources.
  Future<void> _syncMap() async {
    final map = _map;
    if (map == null || !_layersReady) return;

    List<double> coords(LatLng p) => [p.longitude, p.latitude];
    Map<String, Object> point(LatLng p, String color) => {
      'type': 'Feature',
      'properties': {'color': color},
      'geometry': {'type': 'Point', 'coordinates': coords(p)},
    };
    Map<String, Object> lineFeature(RouteOption r, bool selected) => {
      'type': 'Feature',
      'properties': {'selected': selected},
      'geometry': {
        'type': 'LineString',
        'coordinates': [for (final p in r.shape) coords(p)],
      },
    };
    const green = '#2e7d32', red = '#c62828';

    final lines = <Map<String, Object>>[];
    final points = <Map<String, Object>>[];
    final puck = <Map<String, Object>>[];
    switch (_view) {
      case _View.browse:
        break;
      case _View.place:
        if (_place != null) points.add(point(_place!.location, red));
      case _View.directions:
        // Alternates first so the selected route is drawn on top.
        for (var i = 0; i < _routes.length; i++) {
          if (i != _selected) lines.add(lineFeature(_routes[i], false));
        }
        if (_routes.isNotEmpty) {
          lines.add(lineFeature(_routes[_selected], true));
        }
        if (_origin case final o?) points.add(point(o.location, green));
        if (_destination case final d?) points.add(point(d.location, red));
      case _View.navigating:
        final route = _nav.route;
        if (route != null) lines.add(lineFeature(route, true));
        final dest = _nav.destination;
        if (dest != null) points.add(point(dest.location, red));
        final progress = _nav.progress;
        if (progress != null) puck.add(point(progress.snapped, '#1a73e8'));
    }

    Map<String, Object> collection(List<Map<String, Object>> features) => {
      'type': 'FeatureCollection',
      'features': features,
    };
    await map.setGeoJsonSource('routes', collection(lines));
    await map.setGeoJsonSource('endpoints', collection(points));
    await map.setGeoJsonSource('puck', collection(puck));
  }

  // ------------------------------------------------------------- location

  Future<void> _initLocation({bool moveCamera = false}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      if (mounted) setState(() => _locationGranted = true);
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));
      if (moveCamera) {
        await _map?.animateCamera(CameraUpdate.newLatLngZoom(_myLocation!, 15));
      }
    } catch (_) {
      // Location is optional: the user can still choose a start point.
    }
  }

  Place? get _myLocationPlace =>
      _myLocation == null ? null : Place.myLocation(_myLocation!);

  // ------------------------------------------------------------- browsing

  /// On web, taps on dialogs, sheets and the drawer also reach the map
  /// element underneath; ignore those.
  bool get _mapCovered =>
      !(ModalRoute.of(context)?.isCurrent ?? true) ||
      (_scaffoldKey.currentState?.isDrawerOpen ?? false);

  void _onMapClick(LatLng latLng) {
    if (_mapCovered) return;
    switch (_view) {
      case _View.browse:
      case _View.place:
        _showPlace(
          Place.fromCoordinates(latLng),
          moveCamera: false,
          lookUpName: true,
        );
      case _View.directions:
        _setDestination(Place.fromCoordinates(latLng), lookUpName: true);
      case _View.navigating:
        break;
    }
  }

  void _onMapLongClick(LatLng latLng) {
    if (_mapCovered) return;
    if (_view == _View.directions) {
      _setOrigin(Place.fromCoordinates(latLng), lookUpName: true);
    } else if (_view != _View.navigating) {
      _onMapClick(latLng);
    }
  }

  void _showPlace(
    Place place, {
    bool moveCamera = true,
    bool lookUpName = false,
  }) {
    setState(() {
      _view = _View.place;
      _place = place;
    });
    _syncMap();
    if (moveCamera) {
      _map?.animateCamera(CameraUpdate.newLatLngZoom(place.location, 16));
    }
    if (lookUpName) {
      _nameTappedPlace(place, (named) {
        if (identical(_place, place)) _place = named;
      });
    }
  }

  void _onSearchSelected(Place place) {
    _services.saved.addRecent(place);
    _showPlace(place);
  }

  /// Replaces the coordinate label of a tapped point with a place name.
  Future<void> _nameTappedPlace(
    Place place,
    void Function(Place named) apply,
  ) async {
    try {
      final named = await _services.geocoder.reverse(place.location);
      if (named == null || !mounted) return;
      setState(() => apply(named));
      _syncMap();
    } catch (_) {
      // Keep the coordinate label.
    }
  }

  Future<void> _report(LatLng location, {String? placeName}) async {
    final url = await showReportProblemDialog(
      context,
      notes: _services.notes,
      location: location,
      placeName: placeName,
    );
    if (url == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Thanks! Your report was sent to OpenStreetMap mappers.',
        ),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => openWebPage(url),
        ),
      ),
    );
  }

  Future<void> _openGoogleMaps(LatLng destination, {LatLng? origin}) async {
    final ok = await openInGoogleMaps(
      destination: destination,
      origin: origin,
      mode: _mode,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  // ----------------------------------------------------------- directions

  void _openDirections(Place destination) {
    setState(() {
      _view = _View.directions;
      _destination = destination;
      _origin = _myLocationPlace;
    });
    _updateRoute(fitCamera: true);
  }

  void _setOrigin(Place place, {bool lookUpName = false}) {
    setState(() => _origin = place);
    if (lookUpName) {
      _nameTappedPlace(place, (named) {
        if (identical(_origin, place)) _origin = named;
      });
    }
    _updateRoute(fitCamera: true);
  }

  void _setDestination(Place place, {bool lookUpName = false}) {
    setState(() {
      _destination = place;
      _origin ??= _myLocationPlace;
    });
    if (lookUpName) {
      _nameTappedPlace(place, (named) {
        if (identical(_destination, place)) _destination = named;
      });
    }
    _updateRoute(fitCamera: true);
  }

  Future<void> _pickEndpoint({required bool origin}) async {
    final place = await Navigator.of(context).push<Place>(
      MaterialPageRoute(
        builder: (_) => PlacePickerPage(
          title: origin ? 'Choose start' : 'Choose destination',
          geocoder: _services.geocoder,
          saved: _services.saved,
          myLocation: _myLocationPlace,
        ),
      ),
    );
    if (place == null || !mounted) return;
    origin ? _setOrigin(place) : _setDestination(place);
  }

  void _swap() {
    setState(() {
      final o = _origin;
      _origin = _destination;
      _destination = o;
    });
    _updateRoute();
  }

  void _closeDirections() {
    _routeRequest++;
    final dest = _destination;
    setState(() {
      _origin = null;
      _destination = null;
      _routes = const [];
      _selected = 0;
      _loading = false;
      _routeError = null;
      _view = dest == null ? _View.browse : _View.place;
      _place = dest;
    });
    _syncMap();
  }

  void _selectRoute(int index) {
    setState(() => _selected = index);
    _syncMap();
  }

  Future<void> _updateRoute({bool fitCamera = false}) async {
    final from = _origin, to = _destination;
    final id = ++_routeRequest;
    setState(() {
      _routes = const [];
      _selected = 0;
      _routeError = null;
      _loading = from != null && to != null;
    });
    await _syncMap();
    if (from == null || to == null) return;

    try {
      final routes = await _services.routing.route(
        from.location,
        to.location,
        mode: _mode,
        avoid: _services.settings.avoid,
      );
      if (!mounted || id != _routeRequest) return;
      setState(() {
        _routes = routes;
        _loading = false;
      });
      await _syncMap();
      if (fitCamera) _fitBounds(routes.first.bounds);
    } catch (e) {
      if (!mounted || id != _routeRequest) return;
      setState(() {
        _loading = false;
        _routeError = '$e';
      });
    }
  }

  void _fitBounds(LatLngBounds bounds) {
    _map?.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        left: 48,
        top: 120,
        right: 48,
        bottom: 48,
      ),
    );
  }

  List<String> get _avoidingLabels {
    final a = _services.settings.avoid;
    return [
      if (a.tolls && _mode == TravelMode.car) 'tolls',
      if (a.highways && _mode == TravelMode.car) 'highways',
      if (a.ferries) 'ferries',
    ];
  }

  // ----------------------------------------------------------- navigation

  Future<void> _startNavigation() async {
    final origin = _origin, destination = _destination;
    if (origin == null || destination == null || _routes.isEmpty) return;
    final route = _routes[_selected];
    final settings = _services.settings;
    final useGps =
        origin.isMyLocation && _locationGranted && !settings.simulateNavigation;

    final PositionSource source = useGps
        ? GpsPositionSource()
        : SimulatedPositionSource(
            route.shape,
            metersPerSecond: switch (_mode) {
              TravelMode.car => 20,
              TravelMode.bicycle => 7,
              TravelMode.walk => 3,
            },
          );
    if (!useGps && !settings.simulateNavigation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The start is not your current location, so the drive is simulated.',
          ),
        ),
      );
    }

    setState(() {
      _view = _View.navigating;
      _following = true;
      _lastFollowTarget = null;
    });
    await _nav.start(
      route: route,
      destination: destination,
      mode: _mode,
      source: source,
      simulated: !useGps,
    );
    _keepScreenOn(true);
    _map?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: route.shape.first,
          zoom: _navigationZoom,
          tilt: 50,
          bearing: route.shape.length > 1
              ? bearingDegrees(route.shape[0], route.shape[1])
              : 0,
        ),
      ),
    );
  }

  /// Browsers may refuse a wake lock (e.g. without a user gesture); the
  /// screen then just follows its normal timeout.
  Future<void> _keepScreenOn(bool on) async {
    try {
      await (on ? WakelockPlus.enable() : WakelockPlus.disable());
    } catch (_) {}
  }

  double get _navigationZoom => _mode == TravelMode.car ? 17 : 18;

  void _onNavigationChanged() {
    if (_view != _View.navigating || !mounted) return;
    setState(() {});
    _syncMap();
    final progress = _nav.progress;
    if (_following &&
        progress != null &&
        progress.snapped != _lastFollowTarget) {
      _lastFollowTarget = progress.snapped;
      _map?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: progress.snapped,
            zoom: _navigationZoom,
            tilt: 50,
            bearing: _nav.heading,
          ),
        ),
        duration: const Duration(milliseconds: 900),
      );
    }
  }

  void _toggleOverview() {
    final route = _nav.route;
    setState(() => _following = !_following);
    if (!_following && route != null) {
      _showFlat(route.bounds);
    } else {
      _lastFollowTarget = null;
      _onNavigationChanged();
    }
  }

  /// Fits [bounds] with the map facing north and not tilted.
  Future<void> _showFlat(LatLngBounds bounds) async {
    final map = _map;
    if (map == null) return;
    await map.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: map.cameraPosition?.target ?? _camera.target,
          zoom: map.cameraPosition?.zoom ?? _camera.zoom,
        ),
      ),
    );
    _fitBounds(bounds);
  }

  Future<void> _exitNavigation() async {
    final arrived = _nav.hasArrived;
    await _nav.stop();
    _keepScreenOn(false);
    if (!mounted) return;
    setState(() => _view = _View.directions);
    await _syncMap();
    if (arrived) {
      _closeDirections();
      final dest = _place;
      if (dest != null) {
        _map?.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: dest.location, zoom: 16),
          ),
        );
      }
    } else if (_routes.isNotEmpty) {
      _showFlat(_routes[_selected].bounds);
    }
  }

  // ------------------------------------------------------------------- UI

  void _back() {
    switch (_view) {
      case _View.navigating:
        _exitNavigation();
      case _View.directions:
        _closeDirections();
      case _View.place:
        setState(() {
          _view = _View.browse;
          _place = null;
        });
        _syncMap();
      case _View.browse:
        break;
    }
  }

  Future<void> _openPage(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final navigating = _view == _View.navigating;

    return PopScope(
      canPop: _view == _View.browse,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _buildDrawer(),
        drawerEnableOpenDragGesture: false,
        // The bottom panel sits below the map rather than over it, so the
        // map's own controls (compass, attribution) are never hidden.
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  _buildMap(),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      // On web the map is an HTML element underneath Flutter;
                      // the interceptor stops taps on overlays reaching it.
                      child: PointerInterceptor(
                        child: navigating
                            ? NavigationBanner(nav: _nav)
                            : SearchBox(
                                geocoder: _services.geocoder,
                                saved: _services.saved,
                                onSelected: _onSearchSelected,
                                onMenu: () =>
                                    _scaffoldKey.currentState?.openDrawer(),
                              ),
                      ),
                    ),
                  ),
                  if (!navigating)
                    Positioned(
                      right: 16,
                      bottom: 48,
                      child: PointerInterceptor(
                        child: FloatingActionButton(
                          heroTag: 'my-location',
                          tooltip: 'My location',
                          onPressed: () {
                            if (_myLocation != null) {
                              _map?.animateCamera(
                                CameraUpdate.newLatLngZoom(_myLocation!, 15),
                              );
                            } else {
                              _initLocation(moveCamera: true);
                            }
                          },
                          child: const Icon(Icons.my_location),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_buildBottom() case final bottom?)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                ),
                child: PointerInterceptor(child: bottom),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    final style = _style;
    if (style == null) {
      return _StatusView(
        message: _styleError ?? 'Loading map…',
        onRetry: _styleError == null
            ? null
            : () => _loadStyle(_styleBrightness ?? Brightness.light),
        onChangeServer: _styleError == null
            ? null
            : () => showBackendDialog(context, _services.settings),
      );
    }
    return MapLibreMap(
      // A new style string needs a fresh map so layers are re-added.
      key: ValueKey(style.hashCode),
      styleString: style,
      initialCameraPosition: _camera,
      trackCameraPosition: true,
      cameraTargetBounds: CameraTargetBounds(sriLankaBounds),
      minMaxZoomPreference: const MinMaxZoomPreference(6, 19),
      // On web this would add a second locate button; the FAB covers it.
      // While navigating the route puck replaces the device's own marker.
      myLocationEnabled:
          _locationGranted && !kIsWeb && _view != _View.navigating,
      compassEnabled: true,
      compassViewPosition: CompassViewPosition.bottomLeft,
      onMapCreated: (c) => _map = c,
      onStyleLoadedCallback: _onStyleLoaded,
      onCameraIdle: () {
        final position = _map?.cameraPosition;
        if (position != null) _camera = position;
      },
      onMapClick: (_, latLng) => _onMapClick(latLng),
      onMapLongClick: (_, latLng) => _onMapLongClick(latLng),
    );
  }

  Widget? _buildBottom() {
    switch (_view) {
      case _View.browse:
        return null;
      case _View.place:
        final place = _place!;
        return ListenableBuilder(
          listenable: _services.saved,
          builder: (context, _) => PlaceSheet(
            place: place,
            savedAs: _services.saved.kindsOf(place),
            distanceText: _myLocation == null
                ? null
                : '${formatDistance(distanceMeters(_myLocation!, place.location) / 1000)} away',
            onDirections: () => _openDirections(place),
            onSave: () => showSavePlaceSheet(
              context,
              place: place,
              saved: _services.saved,
            ),
            onGoogleMaps: () => _openGoogleMaps(place.location),
            onReport: () => _report(
              place.location,
              placeName: place.isCoordinates ? null : place.name,
            ),
            onClose: _back,
          ),
        );
      case _View.directions:
        return RoutePanel(
          origin: _origin,
          destination: _destination,
          mode: _mode,
          routes: _routes,
          selected: _selected,
          loading: _loading,
          error: _routeError,
          avoiding: _avoidingLabels,
          onModeChanged: (mode) {
            setState(() => _mode = mode);
            _services.settings.travelMode = mode;
            _updateRoute();
          },
          onRouteSelected: _selectRoute,
          onSwap: _swap,
          onClear: _closeDirections,
          onPickOrigin: () => _pickEndpoint(origin: true),
          onPickDestination: () => _pickEndpoint(origin: false),
          onStart: _startNavigation,
          onGoogleMaps: () => _openGoogleMaps(
            _destination!.location,
            origin: _origin == null || _origin!.isMyLocation
                ? null
                : _origin!.location,
          ),
        );
      case _View.navigating:
        return ListenableBuilder(
          listenable: _services.settings,
          builder: (context, _) => NavigationFooter(
            nav: _nav,
            voiceOn: _services.settings.voiceGuidance,
            following: _following,
            onToggleVoice: () {
              final settings = _services.settings;
              settings.voiceGuidance = !settings.voiceGuidance;
              if (!settings.voiceGuidance) _services.speech.stop();
            },
            onToggleOverview: _toggleOverview,
            onExit: _exitNavigation,
          ),
        );
    }
  }

  Widget _buildDrawer() {
    void close() => Navigator.of(context).pop();
    return PointerInterceptor(
      child: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Text(
                  'Lanka Maps',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_border),
                title: const Text('Saved places'),
                onTap: () async {
                  close();
                  final place = await Navigator.of(context).push<Place>(
                    MaterialPageRoute(
                      builder: (_) => SavedPlacesPage(saved: _services.saved),
                    ),
                  );
                  if (place != null && mounted) _showPlace(place);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report a map problem here'),
                subtitle: const Text('At the centre of the map'),
                onTap: () {
                  close();
                  _report(_map?.cameraPosition?.target ?? _camera.target);
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                onTap: () {
                  close();
                  _openPage(SettingsPage(settings: _services.settings));
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About & map data'),
                onTap: () {
                  close();
                  _openPage(const AboutPage());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({required this.message, this.onRetry, this.onChangeServer});

  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onChangeServer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onRetry == null) const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
            if (onChangeServer != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onChangeServer,
                child: const Text('Map data source'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
