// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ← added

import 'package:nyota/firebase_options.dart';
import 'package:nyota/screens/parentdashboard.dart';
import 'package:nyota/theme.dart';

// Import your screens
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/maindashboard_screen.dart';
import 'screens/parentdashboard.dart'; // Parent dashboard

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase BEFORE runApp
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const NyotaApp());
}

class NyotaApp extends StatelessWidget {
  const NyotaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      // Base design size — match this to your Figma/primary mockup resolution
      // 375×812 is very common (≈ iPhone 13 / many modern designs)
      designSize: const Size(375, 812),

      // Makes font sizes adapt more intelligently on very small/large screens
      minTextAdapt: true,

      // Better support for tablets, foldables, split-screen mode
      splitScreenMode: true,

      // Rebuild strategy — usually fine as default
      // fontSizeResolver: (fontSize, instance) => fontSize * instance.scaleText, // optional customization

      builder: (context, child) {
        return MaterialApp(
          title: 'Nyota - Learning Adventure',
          debugShowCheckedModeBanner: false,

          theme: ThemeData(
            primaryColor: AppTheme.primary,
            scaffoldBackgroundColor: AppTheme.background,
            textTheme: GoogleFonts.fredokaTextTheme(
              Theme.of(context).textTheme.apply(
                bodyColor: AppTheme.textPrimary,
                displayColor: AppTheme.textPrimary,
              ),
            ),
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppTheme.primary,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),

          // Initial route — now benefits from ScreenUtil
          home: const LandingPage(),

          // Named routes — all screens inside will have .w / .h / .sp / .r available
          routes: {
            '/login': (context) => const NyotaLoginPage(),
            '/signup': (context) => const SignupScreen(),
            '/main-dashboard': (context) => const MainDashboardScreen(),
            '/parent-dashboard': (context) => const ParentDashboard(),
          },
        );
      },
    );
  }
}

// Optional: Auth wrapper (recommended for protecting routes)
// Uncomment and use this later if you want auto-redirect based on auth state
/*
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // If user is logged in → main dashboard; else → login
        if (snapshot.hasData) {
          return const MainDashboardScreen();
        }
        return const NyotaLoginPage();
      },
    );
  }
}
*/