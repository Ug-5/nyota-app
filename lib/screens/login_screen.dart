// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nyota/theme.dart'; // fixed import (was 'gymack/theme.dart' – likely typo)

class NyotaLoginPage extends StatefulWidget {
  const NyotaLoginPage({super.key});

  @override
  State<NyotaLoginPage> createState() => _NyotaLoginPageState();
}

class _NyotaLoginPageState extends State<NyotaLoginPage> {
  bool _obscurePassword = true;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      // TODO: Replace with real Firebase auth later
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/main-dashboard',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 28.w),
            child: Container(
              padding: EdgeInsets.fromLTRB(24.w, 48.h, 24.w, 32.h),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(32.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 20.r,
                    offset: Offset(0, 8.h),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Welcome Back!',
                      style: GoogleFonts.fredoka(
                        fontSize: 32.sp,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Log in to continue your adventure',
                      style: GoogleFonts.fredoka(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 40.h),

                    _buildTextField(
                      controller: _emailController,
                      icon: Icons.email_outlined,
                      label: 'Email Address',
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (!v.contains('@')) return 'Invalid email';
                        return null;
                      },
                    ),
                    SizedBox(height: 20.h),

                    _buildTextField(
                      controller: _passwordController,
                      icon: Icons.lock_outline,
                      label: 'Password',
                      isPassword: true,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length < 6) return 'At least 6 characters';
                        return null;
                      },
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Forgot Password – coming soon!'),
                              backgroundColor: AppTheme.warning,
                            ),
                          );
                        },
                        child: Text(
                          'Forgot Password?',
                          style: GoogleFonts.fredoka(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 32.h),

                    SizedBox(
                      width: double.infinity,
                      height: 60.h,
                      child: ElevatedButton(
                        onPressed: _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: AppTheme.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
                          elevation: 2,
                        ),
                        child: Text(
                          'LOG IN',
                          style: GoogleFonts.fredoka(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: GoogleFonts.fredoka(
                            fontSize: 15.sp,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/signup'),
                          child: Text(
                            'Sign up',
                            style: GoogleFonts.fredoka(
                              fontSize: 15.sp,
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
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      validator: validator,
      style: GoogleFonts.fredoka(fontSize: 16.sp, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: GoogleFonts.fredoka(fontSize: 16.sp, color: AppTheme.textSecondary),
        prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 24.w),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppTheme.textSecondary,
                  size: 24.w,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        filled: true,
        fillColor: AppTheme.surfaceVariant,
        contentPadding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 16.w),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20.r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20.r),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20.r),
          borderSide: BorderSide(color: AppTheme.primary, width: 2.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20.r),
          borderSide: BorderSide(color: AppTheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20.r),
          borderSide: BorderSide(color: AppTheme.error, width: 2.5),
        ),
      ),
    );
  }
}