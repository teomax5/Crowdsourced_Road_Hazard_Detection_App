import 'package:flutter/material.dart';
import '../services/user_session.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final UserSession _session = UserSession();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
            CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text; // ✅ Fixed: do NOT trim passwords

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter username and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 600));

    final success = _session.login(username, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } else {
      setState(
              () => _errorMessage = 'Invalid username or password. Try again.');
    }
  }

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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2), // ✅ Fixed
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          size: 50,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'AI Road Hazard',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      const Text(
                        'Reporter',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sign in to continue',
                        style:
                        TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 36),

                      // Login card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1), // ✅ Fixed
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                labelText: 'Username',
                                prefixIcon:
                                const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) =>
                                  FocusScope.of(context).nextFocus(),
                            ),
                            const SizedBox(height: 16),

                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                  onPressed: () => setState(() =>
                                  _obscurePassword = !_obscurePassword),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _login(),
                            ),
                            const SizedBox(height: 12),

                            if (_errorMessage != null)
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                  Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: Colors.red, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                            color: Colors.red, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),

                            ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                                  : const Text('Login',
                                  style: TextStyle(fontSize: 16)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Demo credentials hint
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15), // ✅ Fixed
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: const Column(
                          children: [
                            Text(
                              'Demo Credentials',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                            SizedBox(height: 6),
                            Text('👤 User: user / user123',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            SizedBox(height: 2),
                            Text('🔑 Admin: admin / admin123',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}