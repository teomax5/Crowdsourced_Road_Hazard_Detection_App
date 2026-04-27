import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/hazard_report.dart';
import '../services/local_storage_service.dart';
import '../services/ors_service.dart';

// ─────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────

class RouteInfo {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final int index;

  RouteInfo({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.index,
  });

  String get distanceText {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.toInt()} m';
  }

  String get durationText {
    final minutes = (durationSeconds / 60).round();
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }
    return '$minutes min';
  }
}

class SearchSuggestion {
  final String displayName;
  final double lat;
  final double lon;

  SearchSuggestion(
      {required this.displayName, required this.lat, required this.lon});
}

// Which field is currently active for search
enum _ActiveField { origin, destination }

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────

class FindRouteScreen extends StatefulWidget {
  const FindRouteScreen({super.key});

  @override
  State<FindRouteScreen> createState() => _FindRouteScreenState();
}

class _FindRouteScreenState extends State<FindRouteScreen> {
  final MapController _mapController = MapController();
  final LocalStorageService _storage = LocalStorageService();
  StreamSubscription<Position>? _positionStream;

  // ── Controllers & focus nodes ──
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destController = TextEditingController();
  final FocusNode _originFocus = FocusNode();
  final FocusNode _destFocus = FocusNode();

  // ── Location state ──
  LatLng? _gpsLocation;          // raw GPS fix
  LatLng? _originLocation;       // chosen origin (GPS or typed)
  LatLng? _destination;
  String _originName = '';
  String _destinationName = '';
  bool _originIsGps = true;      // true → origin pin follows GPS

  // ── Data ──
  List<HazardReport> _allHazards = [];
  List<HazardReport> _hazardsOnRoute = [];
  List<RouteInfo> _routes = [];

  // ── UI state ──
  bool _isLoadingLocation = true;
  bool _isFetchingRoute = false;
  bool _isSearchingOrigin = false;
  bool _isSearchingDest = false;
  List<SearchSuggestion> _suggestions = [];
  bool _showSuggestions = false;
  _ActiveField _activeField = _ActiveField.destination;

  static const double _routeBufferMeters = 100;

  @override
  void initState() {
    super.initState();

    _originFocus.addListener(() {
      if (_originFocus.hasFocus) {
        setState(() => _activeField = _ActiveField.origin);
      }
    });

    _destFocus.addListener(() {
      if (_destFocus.hasFocus) {
        setState(() => _activeField = _ActiveField.destination);
      }
    });

    _init();

    // 🔥 ADD THIS LINE
    _startLiveLocation();
  }
  @override
  void dispose() {
    _originController.dispose();
    _destController.dispose();
    _originFocus.dispose();
    _destFocus.dispose();
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _getCurrentLocation();
    await _loadHazards();
  }

