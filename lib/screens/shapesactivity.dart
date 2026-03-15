// lib/screens/shapes_activity_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nyota/theme.dart';
import 'package:flutter_tts/flutter_tts.dart';   // ← NEW

class ShapesActivityScreen extends StatefulWidget {
  final VoidCallback onSessionComplete;
  final String? rewardImagePath;

  const ShapesActivityScreen({
    super.key,
    required this.onSessionComplete,
    this.rewardImagePath,
  });

  @override
  State<ShapesActivityScreen> createState() => _ShapesActivityScreenState();
}

class _ShapesActivityScreenState extends State<ShapesActivityScreen> {
  int currentTrial = 0;
  final int totalTrials = 10;

  late String targetShape;
  late List<String> choices;
  bool showHint = false;

  int currentLevel = 1;
  int correctCount = 0;

  // TTS
  late FlutterTts flutterTts;

  final List<String> _shapePool = [
    'circle', 'square', 'triangle', 'star',
    'rectangle', 'oval', 'diamond', 'heart',
    'hexagon', 'pentagon'
  ];

  @override
  void initState() {
    super.initState();
    _initTTS();
    _loadProgress();
    _generateNewTrial();
  }

  Future<void> _initTTS() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.9);     // nice slow speed for kids
    await flutterTts.setVolume(0.9);
    await flutterTts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    await flutterTts.speak(text);
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => currentLevel = prefs.getInt('shapes_level') ?? 1);
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final accuracy = (correctCount / totalTrials * 100).round();

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

    // Auto-speak the new target (very helpful for 3-year-olds)
    Future.delayed(const Duration(milliseconds: 400), () {
      _speak("This is a $targetShape");
    });
  }

  List<String> _getShapesForLevel(int level) {
    switch (level) {
      case 1:
        return ['circle', 'square', 'triangle', 'star'];
      case 2:
        return ['circle', 'square', 'triangle', 'star', 'rectangle', 'oval'];
      case 3:
        return ['circle', 'square', 'triangle', 'star', 'rectangle', 'oval', 'diamond', 'heart'];
      case 4:
        return _shapePool;
      default:
        return _shapePool;
    }
  }

  void _handleTap(String selected) {
    if (selected == targetShape) {
      correctCount++;
      _speak("Great job!");                    // positive sound feedback
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
      _speak("Try again");                     // gentle correction
    }
  }

  Widget _buildShape(String shapeName, double size, {bool isHint = false}) {
    final color = isHint ? AppTheme.success : AppTheme.primary;
    // (same shape builder as before – unchanged for brevity)
    switch (shapeName) {
      case 'circle':
        return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.25), border: Border.all(color: color, width: 6)));
      case 'square':
        return Container(width: size, height: size, decoration: BoxDecoration(color: color.withOpacity(0.25), borderRadius: BorderRadius.circular(12), border: Border.all(color: color, width: 6)));
      case 'rectangle':
        return Container(width: size * 1.4, height: size, decoration: BoxDecoration(color: color.withOpacity(0.25), borderRadius: BorderRadius.circular(12), border: Border.all(color: color, width: 6)));
      case 'triangle':
        return CustomPaint(size: Size(size, size), painter: _TrianglePainter(color: color));
      case 'star':
        return Icon(Icons.star_rounded, size: size, color: color);
      case 'oval':
        return Container(width: size * 1.3, height: size * 0.8, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.25), border: Border.all(color: color, width: 6)));
      case 'diamond':
        return Transform.rotate(angle: pi / 4, child: Container(width: size * 0.9, height: size * 0.9, decoration: BoxDecoration(color: color.withOpacity(0.25), border: Border.all(color: color, width: 6))));
      case 'heart':
        return Icon(Icons.favorite_rounded, size: size, color: color);
      default:
        return Icon(Icons.circle, size: size, color: color);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar + counter + Help + SPEAKER buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (currentTrial + 1) / totalTrials,
                      backgroundColor: AppTheme.surfaceVariant,
                      color: AppTheme.primary,
                      minHeight: 14,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text('${currentTrial + 1} / $totalTrials', style: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => setState(() => showHint = true),
                    icon: const Icon(Icons.help_outline_rounded, color: AppTheme.primary, size: 28),
                  ),
                  IconButton(                                      // ← NEW SPEAKER BUTTON
                    onPressed: () => _speak("This is a $targetShape"),
                    icon: const Icon(Icons.volume_up_rounded, color: AppTheme.primary, size: 28),
                  ),
                ],
              ),
            ),

            const Spacer(),

            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(32)),
              child: Center(child: _buildShape(targetShape, 220)),
            ),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: choices.map((shape) {
                  final isHintedCorrect = shape == targetShape && showHint;
                  return GestureDetector(
                    onTap: () => _handleTap(shape),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 120,
                      height: 130,
                      decoration: BoxDecoration(
                        color: isHintedCorrect ? AppTheme.success.withOpacity(0.25) : AppTheme.surface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: isHintedCorrect ? AppTheme.success : AppTheme.surfaceVariant, width: isHintedCorrect ? 8 : 4),
                      ),
                      child: Center(child: _buildShape(shape, 78, isHint: isHintedCorrect)),
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

// Triangle painter (unchanged)
class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path()..moveTo(size.width / 2, 0)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}