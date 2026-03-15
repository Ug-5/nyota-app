// lib/screens/maindashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nyota/theme.dart';
import 'parentdashboard_screen.dart';
import 'chillddashboard.dart'; // ← your child dashboard file

class MainDashboardScreen extends StatefulWidget {
  final String? userPassword;

  const MainDashboardScreen({super.key, this.userPassword});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _starController;
  late Animation<double> _starAnimation;

  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _starAnimation = Tween<double>(begin: 0, end: 15).animate(
      CurvedAnimation(parent: _starController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _starController.dispose();
    super.dispose();
  }

  void _showPasswordDialog() {
    final ctrl = TextEditingController();
    bool obscure = true;
         Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const ParentDashboard()),
  );
  
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Parent Access',
            style: GoogleFonts.fredoka(
              fontSize: 22,
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
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: ctrl,
                obscureText: obscure,
                style: GoogleFonts.fredoka(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Password',
                  filled: true,
                  fillColor: AppTheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                      color: AppTheme.textSecondary,
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
                style: GoogleFonts.fredoka(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                if (ctrl.text == widget.userPassword) {
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
                style: GoogleFonts.fredoka(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.fromLTRB(32, 80, 32, 48),
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
                            'Welcome to your learning adventure!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.fredoka(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 48),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildOptionCard(
                                imageAsset: 'assets/images/parent.png',
                                label: 'Parent',
                                onTap: _showPasswordDialog,
                              ),
                              const SizedBox(width: 24),
                              _buildOptionCard(
                                imageAsset: 'assets/images/child.png',
                                label: 'Child',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ChildDashboard(),
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
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
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
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.fredoka(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}