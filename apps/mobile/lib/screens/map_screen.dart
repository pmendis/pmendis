import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../config.dart';
import '../models/place.dart';
import '../models/route.dart';
import '../services/geocoding_service.dart';
import '../services/routing_service.dart';
import '../widgets/route_panel.dart';
import '../widgets/search_box.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _routing = RoutingService(baseUrl: apiBaseUrl);
  final _geocoder = GeocodingService(baseUrl: apiBaseUrl);

  MapLibreMapController? _map;
  bool _layersReady = false;

  Brightness? _styleBrightness;
  String? _style;
  String? _styleError;

  bool _locationGranted = false;
  LatLng? _myLocation;

  Place? _origin;
  Place? _destination;
  TravelMode _mode = TravelMode.car;
  List<RouteOption> _routes = const [];
  int _selected = 0;
  bool _loading = false;
  String? _routeError;
  int _routeRequest = 0;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = MediaQuery.platformBrightnessOf(context);
    if (brightness != _styleBrightness) {
      _styleBrightness = brightness;
      _loadStyle(brightness);
    }
  }

  // ---------------------------------------------------------------- style

  /// Fetches the style from the gateway and points its tile URLs at it.
  Future<void> _loadStyle(Brightness brightness) async {
    final name = brightness == Brightness.dark ? 'dark' : 'light';
    setState(() => _styleError = null);
    try {
      final res = await http
          .get(Uri.parse('$apiBaseUrl/styles/$name.json'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      if (!mounted) return;
      setState(() {
        _layersReady = false;
        _style = res.body.replaceAll('{{BASE_URL}}', apiBaseUrl);
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _styleError = 'Cannot reach the map server at $apiBaseUrl\n$e',
      );
    }
  }

  Future<void> _onStyleLoaded() async {
    final map = _map;
    if (map == null) return;
    const empty = {'type': 'FeatureCollection', 'features': <Object>[]};
    await map.addGeoJsonSource('routes', empty);
    await map.addGeoJsonSource('endpoints', empty);
    await map.addLineLayer(
      'routes',
      'route-alternates',
      const LineLayerProperties(
        lineColor: '#9aa5b1',
        lineWidth: 6,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: [
        '==',
        ['get', 'selected'],
        false,
      ],
    );
    await map.addLineLayer(
      'routes',
      'route-casing',
      const LineLayerProperties(
        lineColor: '#0b4fb3',
        lineWidth: 9,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: [
        '==',
        ['get', 'selected'],
        true,
      ],
    );
    await map.addLineLayer(
      'routes',
      'route-selected',
      const LineLayerProperties(
        lineColor: '#2a7bf6',
        lineWidth: 6,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: [
        '==',
        ['get', 'selected'],
        true,
      ],
    );
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
    _layersReady = true;
    await _syncMap();
  }

  /// Pushes the current endpoints and routes into the map's GeoJSON sources.
  Future<void> _syncMap() async {
    final map = _map;
    if (map == null || !_layersReady) return;

    List<double> coords(LatLng p) => [p.longitude, p.latitude];

    // Alternates first so the selected route is drawn on top.
    final order = [
      for (var i = 0; i < _routes.length; i++)
        if (i != _selected) i,
      if (_routes.isNotEmpty) _selected,
    ];
    await map.setGeoJsonSource('routes', {
      'type': 'FeatureCollection',
      'features': [
        for (final i in order)
          {
            'type': 'Feature',
            'properties': {'selected': i == _selected},
            'geometry': {
              'type': 'LineString',
              'coordinates': [for (final p in _routes[i].shape) coords(p)],
            },
          },
      ],
    });
    await map.setGeoJsonSource('endpoints', {
      'type': 'FeatureCollection',
      'features': [
        if (_origin != null)
          {
            'type': 'Feature',
            'properties': {'color': '#2e7d32'},
            'geometry': {
              'type': 'Point',
              'coordinates': coords(_origin!.location),
            },
          },
        if (_destination != null)
          {
            'type': 'Feature',
            'properties': {'color': '#c62828'},
            'geometry': {
              'type': 'Point',
              'coordinates': coords(_destination!.location),
            },
          },
      ],
    });
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
      // Location is optional: the user can still tap a start point.
    }
  }

  Place? get _myLocationPlace => _myLocation == null
      ? null
      : Place(name: 'My location', location: _myLocation!);

  // ------------------------------------------------------------ selection

  void _onMapClick(LatLng latLng) {
    // Without a known position the first tap picks the start.
    if (_origin == null && _myLocationPlace == null) {
      _setOrigin(latLng);
    } else {
      _setDestination(Place.fromCoordinates(latLng), lookUpName: true);
    }
  }

  void _setOrigin(LatLng latLng) {
    final place = Place.fromCoordinates(latLng);
    setState(() => _origin = place);
    _nameTappedPlace(place, isOrigin: true);
    _updateRoute();
  }

  void _setDestination(Place place, {bool lookUpName = false}) {
    setState(() {
      _destination = place;
      _origin ??= _myLocationPlace;
    });
    if (lookUpName) _nameTappedPlace(place, isOrigin: false);
    _updateRoute(fitCamera: true);
  }

  /// Replaces the coordinate label of a tapped point with a place name.
  Future<void> _nameTappedPlace(Place place, {required bool isOrigin}) async {
    try {
      final named = await _geocoder.reverse(place.location);
      if (named == null || !mounted) return;
      setState(() {
        if (isOrigin && identical(_origin, place)) _origin = named;
        if (!isOrigin && identical(_destination, place)) _destination = named;
      });
    } catch (_) {
      // Keep the coordinate label.
    }
  }

  void _swap() {
    setState(() {
      final o = _origin;
      _origin = _destination;
      _destination = o;
    });
    _updateRoute();
  }

  void _clear() {
    _routeRequest++;
    setState(() {
      _origin = null;
      _destination = null;
      _routes = const [];
      _selected = 0;
      _loading = false;
      _routeError = null;
    });
    _syncMap();
  }

  void _selectRoute(int index) {
    setState(() => _selected = index);
    _syncMap();
  }

  // -------------------------------------------------------------- routing

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
      final routes = await _routing.route(
        from.location,
        to.location,
        mode: _mode,
      );
      if (!mounted || id != _routeRequest) return;
      setState(() {
        _routes = routes;
        _loading = false;
      });
      await _syncMap();
      if (fitCamera) {
        await _map?.animateCamera(
          CameraUpdate.newLatLngBounds(
            routes.first.bounds,
            left: 48,
            top: 120,
            right: 48,
            bottom: 48,
          ),
        );
      }
    } catch (e) {
      if (!mounted || id != _routeRequest) return;
      setState(() {
        _loading = false;
        _routeError = '$e';
      });
    }
  }

  // ------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final style = _style;
    final showPanel = _origin != null || _destination != null;

    return Scaffold(
      // The panel sits below the map rather than over it, so the map's own
      // controls (compass, attribution) are never hidden behind it.
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (style != null)
                  MapLibreMap(
                    // A new style string needs a fresh map so layers are re-added.
                    key: ValueKey(style.hashCode),
                    styleString: style,
                    initialCameraPosition: const CameraPosition(
                      target: sriLankaCenter,
                      zoom: 7,
                    ),
                    cameraTargetBounds: CameraTargetBounds(sriLankaBounds),
                    minMaxZoomPreference: const MinMaxZoomPreference(6, 19),
                    // On web this would add a second locate button; the FAB covers it.
                    myLocationEnabled: _locationGranted && !kIsWeb,
                    compassEnabled: true,
                    compassViewPosition: CompassViewPosition.bottomLeft,
                    onMapCreated: (c) => _map = c,
                    onStyleLoadedCallback: _onStyleLoaded,
                    onMapClick: (_, latLng) => _onMapClick(latLng),
                    onMapLongClick: (_, latLng) => _setOrigin(latLng),
                  )
                else
                  _StatusView(
                    message: _styleError ?? 'Loading map…',
                    onRetry: _styleError == null
                        ? null
                        : () =>
                              _loadStyle(_styleBrightness ?? Brightness.light),
                  ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    // On web the map is an HTML element underneath Flutter; the
                    // interceptor stops taps on overlays from reaching it too.
                    child: PointerInterceptor(
                      child: SearchBox(
                        geocoder: _geocoder,
                        onSelected: _setDestination,
                      ),
                    ),
                  ),
                ),
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
          if (showPanel)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: PointerInterceptor(
                child: RoutePanel(
                  origin: _origin,
                  destination: _destination,
                  mode: _mode,
                  routes: _routes,
                  selected: _selected,
                  loading: _loading,
                  error: _routeError,
                  onModeChanged: (mode) {
                    setState(() => _mode = mode);
                    _updateRoute();
                  },
                  onRouteSelected: _selectRoute,
                  onSwap: _swap,
                  onClear: _clear,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

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
          ],
        ),
      ),
    );
  }
}
