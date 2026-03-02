import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _agreedToTerms = false;
  bool _agreedToPrivacy = false;
  bool _isLoading = false;
  bool _emailHasFocus = false;
  bool _phoneHasFocus = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeIn),
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms || !_agreedToPrivacy) {
      _showAgreementError();
      return;
    }
    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushNamed(
          context,
          '/account-setup',
          arguments: {
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
          },
        );
      }
    });
  }

  void _showAgreementError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Please agree to the Terms & Conditions and Privacy Policy to continue.',
          style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
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
          Expanded(
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),
                        _buildSectionTitle('Parent Information'),
                        const SizedBox(height: 6),
                        Text(
                          'We need a few details to create your parent account and keep your child safe.',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMedium,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _buildEmailField(),
                        const SizedBox(height: 16),
                        _buildPhoneField(),
                        const SizedBox(height: 32),
                        _buildDivider(),
                        const SizedBox(height: 28),
                        _buildSectionTitle('Agreements'),
                        const SizedBox(height: 16),
                        _buildTermsCheckbox(),
                        const SizedBox(height: 12),
                        _buildPrivacyCheckbox(),
                        const SizedBox(height: 40),
                        _buildContinueButton(),
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
        gradient: AppColors.landingGradient,
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
                'Create Account',
                style: GoogleFonts.nunito(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Set up your parent account',
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.nunito(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.textDark,
      ),
    );
  }

  Widget _buildEmailField() {
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _emailHasFocus = hasFocus),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel('Email Address', Icons.email_outlined),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
            decoration: InputDecoration(
              hintText: 'parent@email.com',
              prefixIcon: Icon(
                Icons.email_outlined,
                color: _emailHasFocus ? AppColors.primary : AppColors.textLight,
                size: 20,
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email address';
              }
              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(value.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _phoneHasFocus = hasFocus),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel('Phone Number', Icons.phone_outlined),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(15),
            ],
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
            decoration: InputDecoration(
              hintText: '+1 234 567 8900',
              prefixIcon: Icon(
                Icons.phone_outlined,
                color: _phoneHasFocus ? AppColors.primary : AppColors.textLight,
                size: 20,
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your phone number';
              }
              if (value.trim().length < 7) {
                return 'Please enter a valid phone number';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, IconData icon) {
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

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Legal',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textLight,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: AppColors.border)),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return _buildAgreementRow(
      value: _agreedToTerms,
      onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
      leadingIcon: Icons.description_outlined,
      text: 'I agree to the ',
      linkText: 'Terms & Conditions',
      onLinkTap: () => _showPolicyDialog(
        'Terms & Conditions',
        'By using GYMACK, you agree to provide accurate information and use the app responsibly for educational purposes. GYMACK is designed to support children with Autism Spectrum Disorder in learning mathematics.\n\nParents/guardians are responsible for supervising their child\'s use of the application. GYMACK reserves the right to update these terms at any time with notice.',
      ),
    );
  }

  Widget _buildPrivacyCheckbox() {
    return _buildAgreementRow(
      value: _agreedToPrivacy,
      onChanged: (val) => setState(() => _agreedToPrivacy = val ?? false),
      leadingIcon: Icons.shield_outlined,
      text: 'I agree to the ',
      linkText: 'Privacy Policy',
      onLinkTap: () => _showPolicyDialog(
        'Privacy Policy',
        'GYMACK collects only the information necessary to create and manage your account. We collect parent email and phone number for account recovery purposes only.\n\nChild profiles (name and date of birth) are stored securely and are never shared with third parties. We comply with COPPA regulations for children\'s privacy.\n\nYour data is encrypted and you may request deletion at any time by contacting us.',
      ),
    );
  }

  Widget _buildAgreementRow({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required IconData leadingIcon,
    required String text,
    required String linkText,
    required VoidCallback onLinkTap,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: value
              ? AppColors.primary.withOpacity(0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value ? AppColors.primary.withOpacity(0.4) : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: value ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
              child: value
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: text,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMedium,
                      ),
                    ),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: GestureDetector(
                        onTap: onLinkTap,
                        child: Text(
                          linkText,
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPolicyDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            content,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textMedium,
              height: 1.6,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
            child: Text(
              'Got it',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        gradient: (_agreedToTerms && _agreedToPrivacy)
            ? AppColors.buttonGradient
            : null,
        color: (!_agreedToTerms || !_agreedToPrivacy)
            ? AppColors.border
            : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: (_agreedToTerms && _agreedToPrivacy)
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isLoading ? null : _continue,
          child: Center(
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
                    'Continue',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: (_agreedToTerms && _agreedToPrivacy)
                          ? Colors.white
                          : AppColors.textLight,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
