import 'package:flutter/material.dart';
import 'dart:async';
import '../dashboard/dashboard_screen.dart';
import '../food_request/food_request_screen.dart';
import 'role_selection_screen.dart';

class LoadingScreen extends StatefulWidget {
  final Map<String, dynamic> loginResult;
  final String? role;

  const LoadingScreen({super.key, required this.loginResult, this.role});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  void _navigateToNext() {
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;

      if (widget.loginResult['needsRoleSelection'] == true) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
        );
      } else {
        final role = widget.role?.toLowerCase();
        if (role == 'intern' || role == 'interns') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const FoodRequestScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/rtsLogo.png',
              width: 150,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.business, size: 80, color: Color(0xFF5C59E8));
              },
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5C59E8)),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            const Text(
              'Loading Tele-Rts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
