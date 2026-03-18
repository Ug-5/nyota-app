// lib/screens/maindashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nyota/theme.dart';
import 'parentdashboard_screen.dart';
import 'chillddashboard.dart';

class MainDashboardScreen extends StatefulWidget {
  final String? userPassword;

  const MainDashboardScreen({super.key, this.userPassword});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _starController;

  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _starController.dispose();
    super.dispose();
  }

  void _showPasswordDialog(double scaleFactor) {
    final ctrl = TextEditingController();
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Parent Access',
            style: GoogleFonts.fredoka(
              fontSize: 22 * scaleFactor,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter password to access parent dashboard',
                style: GoogleFonts.fredoka(
                  fontSize: 15 * scaleFactor,
                  color: AppTheme.textSecondary,
                ),
              ),
              SizedBox(height: 20 * scaleFactor),
              TextField(
                controller: ctrl,
                obscureText: obscure,
                style: GoogleFonts.fredoka(fontSize: 16 * scaleFactor),
                decoration: InputDecoration(
                  hintText: 'Password',
                  filled: true,
                  fillColor: AppTheme.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                      color: AppTheme.textSecondary,
                      size: 20 * scaleFactor,
                    ),
                    onPressed: () => setSt(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.fredoka(fontSize: 14 * scaleFactor, color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                // Logic: verify password (fallback to 'admin' if null for safety)
                if (ctrl.text == (widget.userPassword ?? 'admin')) {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ParentDashboard()),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Incorrect password'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              },
              child: Text(
                'Enter',
                style: GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: 14 * scaleFactor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Calculate responsiveness variables
    final Size size = MediaQuery.of(context).size;
    final double screenWidth = size.width;
    final double scaleFactor = (screenWidth / 375).clamp(0.8, 1.2);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24 * scaleFactor,
                    vertical: 40 * scaleFactor
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Welcome to your\nlearning adventure!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.fredoka(
                          fontSize: 22 * scaleFactor,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      SizedBox(height: 40 * scaleFactor),

                      // 2. Flexible Row using Expanded
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _buildOptionCard(
                              imageAsset: 'assets/images/parent.png',
                              label: 'Parent',
                              scaleFactor: scaleFactor,
                              onTap: () => _showPasswordDialog(scaleFactor),
                            ),
                          ),
                          SizedBox(width: 16 * scaleFactor),
                          Expanded(
                            child: _buildOptionCard(
                              imageAsset: 'assets/images/child.png',
                              label: 'Child',
                              scaleFactor: scaleFactor,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ChildDashboard()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String imageAsset,
    required String label,
    required double scaleFactor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          // Use AspectRatio to keep the card square regardless of width
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24 * scaleFactor),
                color: AppTheme.surfaceVariant,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                image: DecorationImage(
                  image: AssetImage(imageAsset),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          SizedBox(height: 12 * scaleFactor),
          FittedBox( // Prevents text overflow on small devices
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: GoogleFonts.fredoka(
                fontSize: 16 * scaleFactor,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}