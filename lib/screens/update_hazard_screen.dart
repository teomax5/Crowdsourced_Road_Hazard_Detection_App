import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/hazard_report.dart';
import '../services/local_storage_service.dart';

class UpdateHazardScreen extends StatefulWidget {
  final HazardReport report;

  const UpdateHazardScreen({super.key, required this.report});

  @override
  State<UpdateHazardScreen> createState() => _UpdateHazardScreenState();
}

class _UpdateHazardScreenState extends State<UpdateHazardScreen> {
  String _status = 'Active';
  File? _afterImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _status = widget.report.status;
  }

  Future<void> _pickAfterImage() async {
    final XFile? image =
    await _picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      setState(() {
        _afterImage = File(image.path);
      });
    }
  }

  Future<void> _saveUpdate() async {
    final updatedReport = widget.report.copyWith(
      status: _status,
      updateImagePath: _afterImage?.path,
    );

    await LocalStorageService().updateReport(updatedReport);

    if (mounted) {
      Navigator.pop(context, true); // refresh map
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Hazard Status'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hazard Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            RadioListTile(
              title: const Text('Active'),
              value: 'Active',
              groupValue: _status,
              onChanged: (v) => setState(() => _status = v!),
            ),
            RadioListTile(
              title: const Text('Under Work'),
              value: 'Under Work',
              groupValue: _status,
              onChanged: (v) => setState(() => _status = v!),
            ),
            RadioListTile(
              title: const Text('Resolved'),
              value: 'Resolved',
              groupValue: _status,
              onChanged: (v) => setState(() => _status = v!),
            ),

            const SizedBox(height: 20),

            const Text(
              'After Image (Optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 10),

            if (_afterImage != null)
              Image.file(_afterImage!, height: 160, fit: BoxFit.cover)
            else
              const Text('No update image captured'),

            const SizedBox(height: 10),

            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture Update Image'),
              onPressed: _pickAfterImage,
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveUpdate,
                child: const Text('Save Update'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
