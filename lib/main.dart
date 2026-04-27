import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'services/user_session.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UserSession().restoreSession(); // ✅ Restore session on app start
  runApp(const RoadHazardApp());
}

class RoadHazardApp extends StatelessWidget {
  const RoadHazardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Road Hazard App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue), // ✅ Fixed: not deprecated
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
