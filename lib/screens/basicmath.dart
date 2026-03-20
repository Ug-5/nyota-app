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
  final int? maxDurationMinutes; // ← NEW

  const BasicMathActivityScreen({
    super.key,
    required this.onSessionComplete,
    this.rewardImagePath,
    this.sessionMode = 'mixed',
    this.maxDurationMinutes,
  });

  @override
  State<BasicMathActivityScreen> createState() => _BasicMathActivityScreenState();
}

class _BasicMathActivityScreenState extends State<BasicMathActivityScreen> {
  int currentTrial = 0;
  final int questionsPerLevel = 10;
  int currentLevel = 1;
  final int maxLevel = 4;
  int correctInLevel = 0;
  int totalCorrect = 0;

  int a = 2, b = 1, answer = 3;
  bool isAddition = true;
  List<int> choices = [];
  bool showHint = false;

  FlutterTts flutterTts = FlutterTts();
  DateTime? sessionStartTime;

  @override
  void initState() {
    super.initState();
    _initTTS();
    sessionStartTime = DateTime.now();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _loadLevel().then((_) => _generateNewTrial());
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

  @override
  void dispose() {
    flutterTts.stop();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> _loadLevel() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => currentLevel = prefs.getInt('basicmath_level') ?? 1);
  }

  Future<void> _saveLevel() async {
    final prefs = await SharedPreferences.getInstance();
    final accuracy = totalCorrect > 0 ? (totalCorrect / (currentTrial + 1) * 100).round() : 0;
    if (accuracy >= 85 && currentLevel < maxLevel) currentLevel++;
    else if (accuracy < 70 && currentLevel > 1) currentLevel--;
    await prefs.setInt('basicmath_level', currentLevel);
  }

  bool _timeIsUp() {
    if (widget.maxDurationMinutes == null || sessionStartTime == null) return false;
    final elapsed = DateTime.now().difference(sessionStartTime!).inMinutes;
    return elapsed >= widget.maxDurationMinutes!;
  }

  void _generateNewTrial() {
    if (_timeIsUp()) {
      _endSessionGracefully();
      return;
    }

    setState(() {
      if (widget.sessionMode == 'addition') isAddition = true;
      else if (widget.sessionMode == 'subtraction') isAddition = false;
      else isAddition = Random().nextBool();

      final maxNum = [5, 7, 10, 13][currentLevel - 1].clamp(5, 13);

      if (isAddition) {
        a = Random().nextInt(maxNum - 1) + 2;
        b = Random().nextInt(maxNum - a + 1);
        answer = a + b;
      } else {
        a = Random().nextInt(maxNum) + 2;
        b = Random().nextInt(a - 1) + 1;
        answer = a - b;
      }

      choices = [answer];
      while (choices.length < 3) {
        final distr = answer + Random().nextInt(9) - 4;
        if (distr > 0 && distr != answer && !choices.contains(distr)) choices.add(distr);
      }
      choices.shuffle();
      showHint = false;
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      _speak(isAddition ? "$a plus $b" : "$a minus $b");
    });
  }

  void _handleTap(int selected) {
    if (_timeIsUp()) {
      _endSessionGracefully();
      return;
    }

    final isCorrect = selected == answer;

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
          _speak("Level up! Let's try harder sums!");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Level $currentLevel unlocked! 🌟"),
              backgroundColor: AppTheme.success,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        if (currentTrial >= questionsPerLevel * maxLevel || _timeIsUp()) {
          _saveLevel();
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
          content: Text("Fantastic streak! $correctInLevel correct! ⭐⭐⭐"),
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

  Widget _buildProblem() {
    return Text(
      isAddition ? '$a + $b' : '$a - $b',
      style: GoogleFonts.fredoka(fontSize: 48.sp, fontWeight: FontWeight.w700, color: AppTheme.primary),
    );
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
                  child: Center(child: _buildProblem()),
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
                              style: GoogleFonts.fredoka(fontSize: 42.sp, fontWeight: FontWeight.w700, color: AppTheme.primary),
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