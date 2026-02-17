import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../models/hazard_report.dart';
import '../services/local_storage_service.dart';
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
  HazardReport? _selectedHazard;
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
    final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });
  }

  Future<void> _loadHazards() async {
    final reports = await _storage.loadReports();
    setState(() {
      _hazards = reports;
    });
  }

  // 🔥 STATUS ICONS
  Icon _hazardIcon(HazardReport report) {
    if (report.status == 'Resolved') {
      return const Icon(Icons.check_circle_rounded,
          size: 42, color: Colors.green);
    } else if (report.status == 'Under Work') {
      return const Icon(Icons.construction_rounded,
          size: 42, color: Colors.orange);
    } else {
      return const Icon(Icons.report_problem_rounded,
          size: 42, color: Colors.red);
    }
  }

  List<Marker> _buildMarkers() {
    return _hazards.map((report) {
      return Marker(
        width: 50,
        height: 50,
        point: LatLng(report.latitude, report.longitude),
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedHazard = report;
            });
          },
          child: _hazardIcon(report),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentLocation == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Hazard Map')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation!,
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.ai_road_hazard_app',
              ),

              // 🔥 MARKER CLUSTER
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 60,
                  size: const Size(45, 45),
                  markers: _buildMarkers(),
                  builder: (context, clusterMarkers) {
                    return Container(
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          clusterMarkers.length.toString(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // 🔥 PREVIEW PANEL
          if (_selectedHazard != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Card(
                elevation: 12,
                margin: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedHazard!.description,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 8),

                        // ✅ STATUS TEXT COLOR
                        Text(
                          'Status: ${_selectedHazard!.status}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _selectedHazard!.status == 'Resolved'
                                ? Colors.green
                                : _selectedHazard!.status == 'Under Work'
                                ? Colors.orange
                                : Colors.red,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // 🔥 BEFORE & AFTER IMAGES
                        Row(
                          children: [
                            // ===== BEFORE IMAGE =====
                            Expanded(
                              child: Column(
                                children: [
                                  const Text("Before",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      File(_selectedHazard!.imagePath),
                                      height: 120,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 8),

                            // ===== AFTER IMAGE OR PLACEHOLDER =====
                            Expanded(
                              child: Column(
                                children: [
                                  const Text("After",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),

                                  _selectedHazard!.updateImagePath != null
                                      ? ClipRRect(
                                    borderRadius:
                                    BorderRadius.circular(10),
                                    child: Image.file(
                                      File(_selectedHazard!
                                          .updateImagePath!),
                                      height: 120,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                      : Container(
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius:
                                      BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Colors.grey),
                                    ),
                                    child: const Center(
                                      child: Column(
                                        mainAxisAlignment:
                                        MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.image_not_supported,
                                              size: 35,
                                              color: Colors.grey),
                                          SizedBox(height: 6),
                                          Text(
                                            "No update image",
                                            style: TextStyle(
                                                color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // 🔥 UPDATE BUTTON
                        ElevatedButton.icon(
                          icon: const Icon(Icons.edit),
                          label: const Text('Update Hazard'),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    UpdateHazardScreen(report: _selectedHazard!),
                              ),
                            );

                            await _loadHazards();
                            setState(() {
                              _selectedHazard = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
