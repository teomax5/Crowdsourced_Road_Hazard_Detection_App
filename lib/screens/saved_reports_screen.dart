import 'dart:io';
import 'package:flutter/material.dart';

import '../models/hazard_report.dart';
import '../services/local_storage_service.dart';

class SavedReportsScreen extends StatefulWidget {
  const SavedReportsScreen({super.key});

  @override
  State<SavedReportsScreen> createState() => _SavedReportsScreenState();
}

class _SavedReportsScreenState extends State<SavedReportsScreen> {
  final LocalStorageService _storageService = LocalStorageService();

  late Future<List<HazardReport>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _reportsFuture = _storageService.loadReports();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Hazard Reports'),
      ),
      body: FutureBuilder<List<HazardReport>>(
        future: _reportsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No hazard reports found'),
            );
          }

          final reports = snapshot.data!;

          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: Image.file(
                    File(report.imagePath),
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                  title: Text(report.description),
                  subtitle: Text(
                    'Lat: ${report.latitude}, Lng: ${report.longitude}\n'
                        'Time: ${report.timestamp}',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
