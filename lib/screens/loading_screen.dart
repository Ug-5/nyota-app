import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';   
import 'signup_screen.dart'; 
import 'maindashboard_screen.dart'; 

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Already signed in → go to dashboard
        if (snapshot.hasData && snapshot.data != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainDashboardScreen()),
            );
          });
          return const SizedBox.shrink();
        }

        // Not signed in → show welcome UI
        return _buildLandingUI(context);
      },
    );
  }

  Widget _buildLandingUI(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF9E7),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.png',
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60.0),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo row
                      Row(
                        children: [
                          Image.asset('assets/images/nyotastar.png', height: 40),
                          const SizedBox(width: 12),
                          const Text(
                            'NYOTA',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A4A4A),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      const Text(
                        'Welcome to Nyota!',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4A4A4A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'A calm space for your\nchild to love math.',
                        style: TextStyle(
                          fontSize: 32,
                          color: Color(0xFF4A4A4A),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Fun, simple, and supportive learning.',
                        style: TextStyle(fontSize: 20, color: Color(0xFF4A4A4A)),
                      ),
                      const SizedBox(height: 48),

                      // Two buttons: Login and Sign Up
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // LOGIN BUTTON
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const NyotaLoginPage()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF2D382),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 36, vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Login',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 20),
                          // SIGN UP BUTTON
                          OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SignupScreen()),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4A4A4A),
                              side: const BorderSide(
                                  color: Color(0xFFF2D382), width: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 36, vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Right side: image
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/images/childontab.png',
                          fit: BoxFit.contain,
                        ),
                      ),
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