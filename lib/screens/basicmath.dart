// lib/screens/basic_math_activity_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nyota/theme.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';

class BasicMathActivityScreen extends StatefulWidget {
  final VoidCallback onSessionComplete;
  final String? rewardImagePath;
  final String sessionMode;

  const BasicMathActivityScreen({
    super.key,
    required this.onSessionComplete,
    this.rewardImagePath,
    this.sessionMode = 'mixed',
  });

  @override
  State<BasicMathActivityScreen> createState() => _BasicMathActivityScreenState();
}

class _BasicMathActivityScreenState extends State<BasicMathActivityScreen> {
  int currentTrial = 0;
  final int totalTrials = 10;
  int currentLevel = 1;
  int correctCount = 0;

  late int a, b, answer;
  bool isAddition = true;
  late List<int> choices;
  bool showHint = false;

  late FlutterTts flutterTts;

  @override
  void initState() {
    super.initState();
    _initTTS();
    

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _loadLevel().then((_) => _generateNewTrial());
  }

  Future<void> _initTTS() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.75);      // slower and clearer for children
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
    setState(() => currentLevel = prefs.getInt('basicmath_level') ?? 1);
  }

  Future<void> _saveLevel() async {
    final accuracy = (correctCount / totalTrials * 100).round();
    final prefs = await SharedPreferences.getInstance();
    if (accuracy >= 85 && currentLevel < 4) currentLevel++;
    else if (accuracy < 70 && currentLevel > 1) currentLevel--;
    await prefs.setInt('basicmath_level', currentLevel);
  }

  void _generateNewTrial() {
  setState(() {
    // Respect sessionMode
    if (widget.sessionMode == 'addition') isAddition = true;
    else if (widget.sessionMode == 'subtraction') isAddition = false;
    else isAddition = Random().nextBool();

    final maxNum = currentLevel == 1 ? 5 : currentLevel == 2 ? 7 : currentLevel == 3 ? 10 : 13;

    if (isAddition) {
      a = Random().nextInt(maxNum - 1) + 2;           // 2 to maxNum
      b = Random().nextInt(maxNum - a + 1) + 1;       // now always safe
      answer = a + b;
    } else {
      a = Random().nextInt(maxNum) + 4;
      b = Random().nextInt(a - 1) + 1;
      answer = a - b;
    }

    // Safer distractors (wider range so they feel different)
    choices = [answer];
    while (choices.length < 3) {
      final offset = Random().nextInt(7) - 3;        // -3 to +3
      final distr = answer + offset;
      if (distr > 0 && distr != answer && !choices.contains(distr)) {
        choices.add(distr);
      }
    }
    choices.shuffle();
    showHint = false;
  });

  Future.delayed(const Duration(milliseconds: 500), () {
    _speak(isAddition ? "$a plus $b" : "$a minus $b");
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildGroup(a, Colors.redAccent),
        Icon(
          isAddition ? Icons.add : Icons.remove,
          size: 48.w,
          color: AppTheme.primary,
        ),
        _buildGroup(b, isAddition ? Colors.blueAccent : Colors.grey),
      ],
    );
  }

  Widget _buildGroup(int count, Color color) {
    return Wrap(
      spacing: 6.w,
      runSpacing: 6.h,
      children: List.generate(count, (_) => Icon(
        Icons.circle,
        size: 28.w,
        color: color,
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
                    style: GoogleFonts.fredoka(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  IconButton(
                    onPressed: () => setState(() => showHint = true),
                    icon: Icon(Icons.help_outline_rounded, color: AppTheme.primary, size: 28.w),
                  ),
                  IconButton(
                    onPressed: () => _speak(isAddition ? "$a plus $b" : "$a minus $b"),
                    icon: Icon(Icons.volume_up_rounded, color: AppTheme.primary, size: 28.w),
                  ),
                ],
              ),
            ),

            const Spacer(),

            Container(
              width: 300.w,
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(32.r),
              ),
              child: _buildProblem(),
            ),

            const Spacer(),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: choices.map((num) {
                  final isHinted = num == answer && showHint;
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
                      child: Center(
                        child: Text(
                          num.toString(),
                          style: GoogleFonts.fredoka(
                            fontSize: 42.sp,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
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