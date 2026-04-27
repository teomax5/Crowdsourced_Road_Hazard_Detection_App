import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../models/hazard_report.dart';
import '../services/local_storage_service.dart';
import '../services/model_service.dart';

class ReportHazardScreen extends StatefulWidget {
  const ReportHazardScreen({super.key});

  @override
  State<ReportHazardScreen> createState() => _ReportHazardScreenState();
}

class _ReportHazardScreenState extends State<ReportHazardScreen> {
  final TextEditingController _descriptionController =
  TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final LocalStorageService _storageService = LocalStorageService();
  final ModelService _modelService = ModelService();

  File? _image;
  double? _latitude;
  double? _longitude;
  bool _isSubmitting = false;
  bool _isModelLoaded = false;
  bool _isDetecting = false;
  bool _isLocating = false;

  String? _detectedHazard;
  double? _confidence;
  String? _severity;

  static const double _confidenceThreshold = 0.25;

  @override
  void initState() {
    super.initState();
    _initModel();
    _getLocation(); // ✅ Fixed: auto-fetch location on open
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _modelService.dispose(); // ✅ Fixed: dispose TFLite interpreter
    super.dispose();
  }

  Future<void> _initModel() async {
    try {
      await _modelService.loadModel();
      if (mounted) setState(() => _isModelLoaded = true);
    } catch (e) {
      debugPrint('Model load error: $e');
    }
  }

  Future<void> _getLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Location services are disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        // ✅ Fixed: inform user instead of silently returning
        _showSnack(
            'Location permission permanently denied. Enable in settings.',
            isError: true);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      }
    } catch (e) {
      _showSnack('Could not get location: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!_isModelLoaded) {
      _showSnack('AI model still loading, please wait...');
      return;
    }

    final XFile? picked = await _picker.pickImage(source: source);
    if (picked == null) return;

    setState(() {
      _image = File(picked.path);
      _detectedHazard = null;
      _confidence = null;
      _severity = null;
      _isDetecting = true;
    });

    await _runDetection();

    if (mounted) setState(() => _isDetecting = false);
  }

  // ✅ Fixed: AI detection wired into report flow
  Future<void> _runDetection() async {
    if (_image == null) return;
    try {
      final Uint8List imageBytes = await _image!.readAsBytes();
      final result = await _modelService.runModel(imageBytes);

      if (!mounted) return;

      final double confidence = result['confidence'] as double? ?? 0.0;
      final String hazard = result['hazard'] as String? ?? 'unknown';
      final String severity = result['severity'] as String? ?? 'low';

      if (confidence < _confidenceThreshold || hazard == 'none') {
        _showSnack(
          'Low confidence (${(confidence * 100).toStringAsFixed(1)}%) — try a clearer image.',
          isError: false,
          color: Colors.orange,
        );
        return;
      }

      setState(() {
        _detectedHazard = hazard;
        _confidence = confidence;
        _severity = severity;
      });
    } catch (e) {
      debugPrint('Detection error: $e');
      if (!mounted) return;
      _showSnack('AI detection failed: $e', isError: true);
    }
  }

  Future<void> _submitReport() async {
    // ✅ Fixed: user-facing validation feedback
    if (_image == null) {
      _showSnack('Please capture or select an image.', isError: true);
      return;
    }
    if (_latitude == null || _longitude == null) {
      _showSnack('Please wait for location or tap Get Location.',
          isError: true);
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      _showSnack('Please enter a hazard description.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final report = HazardReport(
        // id auto-generated via UUID in model
        imagePath: _image!.path,
        description: _descriptionController.text.trim(),
        latitude: _latitude!,
        longitude: _longitude!,
        // timestamp auto-set in model
        status: 'active', // ✅ Fixed: consistent lowercase
        confidence: _confidence,
        severity: _severity ?? 'low',
      );

      await _storageService.saveReport(report);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to save report: $e', isError: true);
    } finally {
      // ✅ Fixed: always reset submitting state
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String message,
      {bool isError = false, Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
        color ?? (isError ? Colors.red : Colors.blueAccent),
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red.shade900;
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Hazard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image preview
            ClipRRect(
              borderRadius: BorderRadius.circular(8), // ✅ Fixed: clip to radius
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade100,
                ),
                child: _image != null
                    ? Image.file(_image!, fit: BoxFit.cover)
                    : const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt,
                          size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No image captured',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ✅ Fixed: both camera and gallery options
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    onPressed: _isModelLoaded
                        ? () => _pickImage(ImageSource.camera)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    onPressed: _isModelLoaded
                        ? () => _pickImage(ImageSource.gallery)
                        : null,
                  ),
                ),
              ],
            ),

            if (!_isModelLoaded)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Loading AI model...',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // AI detection result
            if (_isDetecting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 12),
                      Text('Running AI detection...'),
                    ],
                  ),
                ),
              ),

            if (_detectedHazard != null && _confidence != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Detected: $_detectedHazard',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                        'Confidence: ${(_confidence! * 100).toStringAsFixed(1)}%'),
                    if (_severity != null)
                      Row(
                        children: [
                          const Text('Severity: '),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getSeverityColor(_severity!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _severity!.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _confidence,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _confidence! >= 0.7
                              ? Colors.green
                              : _confidence! >= 0.4
                              ? Colors.orange
                              : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Location button
            // ✅ Fixed: shows coordinates after capture, auto-fetches on load
            ElevatedButton.icon(
              icon: _isLocating
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.location_on),
              label: Text(
                _latitude != null
                    ? '📍 ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'
                    : _isLocating
                    ? 'Getting location...'
                    : 'Get Location',
              ),
              onPressed: _isLocating ? null : _getLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                _latitude != null ? Colors.green : Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Hazard Description',
                hintText: 'Describe the hazard (e.g. large pothole near junction)',
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReport,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : const Text('Submit Hazard',
                  style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}