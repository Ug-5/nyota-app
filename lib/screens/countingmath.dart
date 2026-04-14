import 'dart:async';
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
  final int? maxDurationMinutes;

  const CountingActivityScreen({
    super.key,
    required this.onSessionComplete,
    this.rewardImagePath,
    this.maxDurationMinutes,
  });

  @override
  State<CountingActivityScreen> createState() => _CountingActivityScreenState();
}

class _CountingActivityScreenState extends State<CountingActivityScreen>
    with TickerProviderStateMixin {   // Safe for multiple animations (future-proof)

  // Level and sublevel structure
  int currentLevel = 1;
  int currentSubLevel = 1;
  int maxLevel = 3;
  final List<int> subLevelsPerLevel = [4, 4, 4];

  int currentTrial = 0;
  int totalCorrect = 0;
  int starsEarned = 0;
  int rewardCounter = 0;

  int targetCount = 0;
  List<int> choices = [];
  bool showPrompt = false;
  bool hasAnswered = false;
  bool showHint = false;

  FlutterTts flutterTts = FlutterTts();
  DateTime? sessionStartTime;

  final List<String> objectImages = [
    'assets/images/apple.png',
    'assets/images/banana.png',
    'assets/images/ball.png',
    'assets/images/star.png',
    'assets/images/car.png',
    'assets/images/cube.png',
  ];

  List<Widget> collectedStars = [];

  late AnimationController fingerController;
  int currentHintIndex = 0;

  @override
  void initState() {
    super.initState();
    initTTS();
    sessionStartTime = DateTime.now();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    fingerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    loadLevel().then((_) => generateNewTrial());
  }

  Future<void> initTTS() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.52);
    await flutterTts.setVolume(0.92);
    await flutterTts.setPitch(1.12);
    await selectFemaleVoice();
  }

  /// Improved female voice selection (fixes male voice issue)
  Future<void> selectFemaleVoice() async {
    try {
      final voices = await flutterTts.getVoices;
      if (voices != null && voices.isNotEmpty) {
        for (var voice in voices) {
          final name = voice['name']?.toString().toLowerCase() ?? '';
          final gender = voice['gender']?.toString().toLowerCase() ?? '';
          if (gender.contains('female') || name.contains('female') || name.contains('karen') || name.contains('samantha')) {
            await flutterTts.setVoice(voice);
            return;
          }
        }
      }

      // Reliable fallback female voices (most devices support at least one)
      const femaleNames = [
        "en-us-x-tmd#female-1",
        "en-us-x-tmd#female-2",
        "Karen",                    // iOS common female
        "Samantha",                 // iOS female
        "Google UK English Female",
        "Microsoft Zira Desktop",
      ];

      for (var name in femaleNames) {
        try {
          await flutterTts.setVoice({"name": name, "locale": "en-US"});
          debugPrint("✅ Female voice set: $name");
          return;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint("Voice selection error: $e");
    }
    debugPrint("⚠️ Using system default voice (may be male)");
  }

  Future<void> speak(String text) async {
    final prefs = await SharedPreferences.getInstance();
    final soundEnabled = prefs.getBool('sound_enabled') ?? true;
    if (soundEnabled) {
      await flutterTts.speak(text);
    }
  }

  @override
  void dispose() {
    fingerController.dispose();
    flutterTts.stop();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> loadLevel() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentLevel = prefs.getInt('counting_level') ?? 1;
      currentSubLevel = prefs.getInt('counting_sublevel') ?? 1;
    });
  }

  Future<void> saveLevel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('counting_level', currentLevel);
    await prefs.setInt('counting_sublevel', currentSubLevel);
  }

  bool timeIsUp() {
    if (widget.maxDurationMinutes == null || sessionStartTime == null) return false;
    final elapsed = DateTime.now().difference(sessionStartTime!).inMinutes;
    return elapsed >= widget.maxDurationMinutes!;
  }

  void _endSessionGracefully() {
    saveLevel();
    widget.onSessionComplete();
  }

  void generateNewTrial() {
    if (timeIsUp()) {
      _endSessionGracefully();
      return;
    }

    setState(() {
      hasAnswered = false;
      showPrompt = false;
      showHint = false;
      currentHintIndex = 0;

      int minObjects = 2 + currentSubLevel;
      int maxObjects = 3 + currentSubLevel * 2;
      targetCount = Random().nextInt(maxObjects - minObjects + 1) + minObjects;

      choices = [targetCount];
      while (choices.length < 3) {
        int distr = Random().nextInt(maxObjects - minObjects + 1) + minObjects;
        if (distr != targetCount && !choices.contains(distr)) {
          choices.add(distr);
        }
      }
      choices.shuffle();
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      speak(getInstructionText());
    });
  }

  String getInstructionText() {
    switch (currentLevel) {
      case 1:
        return "Look at the objects. How many?";
      case 2:
        return "Count the different objects. How many in total?";
      case 3:
        return "Match the number to the group.";
      default:
        return "How many?";
    }
  }

  void handleTap(int selected) {
    if (hasAnswered || timeIsUp()) return;

    final isCorrect = selected == targetCount;

    setState(() {
      hasAnswered = true;
      showPrompt = true;
    });

    if (isCorrect) {
      setState(() {
        totalCorrect++;
        starsEarned++;
        rewardCounter++;
        addVisibleStar();
      });
      showBeautifulReinforcement();
      speak("Yes! That's $targetCount!");
      if (rewardCounter % 2 == 0) {
        showSmallReward();
      }
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (!mounted) return;
        advanceTrial();
      });
    } else {
      speak("Let's count again.");
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        setState(() {
          hasAnswered = false;
          showPrompt = false;
        });
      });
    }
  }

  void advanceTrial() {
    currentTrial++;
    if (rewardCounter % 4 == 0) {
      if (currentSubLevel < subLevelsPerLevel[currentLevel - 1]) {
        currentSubLevel++;
      } else {
        if (currentLevel < maxLevel) {
          currentLevel++;
          currentSubLevel = 1;
        } else {
          saveLevel();
          _endSessionGracefully();
          return;
        }
      }
      saveLevel();
    }
    generateNewTrial();
  }

  void showSmallReward() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => Center(
        child: ScaleTransition(
            scale: CurvedAnimation(
                parent: fingerController..forward(from: 0.7),
                curve: Curves.elasticOut),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 30.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32.r),
                boxShadow: [
                  BoxShadow(
                      color: Colors.amber.withOpacity(0.3),
                      blurRadius: 18,
                      spreadRadius: 6)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events, color: Colors.amber, size: 60.w),
                  SizedBox(height: 12.h),
                  Text(
                    "Reward!",
                    style: GoogleFonts.fredoka(
                        fontSize: 32.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.success),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    "You got 2 in a row!",
                    style: GoogleFonts.fredoka(fontSize: 22.sp),
                  ),
                ],
              ),
            )),
      ),
    ).then((_) => fingerController.reset());
  }

  void addVisibleStar() {
    setState(() {
      collectedStars.add(const Icon(Icons.star_rounded, color: Colors.amber, size: 34));
      if (collectedStars.length > 6) collectedStars.removeAt(0);
    });
  }

  void showBeautifulReinforcement() {
    final messages = [
      "Fantastic!",
      "Super!",
      "Awesome!",
      "Great job!",
      "You're a star!",
      "Yes! Well done!"
    ];
    final message = messages[Random().nextInt(messages.length)];

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => Center(
        child: ScaleTransition(
          scale: CurvedAnimation(
              parent: fingerController..forward(from: 0.7),
              curve: Curves.elasticOut),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 50.w, vertical: 40.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40.r),
              boxShadow: [
                BoxShadow(
                    color: Colors.amber.withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 10)
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, color: Colors.amber, size: 90.w),
                SizedBox(height: 16.h),
                Text(
                  message,
                  style: GoogleFonts.fredoka(
                      fontSize: 46.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.success),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) => fingerController.reset());
  }

  // FIXED: Hint now reliably counts EVERY object (no skipping)
  void showFingerHint() async {
    if (showHint) return;

    setState(() {
      showHint = true;
      currentHintIndex = 0;
      showPrompt = true;
    });

    for (int i = 0; i < targetCount; i++) {
      if (!mounted) return;
      setState(() => currentHintIndex = i);
      await Future.delayed(const Duration(milliseconds: 100));
      await speak("${i + 1}");
      await Future.delayed(const Duration(milliseconds: 700));
    }

    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      setState(() => showHint = false);
    }
  }

  Widget buildObjects(int count) {
    if (currentLevel == 1) {
      String img = objectImages[0];
      return Wrap(
        spacing: 24.w,
        runSpacing: 24.h,
        alignment: WrapAlignment.center,
        children: List.generate(count, (index) {
          final isHighlighted = showHint && index == currentHintIndex;
          return AnimatedScale(
            scale: isHighlighted ? 1.28 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Image.asset(
              img,
              width: 56.w,
              height: 56.w,
              color: isHighlighted ? Colors.amberAccent : null,
            ),
          );
        }),
      );
    } else if (currentLevel == 2) {
      return Wrap(
        spacing: 24.w,
        runSpacing: 24.h,
        alignment: WrapAlignment.center,
        children: List.generate(count, (index) {
          final isHighlighted = showHint && index == currentHintIndex;
          String img = objectImages[index % objectImages.length];
          return AnimatedScale(
            scale: isHighlighted ? 1.28 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Image.asset(
              img,
              width: 56.w,
              height: 56.w,
              color: isHighlighted ? Colors.amberAccent : null,
            ),
          );
        }),
      );
    } else {
      String img = objectImages[2];
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Wrap(
            spacing: 18.w,
            runSpacing: 18.h,
            alignment: WrapAlignment.center,
            children: List.generate(targetCount, (index) {
              final isHighlighted = showHint && index == currentHintIndex;
              return AnimatedScale(
                scale: isHighlighted ? 1.28 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Image.asset(
                  img,
                  width: 56.w,
                  height: 56.w,
                  color: isHighlighted ? Colors.amberAccent : null,
                ),
              );
            }),
          ),
        ],
      );
    }
  }

  void showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        title: const Text('Exit Activity?'),
        content: const Text('Your progress will be saved. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onSessionComplete();
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  void restartActivity() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        title: const Text('Restart Activity?'),
        content: const Text('This will reset progress in this session.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                currentTrial = 0;
                totalCorrect = 0;
                starsEarned = 0;
                rewardCounter = 0;
                collectedStars.clear();
              });
              generateNewTrial();
            },
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Top Bar
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: showExitConfirmation,
                      icon: Icon(Icons.arrow_back_rounded,
                          size: 30.w, color: colorScheme.primary),
                    ),
                    const Spacer(),
                    Text(
                      'Counting',
                      style: GoogleFonts.fredoka(
                          fontSize: 26.sp,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.primary),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: showFingerHint,
                      child: Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 32.w,
                          color: Colors.orangeAccent.withOpacity(0.8),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    IconButton(
                      onPressed: restartActivity,
                      icon: Icon(Icons.refresh_rounded,
                          size: 30.w, color: Colors.orange.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
              // Progress bar
              Padding(
                padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 8.h),
                child: LinearProgressIndicator(
                  value: (rewardCounter + 1) /
                      (subLevelsPerLevel.reduce((a, b) => a + b) * 2),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  color: colorScheme.primary,
                  minHeight: 14.h,
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                "Level $currentLevel  |  Sublevel $currentSubLevel",
                style: GoogleFonts.fredoka(fontSize: 22.sp, color: colorScheme.primary),
              ),
              SizedBox(height: 18.h),
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(40.r),
                ),
                margin: EdgeInsets.symmetric(horizontal: 24.w),
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(minHeight: 260.h),
                  padding: EdgeInsets.all(20.w),
                  child: Center(
                    child: buildObjects(targetCount),
                  ),
                ),
              ),
              SizedBox(height: 32.h),
              Text(
                getInstructionText(),
                style: GoogleFonts.fredoka(fontSize: 24.sp, color: colorScheme.primary),
              ),
              SizedBox(height: 40.h),
              // FIXED: Answer buttons now fully responsive (HitTestBehavior + mounted checks)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: choices.map((num) {
                    final isCorrectChoice = num == targetCount && showPrompt;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: hasAnswered ? null : () => handleTap(num),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 118.w,
                        height: 130.h,
                        decoration: BoxDecoration(
                          color: isCorrectChoice
                              ? Colors.green.withOpacity(0.2)
                              : colorScheme.surface,
                          borderRadius: BorderRadius.circular(32.r),
                          border: Border.all(
                            color: isCorrectChoice
                                ? Colors.green
                                : colorScheme.primary.withOpacity(0.3),
                            width: isCorrectChoice ? 7.w : 4.w,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            num.toString(),
                            style: GoogleFonts.fredoka(
                              fontSize: 56.sp,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: 40.h),
              if (showHint)
                Padding(
                  padding: EdgeInsets.all(12.w),
                  child: Text(
                    "Hint: Let's count together!",
                    style: GoogleFonts.fredoka(fontSize: 20.sp, color: Colors.orange),
                  ),
                ),
              SizedBox(height: 30.h),
              if (widget.maxDurationMinutes != null && sessionStartTime != null)
                Text(
                  "Time left: ${widget.maxDurationMinutes! - DateTime.now().difference(sessionStartTime!).inMinutes} min",
                  style: GoogleFonts.fredoka(fontSize: 18.sp),
                ),
            ],
          ),
        ),
      ),
    );
  }
}