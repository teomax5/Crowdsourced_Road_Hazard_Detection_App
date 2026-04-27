import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import '../models/hazard_report.dart';
import '../services/local_storage_service.dart';
import '../services/user_session.dart';
import '../services/ors_service.dart';
import 'update_hazard_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LocalStorageService _storage = LocalStorageService();
  final MapController _mapController = MapController();

  List<HazardReport> _hazards = [];
  LatLng? _currentLocation;


  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _getCurrentLocation();
    await _loadHazards();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      debugPrint('Location error: $e');
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(12.84922, 80.19502); // Chennai fallback
      });
    }
  }

  Future<void> _loadHazards() async {
    final reports = await _storage.loadReports();
    if (!mounted) return;
    setState(() => _hazards = reports);
  }

  /// ✅ Fixed: route requires user to tap a destination marker (hazard location)


  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  IconData _getHazardIcon(String description) {
    final d = description.toLowerCase();
    if (d.contains('pothole')) return Icons.circle;
    if (d.contains('water') || d.contains('flood')) return Icons.water;
    if (d.contains('manhole')) return Icons.radio_button_checked;
    if (d.contains('signal')) return Icons.traffic;
    return Icons.warning;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.red;
      case 'under work':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey; // ✅ Fixed: grey for unknown
    }
  }

  List<Marker> _buildMarkers() {
    final List<Marker> markers = [];

    // Current location marker
    if (_currentLocation != null) {
      markers.add(
        Marker(
          width: 40,
          height: 40,
          point: _currentLocation!,
          child: const Icon(Icons.my_location,
              color: Colors.blue, size: 32),
        ),
      );
    }

    for (final report in _hazards) {
      final color = _getStatusColor(report.status);
      final icon = _getHazardIcon(report.description);

      markers.add(
        Marker(
          width: 80,
          height: 80,
          point: LatLng(report.latitude, report.longitude),
          child: GestureDetector(
            onTap: () => _showHazardDetails(report),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15), // ✅ Fixed
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return markers;
  }

  void _showHazardDetails(HazardReport report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView( // ✅ prevents overflow
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// STATUS + SEVERITY
              Row(
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getStatusColor(report.status),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      report.status.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '⚠️ ${report.severity.toUpperCase()}',
                      style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 11),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              /// DESCRIPTION
              Text(
                report.description,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500),
              ),

              const SizedBox(height: 10),

              /// 📸 BEFORE & AFTER IMAGES
              Row(
                children: [
                  /// BEFORE
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Before",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),

                        report.imagePath.isNotEmpty
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(report.imagePath),
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        )
                            : const SizedBox(
                          height: 120,
                          child: Center(child: Text("No Image")),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  /// AFTER
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("After",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),

                        (report.updateImagePath != null &&
                            report.updateImagePath!.isNotEmpty)
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(report.updateImagePath!),
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        )
                            : const SizedBox(
                          height: 120,
                          child: Center(child: Text("No Update")),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              /// LOCATION + AI CONFIDENCE
              Text(
                '📍 ${report.latitude.toStringAsFixed(5)}, ${report.longitude.toStringAsFixed(5)}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),

              if (report.confidence != null)
                Text(
                  'AI Confidence: ${(report.confidence! * 100).toStringAsFixed(1)}%',
                  style:
                  TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),

              const SizedBox(height: 16),

              /// UPDATE BUTTON (FOR ALL USERS)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Update Hazard'),
                  onPressed: () async {
                    Navigator.pop(context);

                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            UpdateHazardScreen(report: report),
                      ),
                    );

                    if (result == true) {
                      await _loadHazards();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Fixed: proper legend with color meanings
  Widget _buildLegend() {
    return Positioned(
      bottom: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95), // ✅ Fixed
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 6)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _legendRow(Colors.red, 'Active'),
            const SizedBox(height: 4),
            _legendRow(Colors.orange, 'Under Work'),
            const SizedBox(height: 4),
            _legendRow(Colors.green, 'Resolved'),
          ],
        ),
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
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentLocation == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hazard Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHazards,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation!, // ✅ Fixed: non-deprecated API
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.ai_road_hazard_app',
              ),
              MarkerLayer(markers: _buildMarkers()),
              // ✅ Route polyline layer
            ],
          ),

          _buildLegend(),


        ],
      ),
    );
  }
}