import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nyota/screens/login_screen.dart';
import 'package:nyota/screens/maindashboard_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still loading auth state (very first launch)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // User is logged in → go to dashboard
        if (snapshot.hasData) {
          return const MainDashboardScreen(); // or whatever your dashboard widget/route is
          // If using named routes → better to use Navigator in MaterialApp
        }

        // No user → show login
        return const NyotaLoginPage(); // or your login screen
      },
    );
  }
}