  // ── GPS ──────────────────────────────────────────────────────────────────

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setFallbackLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        _setFallbackLocation();
        return;
      }

      // ⚡ Get last known location (fast)
      Position? lastKnown = await Geolocator.getLastKnownPosition();

      if (lastKnown != null && mounted) {
        setState(() {
          _gpsLocation = LatLng(lastKnown.latitude, lastKnown.longitude);
        });
      }

      // 🔥 Get accurate GPS fix
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 10),
      );

      if (mounted) {
        final accurateLocation = LatLng(pos.latitude, pos.longitude);

        setState(() {
          _gpsLocation = accurateLocation;
          _originLocation = accurateLocation;
          _originIsGps = true;
          _originController.text = 'My Location';
          _isLoadingLocation = false;
        });

        _mapController.move(accurateLocation, 16);
      }
    } catch (e) {
      debugPrint('Location error: $e');
      _setFallbackLocation();
    }
  }

  void _setFallbackLocation() {
    if (mounted) {
      setState(() {
        _gpsLocation = const LatLng(12.84922, 80.19502);
        _originLocation = _gpsLocation;
        _originIsGps = true;
        _originController.text = 'My Location';
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _loadHazards() async {
    final data = await _storage.loadReports();
    if (mounted) setState(() => _allHazards = data);
  }
  void _startLiveLocation() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      if (!mounted) return;

      final newLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _gpsLocation = newLocation;

        // Only update origin if using GPS
        if (_originIsGps) {
          _originLocation = newLocation;
        }
      });
    });
  }
  // ── Use GPS for origin ────────────────────────────────────────────────────

  void _useGpsAsOrigin() {
    if (_gpsLocation == null) return;
    setState(() {
      _originLocation = _gpsLocation;
      _originIsGps = true;
      _originController.text = 'My Location';
      _suggestions = [];
      _showSuggestions = false;
      _routes = [];
      _hazardsOnRoute = [];
    });
    _originFocus.unfocus();
    _mapController.move(_gpsLocation!, 14);
    _tryFetchRoutes();
  }

  // ── Nominatim autocomplete ────────────────────────────────────────────────

  Future<void> _search(String query, _ActiveField field) async {
    if (query.trim().length < 3) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    setState(() {
      if (field == _ActiveField.origin) {
        _isSearchingOrigin = true;
      } else {
        _isSearchingDest = true;
      }
    });

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
            '?q=${Uri.encodeComponent(query)}'
            '&format=json&limit=5&addressdetails=1',
      );
      final response = await http
          .get(uri, headers: {'User-Agent': 'AIRoadHazardApp/1.0'})
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body) as List;
        setState(() {
          _suggestions = data
              .map((item) => SearchSuggestion(
            displayName: item['display_name'] as String,
            lat: double.parse(item['lat'] as String),
            lon: double.parse(item['lon'] as String),
          ))
              .toList();
          _showSuggestions = _suggestions.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingOrigin = false;
          _isSearchingDest = false;
        });
      }
    }
  }

  void _selectSuggestion(SearchSuggestion s) {
    final shortName = s.displayName.split(',').first.trim();

    if (_activeField == _ActiveField.origin) {
      setState(() {
        _originLocation = LatLng(s.lat, s.lon);
        _originIsGps = false;
        _originName = shortName;
        _originController.text = shortName;
      });
      _originFocus.unfocus();
    } else {
      setState(() {
        _destination = LatLng(s.lat, s.lon);
        _destinationName = shortName;
        _destController.text = shortName;
      });
      _destFocus.unfocus();
    }

    setState(() {
      _suggestions = [];
      _showSuggestions = false;
      _routes = [];
      _hazardsOnRoute = [];
    });

    _tryFetchRoutes();
  }

  // Fetch only when both endpoints are set
  void _tryFetchRoutes() {
    if (_originLocation != null && _destination != null) {
      _fetchRoutes();
    }
  }

  // ── ORS routing ───────────────────────────────────────────────────────────

  Future<void> _fetchRoutes() async {
    if (_originLocation == null || _destination == null) return;

    setState(() {
      _isFetchingRoute = true;
      _routes = [];
      _hazardsOnRoute = [];
    });

    try {
      // ORS expects [longitude, latitude] order — pass correctly
      final features = await ORSService.getRoutes(
        _originLocation!.latitude,
        _originLocation!.longitude,
        _destination!.latitude,
        _destination!.longitude,
      );

      if (!mounted) return;

      final List<RouteInfo> parsedRoutes = [];

      for (int i = 0; i < features.length; i++) {
        final feature = features[i] as Map<String, dynamic>;
        final coords = feature['geometry']['coordinates'] as List<dynamic>;
        final summary =
        feature['properties']['summary'] as Map<String, dynamic>;

        // ORS GeoJSON: coords are [lon, lat] — flip to LatLng correctly
        final points = coords
            .map((c) => LatLng(
          (c[1] as num).toDouble(), // latitude  = index 1
          (c[0] as num).toDouble(), // longitude = index 0
        ))
            .toList();

        parsedRoutes.add(RouteInfo(
          points: points,
          distanceMeters: (summary['distance'] as num).toDouble(),
          durationSeconds: (summary['duration'] as num).toDouble(),
          index: i,
        ));
      }

      final hazardsNearRoute =
      _findHazardsOnRoute(parsedRoutes.isNotEmpty ? parsedRoutes[0] : null);

      if (parsedRoutes.isNotEmpty) {
        _fitMapToRoute(parsedRoutes[0].points);
      }

      setState(() {
        _routes = parsedRoutes;
        _hazardsOnRoute = hazardsNearRoute;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to fetch route: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isFetchingRoute = false);
    }
  }

  // ── Hazard proximity ──────────────────────────────────────────────────────

  List<HazardReport> _findHazardsOnRoute(RouteInfo? route) {
    if (route == null) return [];
    const dist = Distance();
    return _allHazards.where((hazard) {
      final hPoint = LatLng(hazard.latitude, hazard.longitude);
      for (final routePoint in route.points) {
        if (dist.as(LengthUnit.Meter, hPoint, routePoint) <=
            _routeBufferMeters) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  String get _routeSeverity {
    final active = _hazardsOnRoute
        .where((h) => h.status.toLowerCase() == 'active')
        .toList();

    final underWork = _hazardsOnRoute
        .where((h) => h.status.toLowerCase() == 'under work')
        .toList();

    if (active.isEmpty && underWork.isEmpty) return 'Clear';

    final critical = active.where((h) => h.severity == 'critical').length;
    final high = active.where((h) => h.severity == 'high').length;
    final medium = active.where((h) => h.severity == 'medium').length;

    if (critical > 0) return 'Critical';
    if (high > 0) return 'High Risk';

    // 🔥 consider under work as moderate
    if (medium > 0 || underWork.isNotEmpty) return 'Moderate';

    return 'Low Risk';
  }

  Color get _routeSeverityColor {
    switch (_routeSeverity) {
      case 'Clear':
        return Colors.green;
      case 'Critical':
        return Colors.red.shade900;
      case 'High Risk':
        return Colors.red;
      case 'Moderate':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  void _fitMapToRoute(List<LatLng> points) {
    if (points.isEmpty) return;
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      minLat = min(minLat, p.latitude);
      maxLat = max(maxLat, p.latitude);
      minLng = min(minLng, p.longitude);
      maxLng = max(maxLng, p.longitude);
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    final maxDiff = max(maxLat - minLat, maxLng - minLng);

    double zoom = 14;
    if (maxDiff > 0.5) zoom = 10;
    else if (maxDiff > 0.2) zoom = 11;
    else if (maxDiff > 0.1) zoom = 12;
    else if (maxDiff > 0.05) zoom = 13;

    _mapController.move(center, zoom);
  }

  void _clearAll() {
    setState(() {
      _destination = null;
      _destinationName = '';
      _routes = [];
      _hazardsOnRoute = [];
      _destController.clear();
      _suggestions = [];
      _showSuggestions = false;
    });
    if (_originLocation != null) {
      _mapController.move(_originLocation!, 14);
    }
  }

  void _dismissSuggestions() {
    _originFocus.unfocus();
    _destFocus.unfocus();
    setState(() => _showSuggestions = false);
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  // ── Marker / polyline builders ────────────────────────────────────────────

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.red;
      case 'under work':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Origin marker
    if (_originLocation != null) {
      markers.add(Marker(
        width: 44,
        height: 44,
        point: _originLocation!,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.4), blurRadius: 8)
            ],
          ),
          child: const Icon(Icons.my_location, color: Colors.white, size: 22),
        ),
      ));
    }

    // Destination marker
    if (_destination != null) {
      markers.add(Marker(
        width: 44,
        height: 56,
        point: _destination!,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.flag, color: Colors.white, size: 20),
            ),
            Container(
              width: 2,
              height: 10,
              color: Colors.deepPurple,
            ),
          ],
        ),
      ));
    }

    // Hazard markers
    final onRouteIds = _hazardsOnRoute.map((h) => h.id).toSet();
    for (final h in _allHazards) {
      final isOnRoute = onRouteIds.contains(h.id);
      final color = _getStatusColor(h.status);
      markers.add(Marker(
        width: 48,
        height: 48,
        point: LatLng(h.latitude, h.longitude),
        child: Opacity(
          opacity: _routes.isEmpty || isOnRoute ? 1.0 : 0.35,
          child: Container(
            decoration: BoxDecoration(
              color: isOnRoute ? color : color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                  color: color, width: isOnRoute ? 3 : 1.5),
              boxShadow: isOnRoute
                  ? [
                BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 8)
              ]
                  : [],
            ),
            child: Icon(Icons.warning,
                color: isOnRoute ? Colors.white : color, size: 22),
          ),
        ),
      ));
    }

    return markers;
  }

  List<Polyline> _buildPolylines() {
    if (_routes.isEmpty) return [];
    final polylines = <Polyline>[];

    // Alternative routes underneath
    for (int i = 1; i < _routes.length; i++) {
      polylines.add(Polyline(
        points: _routes[i].points,
        color: Colors.grey.withValues(alpha: 0.5),
        strokeWidth: 4,
        isDotted: true,
      ));
    }

    // Primary route on top
    polylines.add(Polyline(
      points: _routes[0].points,
      color: Colors.blue,
      strokeWidth: 6,
    ));

    return polylines;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoadingLocation
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
              _originLocation ?? const LatLng(13.0827, 80.2707),
              initialZoom: 14,
              onTap: (_, __) => _dismissSuggestions(),
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                'com.example.ai_road_hazard_app',
              ),
              PolylineLayer(polylines: _buildPolylines()),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          // Search card + suggestions
          SafeArea(
            child: Column(
              children: [
                _buildSearchCard(),
                if (_showSuggestions) _buildSuggestions(),
              ],
            ),
          ),

          // Loading overlay
          if (_isFetchingRoute)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Finding safest route...',
                            style:
                            TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Route details panel
          if (_routes.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildRoutePanel(),
            ),

          // Legend (only when no route shown)
          if (_routes.isEmpty)
            Positioned(
              bottom: 16,
              left: 16,
              child: _buildLegend(),
            ),
        ],
      ),
    );
  }

  // ── Search card (GMaps-style) ─────────────────────────────────────────────

  Widget _buildSearchCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Back button
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 22),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),

              // Dot-line-dot connector + two fields
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Origin field ──────────────────────────────────
                    Row(
                      children: [
                        _dot(Colors.blue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _originController,
                            focusNode: _originFocus,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Starting point',
                              hintStyle: const TextStyle(fontSize: 14),
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding:
                              const EdgeInsets.symmetric(vertical: 6),
                              suffixIcon: _isSearchingOrigin
                                  ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              )
                                  : null,
                            ),
                            onChanged: (v) {
                              if (v.isNotEmpty && v != 'My Location') {
                                setState(() => _originIsGps = false);
                                _search(v, _ActiveField.origin);
                              }
                            },
                          ),
                        ),
                        // GPS shortcut button
                        GestureDetector(
                          onTap: _useGpsAsOrigin,
                          child: Tooltip(
                            message: 'Use my GPS location',
                            child: Icon(
                              Icons.gps_fixed,
                              size: 20,
                              color: _originIsGps
                                  ? Colors.blue
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Vertical connector
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Row(
                        children: [
                          Column(
                            children: List.generate(
                              4,
                                  (_) => Container(
                                width: 2,
                                height: 4,
                                margin: const EdgeInsets.symmetric(vertical: 1),
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Destination field ─────────────────────────────
                    Row(
                      children: [
                        _dot(Colors.deepPurple),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _destController,
                            focusNode: _destFocus,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Choose destination',
                              hintStyle: const TextStyle(fontSize: 14),
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding:
                              const EdgeInsets.symmetric(vertical: 6),
                              suffixIcon: _isSearchingDest
                                  ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              )
                                  : _destController.text.isNotEmpty
                                  ? GestureDetector(
                                onTap: _clearAll,
                                child: const Icon(Icons.close,
                                    size: 18),
                              )
                                  : null,
                            ),
                            onChanged: (v) =>
                                _search(v, _ActiveField.destination),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: _suggestions.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final s = _suggestions[i];
            return ListTile(
              dense: true,
              leading: Icon(
                _activeField == _ActiveField.origin
                    ? Icons.trip_origin
                    : Icons.location_on_outlined,
                color: _activeField == _ActiveField.origin
                    ? Colors.blue
                    : Colors.deepPurple,
                size: 20,
              ),
              title: Text(
                s.displayName.split(',').first,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
              ),
              subtitle: Text(
                s.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
              onTap: () => _selectSuggestion(s),
            );
          },
        ),
      ),
    );
  }

  // ── Route panel ──────────────────────────────────────────────────────────

  Widget _buildRoutePanel() {
    final best = _routes[0];
    final activeHazardCount =
        _hazardsOnRoute.where((h) => h.status.toLowerCase() == 'active').length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, -4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.trip_origin,
                                color: Colors.blue, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _originIsGps ? 'My Location' : _originName,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.flag,
                                color: Colors.deepPurple, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _destinationName,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _clearAll,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Stats row
                Row(
                  children: [
                    _statChip(Icons.schedule, best.durationText, Colors.blue),
                    const SizedBox(width: 8),
                    _statChip(
                        Icons.straighten, best.distanceText, Colors.teal),
                    const SizedBox(width: 8),
                    _statChip(
                      Icons.warning_amber,
                      '${_hazardsOnRoute.length} hazard${_hazardsOnRoute.length == 1 ? '' : 's'}',
                      _hazardsOnRoute.isEmpty ? Colors.green : Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Severity badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _routeSeverityColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Route Risk: $_routeSeverity',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    if (activeHazardCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          '$activeHazardCount active',
                          style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Alternative routes
                if (_routes.length > 1) ...[
                  const Text(
                    'Alternative Routes',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  ...List.generate(_routes.length - 1, (i) {
                    final alt = _routes[i + 1];
                    final timeDiff =
                        alt.durationSeconds - best.durationSeconds;
                    final diffText = timeDiff >= 0
                        ? '+${(timeDiff / 60).round()} min'
                        : '-${(-timeDiff / 60).round()} min';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: Colors.grey, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text('Alternative ${i + 1}: ${alt.distanceText}',
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 6),
                          Text(
                            diffText,
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                timeDiff > 0 ? Colors.red : Colors.green,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],

                // Hazards list
                if (_hazardsOnRoute.isNotEmpty) ...[
                  const Divider(),
                  const Text(
                    'Hazards Along Route',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _hazardsOnRoute.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final h = _hazardsOnRoute[i];
                        final color = _getStatusColor(h.status);
                        return Container(
                          width: 160,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: color.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning, color: color, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    h.severity.toUpperCase(),
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                h.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                              const Spacer(),
                              Text(
                                h.status.toUpperCase(),
                                style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _legendRow(Colors.blue, 'Start Point'),
          const SizedBox(height: 4),
          _legendRow(Colors.deepPurple, 'Destination'),
          const SizedBox(height: 4),
          _legendRow(Colors.red, 'Active Hazard'),
          const SizedBox(height: 4),
          _legendRow(Colors.orange, 'Under Work'),
          const SizedBox(height: 4),
          _legendRow(Colors.green, 'Resolved'),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 12,
            height: 12,
            decoration:
            BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}