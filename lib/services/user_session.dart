import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  // ✅ Singleton
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  String? _username;
  String? _role;

  // ✅ NOTE: Hardcoded credentials are for demo/academic use only.
  // In a production app, always verify credentials against a secure backend.
  static const Map<String, Map<String, String>> _credentials = {
    'user': {'password': 'user123', 'role': 'user'},
    'admin': {'password': 'admin123', 'role': 'admin'},
  };

  /// Attempts login. Returns true if credentials are valid.
  bool login(String username, String password) {
    final entry = _credentials[username.toLowerCase()];
    if (entry != null && entry['password'] == password) {
      _username = username;
      _role = entry['role'];
      _persistSession(); // ✅ Fixed: persist session
      return true;
    }
    return false;
  }

  /// Clears session from memory and storage.
  Future<void> logout() async {
    _username = null;
    _role = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_username');
    await prefs.remove('session_role');
  }

  /// Restores session from SharedPreferences on app restart.
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString('session_username');
    _role = prefs.getString('session_role');
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_username != null) await prefs.setString('session_username', _username!);
    if (_role != null) await prefs.setString('session_role', _role!);
  }

  String get username => _username ?? '';
  String get role => _role ?? '';
  bool get isAdmin => _role == 'admin';
  bool get isLoggedIn => _username != null && _role != null; // ✅ Fixed: both must be set
}