import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/styling/responsive.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(seconds: 3));
    
    if (!mounted) return;
    
    // Check if user is already logged in
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token != null && token.isNotEmpty) {
      // User is logged in, go to home
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // Not logged in, go to onboarding
      Navigator.pushReplacementNamed(context, '/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: Center(
        child: ContentContainer(
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Text(
              'Family Hub',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF388E3C),
              ),
            ),
            const SizedBox(height: 20),
            // Logo
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.family_restroom, size: 50, color: Color(0xFF388E3C)),
            ),
            const SizedBox(height: 30),
            // Loading dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDot(context),
                const SizedBox(width: 8),
                _buildDot(context),
                const SizedBox(width: 8),
                _buildDot(context),
              ],
            ),
            const Spacer(),
            Text(
              'Connecting Families Together',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF388E3C),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildDot(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Color(0xFF388E3C),
        shape: BoxShape.circle,
      ),
    );
  }
}
