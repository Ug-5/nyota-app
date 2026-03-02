import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'screens/landing_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/account_setup_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const GymackApp());
}

class GymackApp extends StatelessWidget {
  const GymackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GYMACK',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      initialRoute: '/',
      routes: {
        '/': (context) => const LandingScreen(),
        '/signup': (context) => const SignupScreen(),
        '/account-setup': (context) => const AccountSetupScreen(),
      },
    );
  }
}
