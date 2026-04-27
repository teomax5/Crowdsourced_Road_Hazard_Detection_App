import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueAccent, Colors.lightBlueAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'About',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2), // ✅
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          size: 56,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'AI Road Hazard Reporter',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Detect • Report • Resolve',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            letterSpacing: 2),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2), // ✅
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Version 1.0.0',
                          style:
                          TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 24),

                      _infoCard(
                        title: '👨‍💻 Developer',
                        children: [
                          _infoRow(Icons.person, 'Name', 'Your Name Here'),
                          _infoRow(Icons.school, 'College',
                              'Your College Name'),
                          _infoRow(Icons.book, 'Department',
                              'Computer Science & Engineering'),
                          _infoRow(
                              Icons.calendar_today, 'Year', '2024 - 2025'),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _infoCard(
                        title: '📱 Project Info',
                        children: [
                          _infoRow(Icons.info, 'Project Type',
                              'Final Year Project'),
                          _infoRow(
                              Icons.code, 'Framework', 'Flutter (Dart)'),
                          _infoRow(Icons.psychology, 'AI Model',
                              'YOLOv8 TFLite (float32)'),
                          _infoRow(Icons.map, 'Map Engine',
                              'OpenStreetMap + flutter_map'),
                          _infoRow(Icons.storage, 'Storage',
                              'Local JSON (Offline)'),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _infoCard(
                        title: '🤖 How AI Detection Works',
                        children: [
                          _stepRow(
                              '1', 'User captures or picks an image'),
                          _stepRow(
                              '2', 'Image is resized to 640×640 pixels'),
                          _stepRow('3',
                              'YOLOv8 TFLite model runs inference locally on device'),
                          _stepRow('4',
                              'Model outputs bounding boxes + class confidence scores'),
                          _stepRow('5',
                              'Highest confidence detection is shown to user'),
                          _stepRow('6',
                              'Severity is auto-calculated from confidence + hazard type'),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _infoCard(
                        title: '🕳️ Detectable Hazard Classes',
                        children: [
                          _hazardRow(Icons.circle, Colors.brown, 'Pothole',
                              'Road surface damage'),
                          _hazardRow(Icons.water, Colors.blue,
                              'Waterlogging', 'Flooded road / stagnant water'),
                          _hazardRow(Icons.radio_button_checked, Colors.grey,
                              'Open Manhole', 'Uncovered drain or manhole'),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _infoCard(
                        title: '⚠️ Severity Scoring System',
                        children: [
                          _severityRow(Colors.red.shade900, 'Critical',
                              'Confidence ≥ 75% or dangerous hazard type'),
                          _severityRow(
                              Colors.red, 'High', 'Confidence ≥ 50%'),
                          _severityRow(
                              Colors.orange, 'Medium', 'Confidence ≥ 30%'),
                          _severityRow(
                              Colors.green, 'Low', 'Confidence < 30%'),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _infoCard(
                        title: '👥 User Roles',
                        children: [
                          _roleRow('👤', 'Regular User',
                              'Report hazards, view map, view saved reports'),
                          const SizedBox(height: 8),
                          _roleRow('🔑', 'Admin / Authority',
                              'All user features + update status, delete reports, view analytics'),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _infoCard(
                        title: '🛠️ Tech Stack',
                        children: [
                          _techRow('Flutter',
                              'Cross-platform mobile framework'),
                          _techRow('Dart', 'Programming language'),
                          _techRow(
                              'YOLOv8', 'Object detection AI model'),
                          _techRow('TFLite', 'On-device AI inference'),
                          _techRow(
                              'flutter_map', 'OpenStreetMap rendering'),
                          _techRow('Geolocator', 'GPS location access'),
                          _techRow('fl_chart', 'Analytics charts'),
                          _techRow(
                              'image_picker', 'Camera & gallery access'),
                          _techRow(
                              'path_provider', 'Local file storage'),
                        ],
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'Built with ❤️ using Flutter & YOLOv8',
                        style:
                        TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '© 2025 AI Road Hazard Reporter',
                        style:
                        TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(
      {required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08), // ✅
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold)),
          const Divider(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blueAccent),
          const SizedBox(width: 10),
          Text('$label: ',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: Colors.grey.shade700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _stepRow(String step, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(step,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(description,
                style: TextStyle(
                    color: Colors.grey.shade700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _hazardRow(
      IconData icon, Color color, String name, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              Text(description,
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _severityRow(Color color, String level, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(level,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(description,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _roleRow(
      String emoji, String role, String permissions) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(role,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              Text(permissions,
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _techRow(String tech, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          // ✅ Fixed: SizedBox with ellipsis instead of unconstrained Container
          SizedBox(
            width: 90,
            child: Text(
              tech,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(description,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}