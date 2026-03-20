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
  final int? maxDurationMinutes; // ← NEW

  const ShapesActivityScreen({
    super.key,
    required this.onSessionComplete,
    this.rewardImagePath,
    this.maxDurationMinutes,
  });

  @override
  State<ShapesActivityScreen> createState() => ShapesActivityScreenState();
}

class ShapesActivityScreenState extends State<ShapesActivityScreen> {
  int currentTrial = 0;
  final int questionsPerLevel = 10;
  int currentLevel = 1;
  final int maxLevel = 4;
  int correctInLevel = 0;
  int totalCorrect = 0;

  String targetShape = '';
  List<String> choices = [];
  bool showHint = false;

  FlutterTts flutterTts = FlutterTts();
  DateTime? sessionStartTime;

  final List<String> _shapePool = [
    'circle', 'square', 'triangle', 'star',
    'rectangle', 'oval', 'diamond', 'heart',
    'hexagon', 'pentagon'
  ];

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _initTTS();
    sessionStartTime = DateTime.now();
    _loadProgress().then((_) => _generateNewTrial());
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    flutterTts.stop();
    super.dispose();
  }

  Future<void> _initTTS() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.75);
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
    final prefs = await SharedPreferences.getInstance();
    final accuracy = totalCorrect > 0 ? (totalCorrect / (currentTrial + 1) * 100).round() : 0;
    if (accuracy >= 85 && currentLevel < maxLevel) currentLevel++;
    else if (accuracy < 70 && currentLevel > 1) currentLevel--;
    await prefs.setInt('shapes_level', currentLevel);
  }

  bool _timeIsUp() {
    if (widget.maxDurationMinutes == null || sessionStartTime == null) return false;
    final elapsed = DateTime.now().difference(sessionStartTime!).inMinutes;
    return elapsed >= widget.maxDurationMinutes!;
  }

  List<String> _getShapesForLevel(int level) {
    switch (level) {
      case 1:
        return ['circle', 'square', 'triangle'];
      case 2:
        return ['circle', 'square', 'triangle', 'star', 'rectangle'];
      case 3:
        return ['circle', 'square', 'triangle', 'star', 'rectangle', 'oval', 'diamond'];
      case 4:
      default:
        return _shapePool;
    }
  }

  void _generateNewTrial() {
    if (_timeIsUp()) {
      _endSessionGracefully();
      return;
    }

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

    Future.delayed(const Duration(milliseconds: 400), () {
      _speak("Find the $targetShape");
    });
  }

  void _handleTap(String selected) {
    if (_timeIsUp()) {
      _endSessionGracefully();
      return;
    }

    final isCorrect = selected == targetShape;

    setState(() {
      if (isCorrect) {
        correctInLevel++;
        totalCorrect++;
        _speak("Great job!");
        _showMiniRewardIfNeeded();
      } else {
        showHint = true;
        _speak("Try again");
      }
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (isCorrect) {
        currentTrial++;

        // Auto level-up
        if (correctInLevel >= questionsPerLevel && currentLevel < maxLevel) {
          setState(() {
            currentLevel++;
            correctInLevel = 0;
          });
          _speak("Level up! Let's find more shapes!");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Level $currentLevel unlocked! 🌟"),
              backgroundColor: AppTheme.success,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        if (currentTrial >= questionsPerLevel * maxLevel || _timeIsUp()) {
          _saveProgress();
          _endSessionGracefully();
        } else {
          _generateNewTrial();
        }
      }
    });
  }

  void _showMiniRewardIfNeeded() {
    if (correctInLevel > 0 && correctInLevel % 5 == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Amazing streak! $correctInLevel correct! ⭐⭐⭐"),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _endSessionGracefully() {
    _speak("Great work today! See you next time!");
    Future.delayed(const Duration(seconds: 2), () {
      widget.onSessionComplete();
    });
  }

  Widget _buildShape(String shape, double size, {bool isHint = false}) {
    Color color = isHint ? AppTheme.success : AppTheme.primary;

    switch (shape) {
      case 'circle':
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        );
      case 'square':
        return Container(width: size, height: size, color: color);
      case 'triangle':
        return CustomPaint(
          size: Size(size, size),
          painter: _TrianglePainter(color: color),
        );
      case 'star':
        return Icon(Icons.star_rounded, size: size, color: color);
      case 'rectangle':
        return Container(width: size * 1.4, height: size, color: color);
      case 'oval':
        return Container(
          width: size * 1.3,
          height: size,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(size / 2), color: color),
        );
      case 'diamond':
        return Transform.rotate(
          angle: pi / 4,
          child: Container(width: size * 0.7, height: size * 0.7, color: color),
        );
      case 'heart':
        return Icon(Icons.favorite, size: size, color: color);
      case 'hexagon':
      case 'pentagon':
        return Icon(Icons.polyline_rounded, size: size, color: color);
      default:
        return Icon(Icons.star_rounded, size: size, color: color);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 8.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: (currentTrial + 1) / (questionsPerLevel * maxLevel),
                          backgroundColor: AppTheme.surfaceVariant,
                          color: AppTheme.primary,
                          minHeight: 14.h,
                          borderRadius: BorderRadius.circular(7.r),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Text(
                        '${currentTrial + 1} / ${questionsPerLevel * maxLevel}',
                        style: GoogleFonts.fredoka(fontSize: 18.sp, fontWeight: FontWeight.w600, color: AppTheme.primary),
                      ),
                      SizedBox(width: 8.w),
                      IconButton(
                        onPressed: () => setState(() => showHint = true),
                        icon: Icon(Icons.help_outline_rounded, color: AppTheme.primary, size: 28.w),
                      ),
                      IconButton(
                        onPressed: () => _speak("Find the $targetShape"),
                        icon: Icon(Icons.volume_up_rounded, color: AppTheme.primary, size: 28.w),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

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

            // Time remaining display
            if (widget.maxDurationMinutes != null && sessionStartTime != null)
              Positioned(
                top: 16.h,
                right: 24.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: Text(
                    "Time left: ${widget.maxDurationMinutes! - DateTime.now().difference(sessionStartTime!).inMinutes} min",
                    style: GoogleFonts.fredoka(fontSize: 14.sp, color: AppTheme.textPrimary),
                  ),
                ),
              ),
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