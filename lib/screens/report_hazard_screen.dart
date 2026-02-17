import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../models/hazard_report.dart';
import '../services/local_storage_service.dart';

class ReportHazardScreen extends StatefulWidget {
  const ReportHazardScreen({super.key});

  @override
  State<ReportHazardScreen> createState() => _ReportHazardScreenState();
}

class _ReportHazardScreenState extends State<ReportHazardScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final LocalStorageService _storageService = LocalStorageService();

  File? _image;
  double? _latitude;
  double? _longitude;
  bool _isSubmitting = false;

  Future<void> _captureImage() async {
    final XFile? picked =
    await _picker.pickImage(source: ImageSource.camera);

    if (picked != null) {
      setState(() {
        _image = File(picked.path);
      });
    }
  }

  Future<void> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
    });
  }

  Future<void> _submitReport() async {
    if (_image == null ||
        _latitude == null ||
        _longitude == null ||
        _descriptionController.text.isEmpty) {
      return;
    }

    setState(() => _isSubmitting = true);

    final report = HazardReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      imagePath: _image!.path,
      description: _descriptionController.text,
      latitude: _latitude!,
      longitude: _longitude!,
      timestamp: DateTime.now().toIso8601String(),
      status: 'Active', // ✅ REQUIRED FIX
    );

    await _storageService.saveReport(report);

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Hazard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // IMAGE PREVIEW
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _image != null
                  ? Image.file(_image!, fit: BoxFit.cover)
                  : const Center(child: Text('No image captured')),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture Image'),
              onPressed: _captureImage,
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              icon: const Icon(Icons.location_on),
              label: Text(
                _latitude != null ? 'Location Captured' : 'Get Location',
              ),
              onPressed: _getLocation,
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Hazard Description',
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReport,
              child: _isSubmitting
                  ? const CircularProgressIndicator()
                  : const Text('Submit Hazard'),
            ),
          ],
        ),
      ),
    );
  }
}
