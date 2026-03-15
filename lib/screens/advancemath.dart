// lib/screens/advanced_math_activity_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nyota/theme.dart';
import 'package:flutter_tts/flutter_tts.dart';  
class AdvancedMathActivityScreen extends StatefulWidget {
  final VoidCallback onSessionComplete;
  final String? rewardImagePath;
  final String sessionMode;

  const AdvancedMathActivityScreen({
    super.key,
    required this.onSessionComplete,
    this.rewardImagePath,
    this.sessionMode = 'mixed',
  });

  @override
  State<AdvancedMathActivityScreen> createState() => _AdvancedMathActivityScreenState();
}

class _AdvancedMathActivityScreenState extends State<AdvancedMathActivityScreen> {
  int currentTrial = 0;
  final int totalTrials = 10;
  int currentLevel = 1;
  int correctCount = 0;

  late int a, b, answer;
  bool isMultiplication = true;
  late List<int> choices;
  bool showHint = false;

  // TTS
  late FlutterTts flutterTts;

  @override
  void initState() {
    super.initState();
    _initTTS();
    _loadLevel();
    _generateNewTrial();
  }

  Future<void> _initTTS() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.9);
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

  Future<void> _loadLevel() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => currentLevel = prefs.getInt('advancedmath_level') ?? 1);
  }

  Future<void> _saveLevel() async {
    final accuracy = (correctCount / totalTrials * 100).round();
    final prefs = await SharedPreferences.getInstance();
    if (accuracy >= 85 && currentLevel < 4) currentLevel++;
    else if (accuracy < 70 && currentLevel > 1) currentLevel--;
    await prefs.setInt('advancedmath_level', currentLevel);
  }

  void _generateNewTrial() {
    setState(() {
      if (widget.sessionMode == 'multiplication') isMultiplication = true;
      else if (widget.sessionMode == 'division') isMultiplication = false;
      else isMultiplication = Random().nextBool();

      final maxNum = currentLevel == 1 ? 5 : currentLevel == 2 ? 7 : currentLevel == 3 ? 10 : 12;

      if (isMultiplication) {
        a = Random().nextInt(maxNum) + 2;
        b = Random().nextInt(maxNum - 1) + 2;
        answer = a * b;
      } else {
        b = Random().nextInt(maxNum) + 2;
        final maxMultiplier = currentLevel == 1 ? 4 : currentLevel == 2 ? 5 : currentLevel == 3 ? 7 : 8;
        final multiplier = Random().nextInt(maxMultiplier - 1) + 2;
        a = b * multiplier;
        answer = multiplier;
      }

      choices = [answer];
      while (choices.length < 3) {
        final distr = answer + Random().nextInt(6) - 3;
        if (distr > 0 && distr != answer && !choices.contains(distr)) choices.add(distr);
      }
      choices.shuffle();
      showHint = false;
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      _speak(isMultiplication ? "$a times $b" : "$a divided by $b");
    });
  }

  void _handleTap(int selected) {
    if (selected == answer) {
      correctCount++;
      _speak("Great job!");
      Future.delayed(const Duration(milliseconds: 900), () {
        currentTrial++;
        if (currentTrial >= totalTrials) {
          _saveLevel();
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

  Widget _buildProblem() {
    return Column(
      children: [
        Text(isMultiplication ? '$a × $b' : '$a ÷ $b', style: GoogleFonts.fredoka(fontSize: 42, fontWeight: FontWeight.w700, color: AppTheme.primary)),
        const SizedBox(height: 20),
        isMultiplication ? _buildGrid(a, b) : _buildDivisionGroups(a, b),
      ],
    );
  }

  Widget _buildGrid(int rows, int cols) {
    return Wrap(spacing: 8, runSpacing: 8, children: List.generate(rows * cols, (_) => Icon(Icons.circle, size: 24, color: AppTheme.primary)));
  }

  Widget _buildDivisionGroups(int total, int perGroup) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: List.generate(total ~/ perGroup, (_) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(border: Border.all(color: AppTheme.primary, width: 2), borderRadius: BorderRadius.circular(12)),
        child: Wrap(children: List.generate(perGroup, (_) => Icon(Icons.circle, size: 18, color: AppTheme.primary))),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  Expanded(child: LinearProgressIndicator(value: (currentTrial + 1) / totalTrials, backgroundColor: AppTheme.surfaceVariant, color: AppTheme.primary, minHeight: 14, borderRadius: BorderRadius.circular(7))),
                  const SizedBox(width: 16),
                  Text('${currentTrial + 1} / $totalTrials', style: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                  const SizedBox(width: 8),
                  IconButton(onPressed: () => setState(() => showHint = true), icon: const Icon(Icons.help_outline_rounded, color: AppTheme.primary, size: 28)),
                  IconButton(onPressed: () => _speak(isMultiplication ? "$a times $b" : "$a divided by $b"), icon: const Icon(Icons.volume_up_rounded, color: AppTheme.primary, size: 28)),
                ],
              ),
            ),

            const Spacer(),

            Container(
              width: 300,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(32)),
              child: _buildProblem(),
            ),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: choices.map((num) {
                  final isHinted = num == answer && showHint;
                  return GestureDetector(
                    onTap: () => _handleTap(num),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 100,
                      height: 110,
                      decoration: BoxDecoration(
                        color: isHinted ? AppTheme.success.withOpacity(0.25) : AppTheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: isHinted ? AppTheme.success : AppTheme.surfaceVariant, width: isHinted ? 7 : 3),
                      ),
                      child: Center(child: Text(num.toString(), style: GoogleFonts.fredoka(fontSize: 42, fontWeight: FontWeight.w700, color: AppTheme.primary))),
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