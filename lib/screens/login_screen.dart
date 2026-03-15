// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nyota/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
class NyotaLoginPage extends StatefulWidget {
  const NyotaLoginPage({super.key});

  @override
  State<NyotaLoginPage> createState() => _NyotaLoginPageState();
}

class _NyotaLoginPageState extends State<NyotaLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Password', style: GoogleFonts.fredoka(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your email address and we’ll send you a link to reset your password.',
              style: GoogleFonts.fredoka(fontSize: 15),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Your email',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: AppTheme.surfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.fredoka()),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement real password reset (Firebase Auth)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Password reset link sent! (coming soon)', style: GoogleFonts.fredoka()),
                  backgroundColor: AppTheme.success,
                ),
              );
              Navigator.pop(context);
            },
            child: Text('Send Link', style: GoogleFonts.fredoka(color: AppTheme.primary)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

 Future<void> _handleLogin() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  try {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/main-dashboard',
        (route) => false,
      );
    }
  } on FirebaseAuthException catch (e) {
    String errorMessage;

    switch (e.code) {
      case 'user-not-found':
        errorMessage = 'No account found with this email.';
        break;
      case 'wrong-password':
        errorMessage = 'Incorrect password.';
        break;
      case 'invalid-email':
        errorMessage = 'Invalid email format.';
        break;
      case 'user-disabled':
        errorMessage = 'This account has been disabled.';
        break;
      case 'too-many-requests':
        errorMessage = 'Too many attempts. Please try again later.';
        break;
      default:
        errorMessage = e.message ?? 'Login failed. Please try again.';
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage, style: GoogleFonts.fredoka()),
          backgroundColor: AppTheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred', style: GoogleFonts.fredoka()),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Welcome Back!',
                      style: GoogleFonts.fredoka(fontSize: 30, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Log in to continue your child’s learning',
                      style: GoogleFonts.fredoka(fontSize: 16, color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    _buildTextField(
                      controller: _emailController,
                      icon: Icons.email_outlined,
                      label: 'Parent Email',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email is required';
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    _buildTextField(
                      controller: _passwordController,
                      icon: Icons.lock_outline,
                      label: 'Password',
                      isPassword: true,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password is required';
                        if (v.length < 6) return 'At least 6 characters';
                        return null;
                      },
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _showForgotPasswordDialog,
                        child: Text(
                          'Forgot Password?',
                          style: GoogleFonts.fredoka(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: AppTheme.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                              )
                            : Text(
                                'LOG IN',
                                style: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: GoogleFonts.fredoka(fontSize: 15, color: AppTheme.textSecondary),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/signup'),
                          child: Text(
                            'Sign up',
                            style: GoogleFonts.fredoka(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    TextInputType? keyboardType,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword ? _obscurePassword : false,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: GoogleFonts.fredoka(fontSize: 16, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: GoogleFonts.fredoka(fontSize: 16, color: AppTheme.textSecondary),
        prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 24),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppTheme.textSecondary,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        filled: true,
        fillColor: AppTheme.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: AppTheme.primary, width: 2.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: AppTheme.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: AppTheme.error, width: 2.5)),
      ),
    );
  }
}