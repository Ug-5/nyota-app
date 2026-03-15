// lib/screens/landing_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nyota/theme.dart'; // 
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _letterAnimations;
  late Animation<double> _taglineAnimation;

  final String title = "NYOTA";
  final List<String> letters = [];

  @override
  void initState() {
    super.initState();

    letters.addAll(title.split(''));

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800), // total animation time
    );

    // Staggered letter animations
    _letterAnimations = List.generate(
      letters.length,
      (index) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            0.1 * index,           // delay each letter
            0.1 * index + 0.60,    // each letter takes ~450ms
            curve: Curves.easeOutCubic,
          ),
        ),
      ),
    );

    // Tagline appears after most letters
    _taglineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
      ),
    );

    // Start animation once
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Animated NYOTA title
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(letters.length, (index) {
                  return AnimatedBuilder(
                    animation: _letterAnimations[index],
                    builder: (context, child) {
                      final value = _letterAnimations[index].value;
                      return Opacity(
                        opacity: value,
                        child: Transform.scale(
                          scale: 0.85 + (value * 0.15), // gentle pop-in scale
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      letters[index],
                      style: GoogleFonts.fredoka(
                        fontSize: 85,
                        fontWeight: FontWeight.w600, // bold but not super thick
                        color: AppTheme.primary,
                        height: 1.00,
                        letterSpacing: -1.2,
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 12),

              // "Math is Easy" fades in gently
              FadeTransition(
                opacity: _taglineAnimation,
                child: Text(
                  "Math is Easy",
                  style: GoogleFonts.fredoka(
                    fontSize: 30,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.4,
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Hero cute star (your chosen calm star asset)
              

              const Spacer(flex: 2),

              // Buttons – smaller, side by side
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _buildButton(
                        label: 'Log In',
                        background: AppTheme.surfaceVariant,
                        textColor: AppTheme.textPrimary,
                        onTap: () => Navigator.pushNamed(context, '/login'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildButton(
                        label: 'Sign Up',
                        background: AppTheme.primary,
                        textColor: AppTheme.onPrimary,
                        isPrimary: true,
                        onTap: () => Navigator.pushNamed(context, '/signup'),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required Color background,
    required Color textColor,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return SizedBox(
      height: 54, // slightly smaller than before
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: textColor,
          elevation: isPrimary ? 3 : 1,
          shadowColor: AppTheme.primary.withOpacity(0.22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: Text(
          label,
          style: GoogleFonts.fredoka(
            fontSize: 19,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}