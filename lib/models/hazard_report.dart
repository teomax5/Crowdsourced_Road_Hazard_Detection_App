import 'package:uuid/uuid.dart';

class HazardReport {
  final String id;
  final String imagePath;
  final String? updateImagePath;
  final String description;
  final double latitude;
  final double longitude;
  final DateTime timestamp; // ✅ Fixed: DateTime instead of String
  final String status;
  final double? confidence;
  final String severity;

  /// [updateImagePath] Path to an updated image (e.g. after hazard status changes)
  HazardReport({
    String? id,
    required this.imagePath,
    this.updateImagePath,
    required this.description,
    required this.latitude,
    required this.longitude,
    DateTime? timestamp,
    required this.status,
    this.confidence,
    this.severity = 'low', // ✅ Fixed: consistent lowercase
  })  : id = id ?? const Uuid().v4(), // ✅ Fixed: auto-generate UUID
        timestamp = timestamp ?? DateTime.now();

  HazardReport copyWith({
    String? status,
    String? updateImagePath,
    double? confidence,
    String? severity,
  }) {
    return HazardReport(
      id: id,
      imagePath: imagePath,
      updateImagePath: updateImagePath ?? this.updateImagePath,
      description: description,
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
      status: status ?? this.status,
      confidence: confidence ?? this.confidence,
      severity: severity ?? this.severity,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'imagePath': imagePath,
    'updateImagePath': updateImagePath,
    'description': description,
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': timestamp.toIso8601String(), // ✅ Fixed: ISO 8601 string
    'status': status,
    'confidence': confidence,
    'severity': severity,
  };

  factory HazardReport.fromJson(Map<String, dynamic> json) {
    // ✅ Fixed: full null safety + proper type casting
    return HazardReport(
      id: json['id'] as String? ?? const Uuid().v4(),
      imagePath: json['imagePath'] as String? ?? '',
      updateImagePath: json['updateImagePath'] as String?,
      description: json['description'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      status: json['status'] as String? ?? 'active',
      confidence: (json['confidence'] as num?)?.toDouble(),
      severity: json['severity'] as String? ?? 'low',
    );
  }
}