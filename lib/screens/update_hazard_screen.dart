import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/hazard_report.dart';
import '../services/local_storage_service.dart';
import '../services/model_service.dart';

class UpdateHazardScreen extends StatefulWidget {
  final HazardReport report;

  const UpdateHazardScreen({super.key, required this.report});

  @override
  State<UpdateHazardScreen> createState() => _UpdateHazardScreenState();
}

class _UpdateHazardScreenState extends State<UpdateHazardScreen> {
  final LocalStorageService _storage = LocalStorageService();
  final ModelService _modelService = ModelService();
  final ImagePicker _picker = ImagePicker();

  late String _selectedStatus;
  File? _updateImage;
  String? _detectedHazard;
  double? _confidence;
  String? _severity;
  bool _isModelLoaded = false;
  bool _isDetecting = false;
  bool _isSaving = false;

  static const double _confidenceThreshold = 0.25; // ✅ Fixed: raised from 0.10

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.report.status;
    _initModel();
  }

  @override
  void dispose() {
    _modelService.dispose(); // ✅ Fixed: dispose interpreter
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

  Future<void> _pickImage(ImageSource source) async {
    if (!_isModelLoaded) {
      if (!mounted) return; // ✅ Fixed: mounted check
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⏳ AI model still loading...')),
      );
      return;
    }

    final XFile? picked = await _picker.pickImage(source: source);
    if (picked == null) return;

    setState(() {
      _updateImage = File(picked.path);
      _detectedHazard = null;
      _confidence = null;
      _severity = null;
      _isDetecting = true;
    });

    await _detectHazard();
    if (mounted) setState(() => _isDetecting = false);
  }

  Future<void> _detectHazard() async {
    if (_updateImage == null) return;

    try {
      final Uint8List imageBytes = await _updateImage!.readAsBytes();
      final result = await _modelService.runModel(imageBytes);

      if (!mounted) return;

      final double confidence = result['confidence'] as double? ?? 0.0;
      final String hazard = result['hazard'] as String? ?? 'unknown';
      final String severity = result['severity'] as String? ?? 'low';

      if (confidence < _confidenceThreshold || hazard == 'none') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '⚠️ Low confidence (${(confidence * 100).toStringAsFixed(1)}%) — try a clearer image.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() {
        _detectedHazard = hazard;
        _confidence = confidence;
        _severity = severity; // ✅ Fixed: store severity from detection
      });
    } catch (e) {
      debugPrint('Detection error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Failed to run AI detection'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveUpdate() async {
    setState(() => _isSaving = true);

    try {
      final updated = widget.report.copyWith(
        status: _selectedStatus,
        updateImagePath: _updateImage?.path ?? widget.report.updateImagePath,
        confidence: _confidence ?? widget.report.confidence,
        severity: _severity ?? widget.report.severity, // ✅ Fixed: update severity
      );

      await _storage.updateReport(updated);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Hazard updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false); // ✅ Fixed: always reset
    }
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
        return Colors.grey;
    }
  }

  String _formatTimestamp(DateTime dt) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Update Hazard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Before & After',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text('Before',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                              fontSize: 13)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FutureBuilder<bool>(
                          future: File(widget.report.imagePath).exists(),
                          builder: (context, snapshot) =>
                          snapshot.data == true
                              ? Image.file(
                            File(widget.report.imagePath),
                            height: 130,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                              : _placeholderImage('No Image'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    children: [
                      const Text('After',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                              fontSize: 13)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _updateImage != null
                            ? Image.file(
                          _updateImage!,
                          height: 130,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                            : widget.report.updateImagePath != null
                            ? FutureBuilder<bool>(
                          future: File(widget
                              .report.updateImagePath!)
                              .exists(),
                          builder: (context, snapshot) =>
                          snapshot.data == true
                              ? Image.file(
                            File(widget.report
                                .updateImagePath!),
                            height: 130,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                              : _placeholderImage(
                              'No Update Yet'),
                        )
                            : _placeholderImage('No Update Yet'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isDetecting)
              const Center(child: CircularProgressIndicator()),

            if (_detectedHazard != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning,
                            color: Colors.red, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Detected: $_detectedHazard',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                        'Confidence: ${(_confidence! * 100).toStringAsFixed(1)}%'),
                    if (_severity != null)
                      Text('Severity: ${_severity!.toUpperCase()}'),
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

            const Text(
              'Upload After Image',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
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
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            const Text(
              'Update Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildStatusOption('active', 'Active', Icons.error, Colors.red),
                  Divider(height: 1, color: Colors.grey.shade300),
                  _buildStatusOption('under work', 'Under Work',
                      Icons.timelapse, Colors.orange),
                  Divider(height: 1, color: Colors.grey.shade300),
                  _buildStatusOption(
                      'resolved', 'Resolved', Icons.check_circle, Colors.green),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Original Report',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(widget.report.description,
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    '📍 ${widget.report.latitude.toStringAsFixed(5)}, ${widget.report.longitude.toStringAsFixed(5)}',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '🕐 ${_formatTimestamp(widget.report.timestamp)}', // ✅ Fixed
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isSaving ? null : _saveUpdate,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: _getStatusColor(_selectedStatus),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : const Text('Save Update',
                  style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOption(
      String value, String label, IconData icon, Color color) {
    final bool isSelected = _selectedStatus == value;
    return InkWell(
      onTap: () => setState(() => _selectedStatus = value),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected
            ? color.withValues(alpha: 0.08) // ✅ Fixed
            : Colors.transparent,
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight:
                isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.black87,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _placeholderImage(String label) {
    return Container(
      height: 130,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported,
              size: 36, color: Colors.grey.shade400),
          const SizedBox(height: 6),
          Text(label,
              style:
              TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ],
      ),
    );
  }
}