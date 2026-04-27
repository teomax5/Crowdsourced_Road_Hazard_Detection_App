import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/hazard_report.dart';

class LocalStorageService {
  // ✅ Fixed: proper singleton
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  List<HazardReport>? _cache; // ✅ Fixed: in-memory cache

  Future<String> get _localPath async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/reports.json');
  }

  Future<List<HazardReport>> loadReports() async {
    if (_cache != null) return List.from(_cache!); // ✅ return cached copy
    try {
      final file = await _localFile;
      if (!await file.exists()) return []; // ✅ Fixed: async exists()
      final data = await file.readAsString();
      final List jsonData = jsonDecode(data) as List;
      _cache = jsonData
          .map((e) => HazardReport.fromJson(e as Map<String, dynamic>))
          .toList();
      return List.from(_cache!);
    } catch (e, stack) {
      // ✅ Fixed: log errors instead of silently swallowing
      debugPrint('Failed to load reports: $e\n$stack');
      return [];
    }
  }

  Future<void> saveReport(HazardReport report) async {
    final reports = await loadReports();
    reports.add(report);
    await _writeReports(reports);
  }

  Future<void> updateReport(HazardReport updatedReport) async {
    final reports = await loadReports();
    final index = reports.indexWhere((r) => r.id == updatedReport.id);
    if (index == -1) return;
    reports[index] = updatedReport;
    await _writeReports(reports);
  }

  Future<void> deleteReport(String id) async {
    final reports = await loadReports();
    reports.removeWhere((r) => r.id == id);
    await _writeReports(reports);
  }

  /// ✅ Fixed: atomic write via temp file to prevent corruption
  Future<void> _writeReports(List<HazardReport> reports) async {
    final file = await _localFile;
    final temp = File('${file.path}.tmp');
    try {
      await temp.writeAsString(
          jsonEncode(reports.map((e) => e.toJson()).toList()));
      await temp.rename(file.path);
      _cache = List.from(reports); // ✅ update cache
    } catch (e, stack) {
      debugPrint('Failed to write reports: $e\n$stack');
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
  }
}