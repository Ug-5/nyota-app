import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _subtitleController;
  late AnimationController _buttonsController;
  late AnimationController _floatingController;

  late Animation<double> _logoScaleAnim;
  late Animation<double> _logoFadeAnim;
  late Animation<Offset> _logoSlideAnim;
  late Animation<double> _letterSpacingAnim;
  late Animation<double> _subtitleFadeAnim;
  late Animation<double> _buttonsFadeAnim;
  late Animation<Offset> _buttonsSlideAnim;
  late Animation<double> _floatingAnim;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _subtitleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _buttonsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _logoScaleAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _logoSlideAnim = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _letterSpacingAnim = Tween<double>(begin: 30.0, end: 8.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );

    _subtitleFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _subtitleController, curve: Curves.easeIn),
    );

    _buttonsFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonsController, curve: Curves.easeIn),
    );

    _buttonsSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _buttonsController, curve: Curves.easeOut),
    );

    _floatingAnim = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 900));
    _subtitleController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _buttonsController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _subtitleController.dispose();
    _buttonsController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF8A65),
              Color(0xFFFF7043),
              Color(0xFFFF5722),
              Color(0xFFE64A19),
            ],
            stops: [0.0, 0.35, 0.65, 1.0],
          ),
        ),
        child: Stack(
          children: [
            _buildFloatingShapes(size),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLogo(),
                        const SizedBox(height: 16),
                        _buildTagline(),
                      ],
                    ),
                  ),
                  _buildButtons(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingShapes(Size size) {
    return AnimatedBuilder(
      animation: _floatingAnim,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: size.height * 0.08 + _floatingAnim.value * 0.5,
              left: size.width * 0.05,
              child: _ShapeCircle(
                size: 80,
                color: Colors.white.withOpacity(0.12),
              ),
            ),
            Positioned(
              top: size.height * 0.15 - _floatingAnim.value * 0.3,
              right: size.width * 0.08,
              child: _ShapeCircle(
                size: 50,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
            Positioned(
              top: size.height * 0.25 + _floatingAnim.value * 0.7,
              left: size.width * 0.75,
              child: _ShapeRect(
                size: 40,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            Positioned(
              top: size.height * 0.05 + _floatingAnim.value * 0.4,
              left: size.width * 0.42,
              child: _ShapeTriangle(color: Colors.white.withOpacity(0.07)),
            ),
            Positioned(
              bottom: size.height * 0.35 - _floatingAnim.value * 0.5,
              left: size.width * 0.03,
              child: _ShapeCircle(
                size: 60,
                color: Colors.white.withOpacity(0.09),
              ),
            ),
            Positioned(
              bottom: size.height * 0.40 + _floatingAnim.value * 0.6,
              right: size.width * 0.05,
              child: _ShapeCircle(
                size: 35,
                color: Colors.white.withOpacity(0.11),
              ),
            ),
            Positioned(
              bottom: size.height * 0.28 + _floatingAnim.value * 0.3,
              right: size.width * 0.20,
              child: _ShapeRect(
                size: 28,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: Listenable.merge([_logoController]),
      builder: (context, child) {
        return SlideTransition(
          position: _logoSlideAnim,
          child: FadeTransition(
            opacity: _logoFadeAnim,
            child: ScaleTransition(
              scale: _logoScaleAnim,
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'G',
                        style: GoogleFonts.nunito(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AnimatedBuilder(
                    animation: _letterSpacingAnim,
                    builder: (context, child) {
                      return Text(
                        'GYMACK',
                        style: GoogleFonts.nunito(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: _letterSpacingAnim.value,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTagline() {
    return FadeTransition(
      opacity: _subtitleFadeAnim,
      child: Column(
        children: [
          Text(
            'Math Learning for Every Child',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.92),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMathChip('1+2'),
              const SizedBox(width: 8),
              _buildMathChip('Shapes'),
              const SizedBox(width: 8),
              _buildMathChip('Count'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMathChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    return SlideTransition(
      position: _buttonsSlideAnim,
      child: FadeTransition(
        opacity: _buttonsFadeAnim,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _GymackButton(
                      label: 'Create Account',
                      isPrimary: true,
                      onPressed: () {
                        Navigator.pushNamed(context, '/signup');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GymackButton(
                      label: 'Login',
                      isPrimary: false,
                      onPressed: () {
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Designed for children ages 3–10 with ASD',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.75),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GymackButton extends StatefulWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onPressed;

  const _GymackButton({
    required this.label,
    required this.isPrimary,
    required this.onPressed,
  });

  @override
  State<_GymackButton> createState() => _GymackButtonState();
}

class _GymackButtonState extends State<_GymackButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _pressController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: widget.isPrimary ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: widget.isPrimary
                ? null
                : Border.all(color: Colors.white, width: 2),
            boxShadow: widget.isPrimary
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              widget.label,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: widget.isPrimary ? AppColors.primary : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShapeCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _ShapeCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _ShapeRect extends StatelessWidget {
  final double size;
  final Color color;

  const _ShapeRect({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _ShapeTriangle extends StatelessWidget {
  final Color color;

  const _ShapeTriangle({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(36, 32),
      painter: _TrianglePainter(color: color),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
