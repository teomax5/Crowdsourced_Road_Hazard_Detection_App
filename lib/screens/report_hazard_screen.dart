import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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
  Uint8List? _annotatedImage;

  double? _latitude;
  double? _longitude;

  String? _detectedHazard;
  double? _confidence;

  bool _isSubmitting = false;

  /// ✅ Use this with ADB reverse
  final String apiUrl = "http://127.0.0.1:8000/detect";

  /// 📸 CAPTURE IMAGE + AUTO DETECT
  Future<void> _captureImage() async {
    final XFile? picked =
    await _picker.pickImage(source: ImageSource.camera);

    if (picked != null) {
      if (!mounted) return;

      setState(() {
        _image = File(picked.path);
        _annotatedImage = null;
        _detectedHazard = null;
        _confidence = null;
        _isSubmitting = true;
      });

      await _detectHazard();

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });
    }
  }

  /// 📍 GET LOCATION
  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      if (!mounted) return;

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      print("Location Error: $e");
    }
  }

  /// 🤖 SEND IMAGE TO YOLO API
  Future<void> _detectHazard() async {
    if (_image == null) return;

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(apiUrl),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          _image!.path,
        ),
      );

      var response = await request.send().timeout(
        const Duration(seconds: 15),
      );

      var responseData = await response.stream.bytesToString();
      var jsonData = jsonDecode(responseData);

      if (!mounted) return;

      if (jsonData["detections"] != null &&
          jsonData["detections"].isNotEmpty) {
        setState(() {
          _detectedHazard = jsonData["detections"][0]["hazard"];
          _confidence = jsonData["detections"][0]["confidence"];
        });
      }

      if (jsonData["annotated_image"] != null) {
        setState(() {
          _annotatedImage =
              base64Decode(jsonData["annotated_image"]);
        });
      }
    } catch (e) {
      print("Detection Error: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Failed to connect to AI server"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 🚀 SUBMIT REPORT
  Future<void> _submitReport() async {
    if (_image == null ||
        _latitude == null ||
        _longitude == null ||
        _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Please complete all fields"),
        ),
      );
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
      status: 'Active',
    );

    await _storageService.saveReport(report);

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  /// 🎨 UI
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

            /// 📷 ORIGINAL IMAGE
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

            const SizedBox(height: 20),

            /// ⏳ LOADING
            if (_isSubmitting)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text("Analyzing image with AI..."),
                ],
              ),

            const SizedBox(height: 20),

            /// 🧠 DETECTION RESULT
            if (_detectedHazard != null)
              Column(
                children: [
                  Text(
                    "Detected Hazard: $_detectedHazard",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  Text(
                    "Confidence: ${(_confidence! * 100).toStringAsFixed(1)}%",
                  ),
                ],
              ),

            const SizedBox(height: 20),

            /// 🟥 ANNOTATED IMAGE
            if (_annotatedImage != null)
              Column(
                children: [
                  const Text(
                    "AI Detection Result",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Image.memory(_annotatedImage!),
                ],
              ),

            const SizedBox(height: 20),

            /// 📍 LOCATION
            ElevatedButton.icon(
              icon: const Icon(Icons.location_on),
              label: Text(
                _latitude != null
                    ? 'Location Captured'
                    : 'Get Location',
              ),
              onPressed: _getLocation,
            ),

            const SizedBox(height: 20),

            /// 📝 DESCRIPTION
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Hazard Description',
              ),
            ),

            const SizedBox(height: 25),

            /// 🚀 SUBMIT
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReport,
              child: _isSubmitting
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Submit Hazard'),
            ),
          ],
        ),
      ),
    );
  }
}