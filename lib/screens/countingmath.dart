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
  final int? maxDurationMinutes; // ← NEW: passed from parent/child dashboard

  const CountingActivityScreen({
    super.key,
    required this.onSessionComplete,
    this.rewardImagePath,
    this.maxDurationMinutes,
  });

  @override
  State<CountingActivityScreen> createState() => _CountingActivityScreenState();
}

class _CountingActivityScreenState extends State<CountingActivityScreen> {
  int currentTrial = 0;
  final int questionsPerLevel = 10;
  int currentLevel = 1;
  final int maxLevel = 4;
  int correctInLevel = 0;
  int totalCorrect = 0;

  int targetCount = 0;
  List<int> choices = [];
  bool showHint = false;

  FlutterTts flutterTts = FlutterTts();
  DateTime? sessionStartTime;

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
    await flutterTts.setSpeechRate(0.75); // slower for better understanding
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
    setState(() => currentLevel = prefs.getInt('counting_level') ?? 1);
  }

  Future<void> _saveLevel() async {
    final prefs = await SharedPreferences.getInstance();
    final accuracy = totalCorrect > 0 ? (totalCorrect / (currentTrial + 1) * 100).round() : 0;
    if (accuracy >= 85 && currentLevel < maxLevel) {
      currentLevel++;
    } else if (accuracy < 70 && currentLevel > 1) {
      currentLevel--;
    }
    await prefs.setInt('counting_level', currentLevel);
  }

  bool _timeIsUp() {
    if (widget.maxDurationMinutes == null || sessionStartTime == null) return false;
    final elapsedMinutes = DateTime.now().difference(sessionStartTime!).inMinutes;
    return elapsedMinutes >= widget.maxDurationMinutes!;
  }

  void _generateNewTrial() {
    if (_timeIsUp()) {
      _endSessionGracefully();
      return;
    }

    setState(() {
      final maxObjects = [5, 7, 10, 13][currentLevel - 1].clamp(5, 13);

      const minCount = 4;
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
    if (_timeIsUp()) {
      _endSessionGracefully();
      return;
    }

    final isCorrect = selected == targetCount;

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

        // Automatic level progression after completing questionsPerLevel correct answers
        if (correctInLevel >= questionsPerLevel && currentLevel < maxLevel) {
          setState(() {
            currentLevel++;
            correctInLevel = 0;
          });
          _speak("Level up! Let's count even more!");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Level $currentLevel unlocked! 🌟"),
              backgroundColor: AppTheme.success,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // End session if all levels done or time is up
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