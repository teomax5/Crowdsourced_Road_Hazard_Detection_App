import 'package:flutter/material.dart';
import '../services/user_session.dart';
import 'report_hazard_screen.dart';
import 'saved_reports_screen.dart';
import 'map_screen.dart';
import 'find_route_screen.dart';
import 'analytics_screen.dart';
import 'login_screen.dart';
import 'about_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Widget _buildButton({
    required IconData icon,
    required String label,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding:
            const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: iconColor, size: 28),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // close dialog first
              await UserSession().logout(); // ✅ Fixed: await async logout
              if (!context.mounted) return; // ✅ Fixed: mounted check
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = UserSession();
    final isAdmin = session.isAdmin;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueAccent, Colors.lightBlueAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2), // ✅ Fixed
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAdmin
                                  ? Icons.admin_panel_settings
                                  : Icons.person,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              // ✅ Fixed: consistent label for both roles
                              isAdmin
                                  ? 'Admin: ${session.username}'
                                  : 'User: ${session.username}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.info_outline,
                            color: Colors.white),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AboutScreen()),
                        ),
                        tooltip: 'About',
                      ),
                      IconButton(
                        icon:
                        const Icon(Icons.logout, color: Colors.white),
                        onPressed: () => _logout(context),
                        tooltip: 'Logout',
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        const Text(
                          'AI Road Hazard Reporter',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAdmin
                                ? Colors.amber.withValues(alpha: 0.3) // ✅ Fixed
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isAdmin
                                ? '🔑 Authority / Admin Panel'
                                : '👤 Citizen Panel',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 40),

                        _buildButton(
                          icon: Icons.warning,
                          label: 'Report Road Hazard',
                          iconColor: Colors.red,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                  const ReportHazardScreen())),
                        ),
                        _buildButton(
                          icon: Icons.map,
                          label: 'View Hazards Map',
                          iconColor: Colors.blue,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const MapScreen())),
                        ),
                        _buildButton(
                          icon: Icons.route,
                          label: 'Find Safe Route',
                          iconColor: Colors.green,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                  const FindRouteScreen())),
                        ),
                        _buildButton(
                          icon: Icons.list_alt,
                          label: 'View Saved Reports',
                          iconColor: Colors.blue,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                  const SavedReportsScreen())),
                        ),

                        // ✅ Admin-only buttons
                        if (isAdmin) ...[
                          _buildButton(
                            icon: Icons.bar_chart,
                            label: 'Analytics Dashboard',
                            iconColor: Colors.purple,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                    const AnalyticsScreen())),
                          ),
                        ],

                        // ✅ Fixed: About only in top bar icon — removed duplicate button here
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}