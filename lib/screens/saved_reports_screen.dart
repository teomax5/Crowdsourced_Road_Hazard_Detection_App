import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hazard_report.dart';
import '../services/local_storage_service.dart';
import '../services/user_session.dart';

class SavedReportsScreen extends StatefulWidget {
  const SavedReportsScreen({super.key});

  @override
  State<SavedReportsScreen> createState() => _SavedReportsScreenState();
}

class _SavedReportsScreenState extends State<SavedReportsScreen> {
  final LocalStorageService _storage = LocalStorageService();
  List<HazardReport> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final data = await _storage.loadReports();
    if (!mounted) return;
    setState(() {
      _reports = data;
      _isLoading = false;
    });
  }

  Future<void> _deleteReport(HazardReport report) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text('Are you sure you want to delete this report?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await _storage.deleteReport(report.id);

    // ✅ Fixed: mounted check BEFORE setState and SnackBar
    if (!mounted) return;
    await _loadReports();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report deleted')),
    );
  }

  Widget _buildImage(String imagePath) {
    final file = File(imagePath);
    // ✅ FutureBuilder to avoid sync existsSync in build
    return FutureBuilder<bool>(
      future: file.exists(),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return Image.file(file, width: 56, height: 56, fit: BoxFit.cover);
        }
        return const Icon(Icons.broken_image, size: 56, color: Colors.grey);
      },
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
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
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
        return Colors.grey; // ✅ Fixed: grey instead of red for unknown
    }
  }

  // ✅ Fixed: format DateTime properly
  String _formatTimestamp(DateTime dt) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = UserSession().isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.report_off, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No saved reports yet',
              style:
              TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: _reports.length,
        itemBuilder: (context, index) {
          final report = _reports[index];
          return Card(
            margin: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: _buildImage(report.imagePath),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getSeverityColor(
                                    report.severity),
                                borderRadius:
                                BorderRadius.circular(10),
                              ),
                              child: Text(
                                '⚠️ ${report.severity.toUpperCase()}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                    report.status),
                                borderRadius:
                                BorderRadius.circular(10),
                              ),
                              child: Text(
                                report.status.toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          report.description,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (report.confidence != null)
                          Text(
                            'AI Confidence: ${(report.confidence! * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12),
                          ),
                        Text(
                          '📍 ${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
                          style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12),
                        ),
                        Text(
                          '🕐 ${_formatTimestamp(report.timestamp)}', // ✅ Fixed
                          style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                  // ✅ Fixed: delete only for admins
                  if (isAdmin)
                    IconButton(
                      icon: const Icon(Icons.delete,
                          color: Colors.red, size: 20),
                      onPressed: () => _deleteReport(report),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}