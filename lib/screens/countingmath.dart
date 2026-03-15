// lib/screens/counting_activity_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nyota/theme.dart';
import 'package:flutter_tts/flutter_tts.dart';   

class CountingActivityScreen extends StatefulWidget {
  final VoidCallback onSessionComplete;
  final String? rewardImagePath;

  const CountingActivityScreen({
    super.key,
    required this.onSessionComplete,
    this.rewardImagePath,
  });

  @override
  State<CountingActivityScreen> createState() => _CountingActivityScreenState();
}

class _CountingActivityScreenState extends State<CountingActivityScreen> {
  int currentTrial = 0;
  final int totalTrials = 10;
  int currentLevel = 1;
  int correctCount = 0;

  late int targetCount;
  late List<int> choices;
  bool showHint = false;

  // TTS
  late FlutterTts flutterTts;

  final List<IconData> objectIcons = [
    Icons.star_rounded,
    Icons.circle,
    Icons.favorite,
    Icons.rocket_launch,
    Icons.pets,
  ];

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
    setState(() => currentLevel = prefs.getInt('counting_level') ?? 1);
  }

  Future<void> _saveLevel() async {
    final accuracy = (correctCount / totalTrials * 100).round();
    final prefs = await SharedPreferences.getInstance();
    if (accuracy >= 85 && currentLevel < 4) currentLevel++;
    else if (accuracy < 70 && currentLevel > 1) currentLevel--;
    await prefs.setInt('counting_level', currentLevel);
  }

  void _generateNewTrial() {
    setState(() {
      final maxObjects = currentLevel == 1 ? 5 : currentLevel == 2 ? 7 : currentLevel == 3 ? 10 : 13;
      targetCount = Random().nextInt(maxObjects - 3) + 4;

      choices = [targetCount];
      while (choices.length < 3) {
        final distr = Random().nextInt(maxObjects - 3) + 4;
        if (distr != targetCount && !choices.contains(distr)) choices.add(distr);
      }
      choices.shuffle();
      showHint = false;
    });

    // Auto-speak for 3-year-olds
    Future.delayed(const Duration(milliseconds: 400), () {
      _speak("How many objects do you see?");
    });
  }

  void _handleTap(int selected) {
    if (selected == targetCount) {
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

  Widget _buildObjects(int count, double size) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: List.generate(count, (_) => Icon(objectIcons[Random().nextInt(objectIcons.length)], size: size, color: AppTheme.primary)),
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
                  IconButton(onPressed: () => setState(() => showHint = true), icon: const Icon(Icons.help_outline_rounded, color: AppTheme.primary, size: 28)),
                  IconButton(onPressed: () => _speak("How many objects do you see?"), icon: const Icon(Icons.volume_up_rounded, color: AppTheme.primary, size: 28)),
                ],
              ),
            ),

            const Spacer(),

            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(32)),
              child: Center(child: _buildObjects(targetCount, 42)),
            ),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: choices.map((num) {
                  final isHinted = num == targetCount && showHint;
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(num.toString(), style: GoogleFonts.fredoka(fontSize: 32, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                          const SizedBox(height: 6),
                          _buildObjects(num, 14),
                        ],
                      ),
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