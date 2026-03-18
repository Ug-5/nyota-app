// lib/screens/shapes_activity_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nyota/theme.dart';

class ShapesActivityScreen extends StatefulWidget {
  final VoidCallback onSessionComplete;
  final String? rewardImagePath;

  const ShapesActivityScreen({
    super.key,
    required this.onSessionComplete,
    this.rewardImagePath,
  });

  @override
  State<ShapesActivityScreen> createState() => ShapesActivityScreenState();
}

class ShapesActivityScreenState extends State<ShapesActivityScreen> {
  int currentTrial = 0;
  final int totalTrials = 10;

  late String targetShape;
  late List<String> choices;
  bool showHint = false;

  int currentLevel = 1;
  int correctCount = 0;

  late FlutterTts flutterTts;

  final List<String> _shapePool = [
    'circle', 'square', 'triangle', 'star',
    'rectangle', 'oval', 'diamond', 'heart',
    'hexagon', 'pentagon'
  ];

  @override
  void initState() {
    super.initState();

    // Lock to landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _initTTS();
    _loadProgress();
    _generateNewTrial();
  }

  @override
  void dispose() {
    // Restore all orientations
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    flutterTts.stop();
    super.dispose();
  }

  Future<void> _initTTS() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.75); // slower → clearer for children
    await flutterTts.setVolume(0.95);
    await flutterTts.setPitch(1.0);
  }

Future<void> _speak(String text) async {
  final prefs = await SharedPreferences.getInstance();
  final soundEnabled = prefs.getBool('sound_enabled') ?? true;
  if (soundEnabled) {
    await flutterTts.speak(text);
  }
}

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => currentLevel = prefs.getInt('shapes_level') ?? 1);
  }

  Future<void> _saveProgress() async {
    final accuracy = (correctCount / totalTrials * 100).round();
    final prefs = await SharedPreferences.getInstance();

    if (accuracy >= 85 && currentLevel < 4) currentLevel++;
    else if (accuracy < 70 && currentLevel > 1) currentLevel--;

    await prefs.setInt('shapes_level', currentLevel);
  }

  void _generateNewTrial() {
    setState(() {
      final available = _getShapesForLevel(currentLevel);
      targetShape = available[Random().nextInt(available.length)];

      choices = [targetShape];
      while (choices.length < 3) {
        final distr = available[Random().nextInt(available.length)];
        if (distr != targetShape && !choices.contains(distr)) choices.add(distr);
      }
      choices.shuffle();
      showHint = false;
    });

    // Speak the target shape after a short delay
    Future.delayed(const Duration(milliseconds: 800), () {
      _speak("This is a $targetShape");
    });
  }

  List<String> _getShapesForLevel(int level) {
    switch (level) {
      case 1: return ['circle', 'square', 'triangle', 'star'];
      case 2: return ['circle', 'square', 'triangle', 'star', 'rectangle', 'oval'];
      case 3: return ['circle', 'square', 'triangle', 'star', 'rectangle', 'oval', 'diamond', 'heart'];
      default: return _shapePool;
    }
  }

  void _handleTap(String selected) {
    if (selected == targetShape) {
      correctCount++;
      _speak("Great job!");
      Future.delayed(const Duration(milliseconds: 900), () {
        currentTrial++;
        if (currentTrial >= totalTrials) {
          _saveProgress();
          widget.onSessionComplete();
        } else {
          _generateNewTrial();
        }
      });
    } else {
      setState(() => showHint = true);
      _speak("Try again");
    }
  }

  Widget _buildShape(String shapeName, double size, {bool isHint = false}) {
    final color = isHint ? AppTheme.success : AppTheme.primary;

    switch (shapeName) {
      case 'circle':
        return Container(
          width: size.w,
          height: size.h,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.25),
            border: Border.all(color: color, width: 6.w),
          ),
        );
      case 'square':
        return Container(
          width: size.w,
          height: size.h,
          decoration: BoxDecoration(
            color: color.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: color, width: 6.w),
          ),
        );
      case 'rectangle':
        return Container(
          width: size.w * 1.4,
          height: size.h,
          decoration: BoxDecoration(
            color: color.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: color, width: 6.w),
          ),
        );
      case 'triangle':
        return CustomPaint(
          size: Size(size.w, size.h),
          painter: _TrianglePainter(color: color),
        );
      case 'star':
        return Icon(Icons.star_rounded, size: size.w, color: color);
      case 'oval':
        return Container(
          width: size.w * 1.3,
          height: size.h * 0.8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.25),
            border: Border.all(color: color, width: 6.w),
          ),
        );
      case 'diamond':
        return Transform.rotate(
          angle: pi / 4,
          child: Container(
            width: size.w * 0.9,
            height: size.h * 0.9,
            decoration: BoxDecoration(
              color: color.withOpacity(0.25),
              border: Border.all(color: color, width: 6.w),
            ),
          ),
        );
      case 'heart':
        return Icon(Icons.favorite_rounded, size: size.w, color: color);
      default:
        return Icon(Icons.circle, size: size.w, color: color);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress + controls
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 8.h),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (currentTrial + 1) / totalTrials,
                      backgroundColor: AppTheme.surfaceVariant,
                      color: AppTheme.primary,
                      minHeight: 14.h,
                      borderRadius: BorderRadius.circular(7.r),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Text(
                    '${currentTrial + 1} / $totalTrials',
                    style: GoogleFonts.fredoka(fontSize: 18.sp, fontWeight: FontWeight.w600, color: AppTheme.primary),
                  ),
                  SizedBox(width: 8.w),
                  IconButton(
                    onPressed: () => setState(() => showHint = true),
                    icon: Icon(Icons.help_outline_rounded, color: AppTheme.primary, size: 28.w),
                  ),
                  IconButton(
                    onPressed: () => _speak("This is a $targetShape"),
                    icon: Icon(Icons.volume_up_rounded, color: AppTheme.primary, size: 28.w),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Big target shape
            Container(
              width: 280.w,
              height: 280.h,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(32.r),
              ),
              child: Center(child: _buildShape(targetShape, 220.w)),
            ),

            const Spacer(),

            // 3 choice cards
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: choices.map((shape) {
                  final isHintedCorrect = shape == targetShape && showHint;
                  return GestureDetector(
                    onTap: () => _handleTap(shape),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 120.w,
                      height: 130.h,
                      decoration: BoxDecoration(
                        color: isHintedCorrect ? AppTheme.success.withOpacity(0.25) : AppTheme.surface,
                        borderRadius: BorderRadius.circular(28.r),
                        border: Border.all(
                          color: isHintedCorrect ? AppTheme.success : AppTheme.surfaceVariant,
                          width: isHintedCorrect ? 8.w : 4.w,
                        ),
                      ),
                      child: Center(child: _buildShape(shape, 78.w, isHint: isHintedCorrect)),
                    ),
                  );
                }).toList(),
              ),
            ),

            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
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