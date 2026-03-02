import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme.dart';

class AccountSetupScreen extends StatefulWidget {
  const AccountSetupScreen({super.key});

  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _childNameController = TextEditingController();

  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;
  DateTime? _selectedDate;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeIn),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _childNameController.dispose();
    super.dispose();
  }

  void _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(now.year - 5, now.month, now.day),
      firstDate: DateTime(now.year - 12),
      lastDate: DateTime(now.year - 2),
      helpText: 'Select child\'s date of birth',
      cancelText: 'Cancel',
      confirmText: 'Confirm',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textDark,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700),
              ),
            ),
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  String _getPasswordStrength(String password) {
    if (password.isEmpty) return '';
    if (password.length < 6) return 'weak';
    bool hasUpper = password.contains(RegExp(r'[A-Z]'));
    bool hasDigit = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    int score = (hasUpper ? 1 : 0) + (hasDigit ? 1 : 0) + (hasSpecial ? 1 : 0);
    if (password.length >= 8 && score >= 2) return 'strong';
    if (password.length >= 6 && score >= 1) return 'medium';
    return 'weak';
  }

  Color _getStrengthColor(String strength) {
    switch (strength) {
      case 'strong':
        return AppColors.success;
      case 'medium':
        return AppColors.accent;
      case 'weak':
        return AppColors.error;
      default:
        return Colors.transparent;
    }
  }

  void _createAccount() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      _showError("Please select your child's date of birth");
      return;
    }
    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSuccessDialog();
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.buttonGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Account Created!',
              style: GoogleFonts.nunito(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Welcome to GYMACK! ${_childNameController.text.trim()}\'s learning journey starts now.',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textMedium,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context)
                        .popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Start Learning',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          _buildStepIndicator(),
          Expanded(
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPasswordSection(),
                        const SizedBox(height: 32),
                        _buildChildProfileSection(),
                        const SizedBox(height: 40),
                        _buildCreateButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.tealGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'GYMACK',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 3,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Account Setup',
                style: GoogleFonts.nunito(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Set your password & add child profile',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
      child: Row(
        children: [
          _StepDot(label: '1', title: 'Sign Up', isCompleted: true, isActive: false),
          _StepConnector(isCompleted: true),
          _StepDot(label: '2', title: 'Setup', isCompleted: false, isActive: true),
          _StepConnector(isCompleted: false),
          _StepDot(label: '3', title: 'Learn', isCompleted: false, isActive: false),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    final strength = _getPasswordStrength(_passwordController.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.lock_outline_rounded,
          title: 'Parent Password',
          subtitle: 'This protects your parent account settings',
          color: AppColors.secondary,
        ),
        const SizedBox(height: 20),
        _buildFieldLabel('Password'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: !_showPassword,
          onChanged: (_) => setState(() {}),
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
          decoration: InputDecoration(
            hintText: 'Create a strong password',
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                color: AppColors.secondary, size: 20),
            suffixIcon: GestureDetector(
              onTap: () => setState(() => _showPassword = !_showPassword),
              child: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textLight,
                size: 20,
              ),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please create a password';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
        if (_passwordController.text.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildPasswordStrength(strength),
        ],
        const SizedBox(height: 16),
        _buildFieldLabel('Confirm Password'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: !_showConfirmPassword,
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
          decoration: InputDecoration(
            hintText: 'Re-enter your password',
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                color: AppColors.secondary, size: 20),
            suffixIcon: GestureDetector(
              onTap: () => setState(
                  () => _showConfirmPassword = !_showConfirmPassword),
              child: Icon(
                _showConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textLight,
                size: 20,
              ),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your password';
            }
            if (value != _passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPasswordStrength(String strength) {
    final color = _getStrengthColor(strength);
    final percent = strength == 'strong'
        ? 1.0
        : strength == 'medium'
            ? 0.6
            : 0.3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Icon(Icons.circle, size: 6, color: color),
            const SizedBox(width: 5),
            Text(
              'Password strength: ${strength[0].toUpperCase()}${strength.substring(1)}',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChildProfileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.child_care_rounded,
          title: "Child's Profile",
          subtitle: 'This helps us personalize the learning experience',
          color: AppColors.primary,
        ),
        const SizedBox(height: 20),
        _buildFieldLabel("Child's Name"),
        const SizedBox(height: 8),
        TextFormField(
          controller: _childNameController,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
          decoration: InputDecoration(
            hintText: "Enter child's first name",
            prefixIcon: const Icon(Icons.person_outline_rounded,
                color: AppColors.primary, size: 20),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return "Please enter your child's name";
            }
            if (value.trim().length < 2) {
              return 'Name must be at least 2 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildFieldLabel('Date of Birth'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _selectDate(context),
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedDate != null
                    ? AppColors.primary
                    : AppColors.border,
                width: _selectedDate != null ? 2 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cake_outlined,
                  color: _selectedDate != null
                      ? AppColors.primary
                      : AppColors.textLight,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  _selectedDate != null
                      ? DateFormat('MMMM d, yyyy').format(_selectedDate!)
                      : 'Select date of birth',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: _selectedDate != null
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: _selectedDate != null
                        ? AppColors.textDark
                        : AppColors.textLight,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.textLight,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (_selectedDate != null) ...[
          const SizedBox(height: 10),
          _buildAgeDisplay(),
        ],
      ],
    );
  }

  Widget _buildAgeDisplay() {
    final now = DateTime.now();
    final age = now.year -
        _selectedDate!.year -
        (now.month < _selectedDate!.month ||
                (now.month == _selectedDate!.month &&
                    now.day < _selectedDate!.day)
            ? 1
            : 0);
    final isInRange = age >= 3 && age <= 10;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isInRange
            ? AppColors.success.withOpacity(0.08)
            : AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isInRange
              ? AppColors.success.withOpacity(0.3)
              : AppColors.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isInRange
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded,
            size: 18,
            color: isInRange ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isInRange
                  ? '$age years old — great fit for GYMACK!'
                  : '$age years old — GYMACK is designed for ages 3–10',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isInRange ? AppColors.success : AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMedium,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.nunito(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textMedium,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildCreateButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 58,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.buttonGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      'Create Account',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'By creating an account, you confirm all information above is accurate.',
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textLight,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final String title;
  final bool isCompleted;
  final bool isActive;

  const _StepDot({
    required this.label,
    required this.title,
    required this.isCompleted,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    Color dotColor = isCompleted
        ? AppColors.success
        : isActive
            ? AppColors.secondary
            : AppColors.border;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: (isCompleted || isActive) ? dotColor : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: dotColor,
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : Text(
                    label,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isActive ? Colors.white : AppColors.textLight,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: (isCompleted || isActive) ? dotColor : AppColors.textLight,
          ),
        ),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  final bool isCompleted;

  const _StepConnector({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Container(
          height: 2,
          color: isCompleted ? AppColors.success : AppColors.border,
        ),
      ),
    );
  }
}
