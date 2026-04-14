import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nyota/screens/login_screen.dart';
import 'package:nyota/screens/maindashboard_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // splash delay (optional)
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) {
          if (user != null) {
            return const MainDashboardScreen();
          } else {
            return const NyotaLoginPage();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/loadingpg.png',
              fit: BoxFit.cover,
            ),
          ),
          const Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}