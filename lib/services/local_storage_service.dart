import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/hazard_report.dart';

class LocalStorageService {
  static const String _fileName = 'hazard_reports.json';

  Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<List<HazardReport>> loadReports() async {
    try {
      final file = await _getLocalFile();
      if (!await file.exists()) return [];

      final contents = await file.readAsString();
      final List<dynamic> jsonData = jsonDecode(contents);

      return jsonData
          .map((e) => HazardReport.fromJson(e))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveReport(HazardReport report) async {
    final file = await _getLocalFile();
    final reports = await loadReports();

    reports.add(report);

    await file.writeAsString(
      jsonEncode(reports.map((e) => e.toJson()).toList()),
    );
  }

  /// ✅ NEW METHOD (FIXES ERROR #2)
  Future<void> updateReport(HazardReport updatedReport) async {
    final file = await _getLocalFile();
    final reports = await loadReports();

    final index =
    reports.indexWhere((r) => r.id == updatedReport.id);

    if (index != -1) {
      reports[index] = updatedReport;

      await file.writeAsString(
        jsonEncode(reports.map((e) => e.toJson()).toList()),
      );
    }
  }
}
