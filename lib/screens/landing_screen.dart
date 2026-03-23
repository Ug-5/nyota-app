// lib/screens/landing_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nyota/theme.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  List<Animation<double>> _letterAnimations = [];
  Animation<double>? _taglineAnimation;

  final String title = "NYOTA";
  final List<String> letters = [];

  @override
  void initState() {
    super.initState();
    letters.addAll(title.split(''));

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _letterAnimations = List.generate(
      letters.length,
      (index) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller!,
          curve: Interval(
            0.1 * index,
            0.1 * index + 0.60,
            curve: Curves.easeOutCubic,
          ),
        ),
      ),
    );

    _taglineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller!,
        curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller!.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    if (_controller == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Animated NYOTA title
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.w),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(letters.length, (index) {
                      return AnimatedBuilder(
                        animation: _letterAnimations[index],
                        builder: (context, child) {
                          final value = _letterAnimations[index].value;
                          return Opacity(
                            opacity: value,
                            child: Transform.scale(
                              scale: 0.85 + (value * 0.15),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          letters[index],
                          style: GoogleFonts.fredoka(
                            fontSize: 85.sp,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                            height: 1.00,
                            letterSpacing: -1.2.sp,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),

              SizedBox(height: 12.h),

              // Tagline
              FadeTransition(
                opacity: _taglineAnimation!,
                child: Text(
                  "Math is Easy",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fredoka(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w400,
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.4.sp,
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // Buttons
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 28.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _buildButton(
                        label: 'Log In',
                        background: colorScheme.surfaceVariant,
                        textColor: colorScheme.onSurface,
                        onTap: () => Navigator.pushNamed(context, '/login'),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: _buildButton(
                        label: 'Sign Up',
                        background: colorScheme.primary,
                        textColor: colorScheme.onPrimary,
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
    final colorScheme = Theme.of(context).colorScheme;
    
    return SizedBox(
      height: 54.h,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: textColor,
          elevation: isPrimary ? 3 : 1,
          shadowColor: colorScheme.primary.withOpacity(0.22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28.r),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12.w),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.fredoka(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}