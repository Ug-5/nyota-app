// lib/screens/basicmath.dart
// ignore_for_file: no_logic_in_create_state

import 'dart:async';
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
  final int? maxDurationMinutes;

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

class _BasicMathActivityScreenState extends State<BasicMathActivityScreen>
    with TickerProviderStateMixin {   // ← Changed here (this fixes the error)
  // Level and sublevel structure
  int currentLevel = 1;
  int currentSubLevel = 1;
  int maxLevel = 3; // 1: easy, 2: moderate, 3: hard
  final List<int> subLevelsPerLevel = [4, 4, 4];
   int questionsPerLevel = 4; // used for final session reward stars

  int currentTrial = 0;
  int totalCorrect = 0;
  int starsEarned = 0;
  int rewardCounter = 0;

  int a = 2, b = 1, answer = 3;
  bool isAddition = true;
  List<int> choices = [];
  bool showPrompt = false;
  bool hasAnswered = false;
  bool showHint = false;
  bool showHintOverlay = false;
  int hintStep = 0;
  List<Widget> hintObjects = [];

  FlutterTts flutterTts = FlutterTts();
  DateTime? sessionStartTime;

  List<Widget> collectedStars = [];
  late AnimationController fingerController;
  late AnimationController starController;
  late Animation<double> starScale;

  // For tracking recent accuracy to smooth level changes
  final List<bool> recentCorrect = [];
  int consecutiveCorrect = 0;

  // Visual objects (replace with images for real PECS)
  final List<String> objectImages = [
    'assets/images/apple.png',
    'assets/images/banana.png',
    'assets/images/ball.png',
    'assets/images/star.png',
    'assets/images/car.png',
    'assets/images/cube.png',
  ];

  @override
  void initState() {
    super.initState();
    initTTS();
    sessionStartTime = DateTime.now();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    fingerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    starController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    starScale = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: starController, curve: Curves.elasticOut),
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

  Future<void> selectFemaleVoice() async {
    try {
      final voices = await flutterTts.getVoices;
      if (voices != null && voices.isNotEmpty) {
        for (var voice in voices) {
          final name = voice['name']?.toString().toLowerCase() ?? '';
          final gender = voice['gender']?.toString().toLowerCase() ?? '';
          if (gender.contains('female') || name.contains('female')) {
            await flutterTts.setVoice(voice);
            return;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> speak(String text) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('sound_enabled') ?? true) {
      await flutterTts.speak(text);
    }
  }

  @override
  void dispose() {
    fingerController.dispose();
    starController.dispose();
    flutterTts.stop();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> loadLevel() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentLevel = prefs.getInt('basicmath_level') ?? 1;
      currentSubLevel = prefs.getInt('basicmath_sublevel') ?? 1;
    });
  }

  Future<void> saveLevel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('basicmath_level', currentLevel);
    await prefs.setInt('basicmath_sublevel', currentSubLevel);
  }

  bool timeIsUp() {
    if (widget.maxDurationMinutes == null || sessionStartTime == null) return false;
    return DateTime.now().difference(sessionStartTime!).inMinutes >= widget.maxDurationMinutes!;
  }

  void generateNewTrial() {
    if (timeIsUp()) {
      endSessionGracefully();
      return;
    }

    setState(() {
      hasAnswered = false;
      showPrompt = false;
      showHint = false;
      showHintOverlay = false;
      hintStep = 0;

      if (widget.sessionMode == 'addition') {
        isAddition = true;
      } else if (widget.sessionMode == 'subtraction') isAddition = false;
      else isAddition = Random().nextBool();

      // Level config: increase number range and complexity by sublevel
      int minNum = 2 + currentSubLevel;
      int maxNum = 3 + currentSubLevel * 2 + currentLevel * 2;

      if (isAddition) {
        a = Random().nextInt(maxNum - minNum + 1) + minNum;
        b = Random().nextInt(maxNum - a + 1);
        answer = a + b;
      } else {
        a = Random().nextInt(maxNum - minNum + 1) + minNum;
        b = Random().nextInt(a - minNum + 1) + minNum;
        answer = a - b;
      }

      generateChoices();
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      speak(getInstructionText());
    });
  }

  String getInstructionText() {
    if (isAddition) {
      return "How many in total? $a plus $b";
    } else {
      return "How many left? $a minus $b";
    }
  }

  void generateChoices() {
    choices = [answer];
    final Set<int> used = {answer};

    void addIfValid(int candidate) {
      if (candidate > 0 && !used.contains(candidate)) {
        choices.add(candidate);
        used.add(candidate);
      }
    }

    // Common mistakes
    if (isAddition) {
      addIfValid(a + b + 1);  // one more
      addIfValid(a + b - 1);  // one less
      addIfValid(a + b + 2);  // two more
      addIfValid(a + b - 2);  // two less
    } else {
      addIfValid(a - b + 1);
      addIfValid(a - b - 1);
      addIfValid(b);          // mixing minuend and difference
    }

    // Fill up to 4 choices total (3 distractors) with plausible near numbers
    while (choices.length < 4) {
      int offset = Random().nextInt(5) - 2; // -2..2
      int candidate = answer + offset;
      if (candidate > 0 && candidate != answer && !used.contains(candidate)) {
        choices.add(candidate);
        used.add(candidate);
      }
    }

    choices.shuffle();
  }

  void handleTap(int selected, int buttonIndex) {
    if (hasAnswered || showHint || timeIsUp()) return;

    final isCorrect = selected == answer;

    // Update recent accuracy record
    recentCorrect.add(isCorrect);
    if (recentCorrect.length > 5) recentCorrect.removeAt(0);

    setState(() {
      hasAnswered = true;
      showPrompt = true;
    });

    if (isCorrect) {
      setState(() {
        totalCorrect++;
        starsEarned++;
        rewardCounter++;
        consecutiveCorrect++;
        addVisibleStar();
      });
      playSubtleReinforcement(buttonIndex);
      speak("Yes! That's $answer!");
      if (rewardCounter % 2 == 0) {
        showSmallReward();
      }
      checkMilestone();
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) {
          hasAnswered = false;
          showPrompt = false;
          advanceTrial();
        }
      });
    } else {
      consecutiveCorrect = 0;
      speak("Let's try again. $answer is correct.");
      if (!showHint) {
        showFingerHint();
      }
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() {
          hasAnswered = false;
          showPrompt = false;
        });
      });
    }
  }

  void advanceTrial() {
    currentTrial++;
    // Advance sublevel after 4 correct answers
    if (rewardCounter % 4 == 0) {
      if (currentSubLevel < subLevelsPerLevel[currentLevel - 1]) {
        currentSubLevel++;
      } else {
        // Advance level
        if (currentLevel < maxLevel) {
          currentLevel++;
          currentSubLevel = 1;
        } else {
          saveLevel();
          endSessionGracefully();
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

  void playSubtleReinforcement(int tappedIndex) {
    // Animate the star near the correct button
    starController.forward(from: 0.0);
    Future.delayed(const Duration(milliseconds: 500), () {
      starController.reset();
    });
  }

  void checkMilestone() {
    if (consecutiveCorrect > 0 && consecutiveCorrect % 3 == 0) {
      // Show a floating encouragement without interrupting flow
      speak("Great! You're doing wonderful!");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "✨ $consecutiveCorrect correct in a row! ✨",
            style: GoogleFonts.fredoka(fontSize: 20.sp),
          ),
          duration: const Duration(milliseconds: 1200),
          backgroundColor: Colors.teal.shade300,
        ),
      );
    }
  }

  void addVisibleStar() {
    setState(() {
      collectedStars.add(const Icon(Icons.star_rounded, color: Colors.amber, size: 34));
      if (collectedStars.length > 6) collectedStars.removeAt(0);
    });
  }

  void showFingerHint() async {
    if (showHint) return;

    setState(() {
      showHint = true;
      showHintOverlay = true;
      hintStep = 0;
    });

    if (isAddition) {
      await additionHint();
    } else {
      await subtractionHint();
    }

    if (mounted) {
      setState(() {
        showHint = false;
        showHintOverlay = false;
      });
    }
  }

  Future<void> additionHint() async {
    await speak("Let's count $a balls.");
    await showBalls(a, "First group:");
    await Future.delayed(const Duration(milliseconds: 800));

    await speak("Now add $b more balls.");
    await showBalls(b, "Second group:");
    await Future.delayed(const Duration(milliseconds: 800));

    await speak("Now let's count all the balls together.");
    await showBalls(a + b, "Total:");
    await Future.delayed(const Duration(milliseconds: 800));
    await speak("$a plus $b equals $answer.");
  }

  Future<void> subtractionHint() async {
    await speak("We have $a balls.");
    await showBalls(a, "Start:");
    await Future.delayed(const Duration(milliseconds: 800));

    await speak("Now take away $b balls.");
    for (int i = 0; i < b; i++) {
      await speak("${i + 1}");
      await Future.delayed(const Duration(milliseconds: 500));
    }

    await speak("How many are left?");
    await showBalls(a - b, "Remaining:");
    await Future.delayed(const Duration(milliseconds: 800));
    await speak("$a minus $b equals $answer.");
  }

  Future<void> showBalls(int count, String stepText) async {
    setState(() {
      hintObjects = List.generate(count, (index) {
        return Icon(
          Icons.circle,
          size: 40.w,
          color: Colors.brown.shade300,
        );
      });
    });
    await speak(stepText);
    await Future.delayed(const Duration(milliseconds: 1200));
  }

  Widget buildProblem() {
    List<Widget> objectsA = List.generate(a, (i) => Image.asset(objectImages[i % objectImages.length], width: 36.w, height: 36.w));
    List<Widget> objectsB = List.generate(b, (i) => Image.asset(objectImages[(i + 2) % objectImages.length], width: 36.w, height: 36.w));
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Wrap(spacing: 4.w, children: objectsA),
            SizedBox(width: 12.w),
            Text(isAddition ? '+' : '-', style: GoogleFonts.fredoka(fontSize: 38.sp, fontWeight: FontWeight.bold)),
            SizedBox(width: 12.w),
            Wrap(spacing: 4.w, children: objectsB),
          ],
        ),
        SizedBox(height: 18.h),
        Text(
          isAddition ? '$a + $b' : '$a - $b',
          style: GoogleFonts.fredoka(fontSize: 44.sp, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary),
        ),
        if (showHintOverlay)
          Container(
            margin: EdgeInsets.only(top: 20.h),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Wrap(
              spacing: 12.w,
              runSpacing: 12.h,
              alignment: WrapAlignment.center,
              children: hintObjects,
            ),
          ),
      ],
    );
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
                collectedStars.clear();
                recentCorrect.clear();
                consecutiveCorrect = 0;
              });
              loadLevel().then((_) => generateNewTrial());
              speak("Starting over. Let's practice math together.");
            },
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  void endSessionGracefully() {
    speak("Great work today! You did amazing!");
    showSessionReward();
  }

  void showSessionReward() {
    int starCount = (starsEarned / (questionsPerLevel * maxLevel) * 3).round().clamp(0, 3);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40.r)),
        child: Container(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) => Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  child: Icon(
                    i < starCount ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 90.w,
                    color: i < starCount ? Colors.amber : Colors.grey.withOpacity(0.5),
                  ),
                )),
              ),
              SizedBox(height: 24.h),
              Text(
                starCount == 3 ? "AMAZING! You're a math superstar! 🌟🌟🌟" :
                starCount == 2 ? "Excellent work! 🌟🌟" :
                starCount == 1 ? "Great job! 🌟" : "You did well! Keep practicing 💪",
                style: GoogleFonts.fredoka(fontSize: 32.sp, fontWeight: FontWeight.bold, color: AppTheme.success),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              Text(
                "You got $totalCorrect correct answers!",
                style: GoogleFonts.fredoka(fontSize: 22.sp),
              ),
              SizedBox(height: 32.h),
              if (widget.rewardImagePath != null && starCount >= 2)
                Column(
                  children: [
                    Text(
                      "🏆 You earned your special reward! 🏆",
                      style: GoogleFonts.fredoka(fontSize: 26.sp, fontWeight: FontWeight.bold, color: Colors.amber),
                    ),
                    SizedBox(height: 16.h),
                    Container(
                      width: 160.w,
                      height: 160.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: Colors.amber, width: 5.w),
                        image: DecorationImage(
                          image: AssetImage(widget.rewardImagePath!),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              SizedBox(height: 40.h),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onSessionComplete();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  padding: EdgeInsets.symmetric(horizontal: 60.w, vertical: 18.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
                ),
                child: Text("Continue", style: GoogleFonts.fredoka(fontSize: 26.sp, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
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
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)],
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: showExitConfirmation,
                      icon: Icon(Icons.arrow_back_rounded, size: 30.w, color: colorScheme.primary),
                    ),
                    const Spacer(),
                    Text(
                      'Basic Math',
                      style: GoogleFonts.fredoka(fontSize: 26.sp, fontWeight: FontWeight.w500, color: colorScheme.primary),
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
                      icon: Icon(Icons.refresh_rounded, size: 30.w, color: Colors.orange.withOpacity(0.8)),
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
              // Level and sublevel display
              Text(
                "Level $currentLevel  |  Sublevel $currentSubLevel",
                style: GoogleFonts.fredoka(fontSize: 22.sp, color: colorScheme.primary),
              ),
              SizedBox(height: 18.h),
              // Problem card
              Container(
                width: 340.w,
                padding: EdgeInsets.all(32.w),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(40.r),
                  border: Border.all(color: colorScheme.primary.withOpacity(0.2), width: 5.w),
                ),
                child: Center(child: buildProblem()),
              ),
              SizedBox(height: 40.h),
              Text(
                getInstructionText(),
                style: GoogleFonts.fredoka(fontSize: 28.sp, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32.h),
              
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: choices.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final num = entry.value;
                    final isCorrectChoice = num == answer && showPrompt;
                    const isPressed = false;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: (hasAnswered || showHint) ? null : () => handleTap(num, idx),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        transform: Matrix4.identity()..scale(isPressed ? 0.96 : 1.0),
                        width: 118.w,
                        height: 130.h,
                        decoration: BoxDecoration(
                          color: isCorrectChoice ? Colors.green.withOpacity(0.2) : colorScheme.surface,
                          borderRadius: BorderRadius.circular(32.r),
                          border: Border.all(
                            color: isCorrectChoice ? Colors.green : colorScheme.primary.withOpacity(0.3),
                            width: isCorrectChoice ? 7.w : 4.w,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Center(
                              child: Text(
                                num.toString(),
                                style: GoogleFonts.fredoka(
                                  fontSize: 56.sp,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                            if (isCorrectChoice && starController.isAnimating)
                              AnimatedBuilder(
                                animation: starController,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: starScale.value,
                                    child: Opacity(
                                      opacity: 1.0 - starController.value,
                                      child: Icon(
                                        Icons.star_rounded,
                                        size: 50.w,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: 40.h),
              if (showHint && !showHintOverlay)
                Text(
                  isAddition ? "Hint: Let's count together!" : "Hint: Let's take away together!",
                  style: GoogleFonts.fredoka(fontSize: 20.sp, color: Colors.orange),
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