class HazardReport {
  final String id;
  final String imagePath; // Before image
  final String? updateImagePath; // After image
  final String description;
  final double latitude;
  final double longitude;
  final String timestamp;
  final String status;

  HazardReport({
    required this.id,
    required this.imagePath,
    this.updateImagePath,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.status,
  });

  HazardReport copyWith({
    String? status,
    String? updateImagePath,
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
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'imagePath': imagePath,
    'updateImagePath': updateImagePath,
    'description': description,
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': timestamp,
    'status': status,
  };

  factory HazardReport.fromJson(Map<String, dynamic> json) {
    return HazardReport(
      id: json['id'],
      imagePath: json['imagePath'],
      updateImagePath: json['updateImagePath'],
      description: json['description'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      timestamp: json['timestamp'],
      status: json['status'],
    );
  }
}
