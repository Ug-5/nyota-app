// lib/screens/counting_activity_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nyota/theme.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';

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

    SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  }

  Future<void> _initTTS() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.75);     // slower for better understanding
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

  @override
  void dispose() {
    flutterTts.stop();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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
    
    // Ensure we always have at least 3 possible numbers
    final minCount = 4;
    final possibleCounts = List.generate(maxObjects - minCount + 1, (i) => minCount + i);
    
    targetCount = possibleCounts[Random().nextInt(possibleCounts.length)];

    choices = [targetCount];
    while (choices.length < 3) {
      final distr = possibleCounts[Random().nextInt(possibleCounts.length)];
      if (distr != targetCount && !choices.contains(distr)) {
        choices.add(distr);
      }
    }
    choices.shuffle();
    showHint = false;
  });

  Future.delayed(const Duration(milliseconds: 500), () {
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
      spacing: 8.w,
      runSpacing: 8.h,
      alignment: WrapAlignment.center,
      children: List.generate(count, (_) => Icon(
        objectIcons[Random().nextInt(objectIcons.length)],
        size: size.w,
        color: AppTheme.primary,
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
                    onPressed: () => _speak("How many objects do you see?"),
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
              child: Center(child: _buildObjects(targetCount, 42.w)),
            ),

            const Spacer(),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: choices.map((num) {
                  final isHinted = num == targetCount && showHint;
                  return GestureDetector(
                    onTap: () => _handleTap(num),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 100.w,
                      height: 110.h,
                      decoration: BoxDecoration(
                        color: isHinted ? AppTheme.success.withOpacity(0.25) : AppTheme.surface,
                        borderRadius: BorderRadius.circular(24.r),
                        border: Border.all(
                          color: isHinted ? AppTheme.success : AppTheme.surfaceVariant,
                          width: isHinted ? 7.w : 3.w,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            num.toString(),
                            style: GoogleFonts.fredoka(fontSize: 32.sp, fontWeight: FontWeight.w700, color: AppTheme.primary),
                          ),
                          SizedBox(height: 6.h),
                          _buildObjects(num, 14.w),
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