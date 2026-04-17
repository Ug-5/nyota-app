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
    with TickerProviderStateMixin {

  int currentLevel = 1;
  int currentSubLevel = 1;
  int maxLevel = 3;
  final List<int> subLevelsPerLevel = [4, 4, 4];

  int currentTrial = 0;
  int totalCorrect = 0;
  int starsEarned = 0;
  int rewardCounter = 0;

  int a = 0, b = 0, answer = 0;
  bool isAddition = true;
  List<int> choices = [];
  bool showPrompt = false;
  bool hasAnswered = false;
  bool showHint = false;
  int currentHintIndex = 0;
  bool isCountingHint = false;

  DateTime? sessionStartTime;

  final List<String> objectImages = [
    'assets/images/apple.png',
    'assets/images/banana.png',
    'assets/images/ball.png',
    'assets/images/star.png',
    'assets/images/car.png',
    'assets/images/cube.png',
  ];

  String currentObject = 'assets/images/apple.png';

  List<Widget> collectedStars = [];

  late AnimationController fingerController;
  FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    sessionStartTime = DateTime.now();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    fingerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

    initTTS();
    loadLevel().then((_) => generateNewTrial());
  }

  Future<void> initTTS() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.48);
    await flutterTts.setPitch(1.08);
    await flutterTts.setVolume(0.92);
  }

  Future<void> speak(String text) async {
    await flutterTts.speak(text);
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
      isCountingHint = false;
      currentHintIndex = 0;
    });

    // Decide operation
    if (widget.sessionMode == 'addition') isAddition = true;
    else if (widget.sessionMode == 'subtraction') isAddition = false;
    else isAddition = currentLevel == 1 ? true : currentLevel == 2 ? false : Random().nextBool();

    currentObject = objectImages[Random().nextInt(objectImages.length)];

    int minNum = 1 + currentSubLevel;
    int maxNum = 3 + currentSubLevel * 2 + (currentLevel - 1) * 2;

    if (isAddition) {
      a = Random().nextInt(maxNum - minNum + 1) + minNum;
      b = Random().nextInt(maxNum - a + 2) + 1;
      answer = a + b;
    } else {
      a = Random().nextInt(maxNum - minNum + 1) + minNum + 3;
      b = Random().nextInt(a - 1) + 1;
      answer = a - b;
    }

    generateChoices();
  }

  void generateChoices() {
    choices = [answer];
    final Set<int> used = {answer};

    while (choices.length < 4) {
      int offset = Random().nextInt(5) - 2;
      int candidate = answer + offset;
      if (candidate > 0 && !used.contains(candidate)) {
        choices.add(candidate);
        used.add(candidate);
      }
    }
    choices.shuffle();
  }

  String getInstructionText() {
    return isAddition ? "$a + $b = ?" : "$a - $b = ?";
  }

  void handleTap(int selected) {
    if (hasAnswered || timeIsUp()) return;

    final isCorrect = selected == answer;

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

      showSimpleEmojiFeedback();

      if (rewardCounter % 3 == 0) {
        speak("Well done!");
      }

      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) advanceTrial();
      });
    } else {
      speak("Let's try again.");
      
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() {
            hasAnswered = false;
            showPrompt = false;
          });
        }
      });
    }
  }

  void showSimpleEmojiFeedback() {
    final emojis = ["🎉", "🥳", "⭐", "🔥", "👏", "🌟"];
    final emoji = emojis[Random().nextInt(emojis.length)];

    final overlay = OverlayEntry(
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Text(emoji, style: TextStyle(fontSize: 85.sp)),
        ),
      ),
    );

    Overlay.of(context).insert(overlay);
    Future.delayed(const Duration(milliseconds: 750), () => overlay.remove());
  }

  void advanceTrial() {
    currentTrial++;

    if (rewardCounter % 4 == 0) {
      if (currentSubLevel < subLevelsPerLevel[currentLevel - 1]) {
        currentSubLevel++;
      } else if (currentLevel < maxLevel) {
        currentLevel++;
        currentSubLevel = 1;
      } else {
        showFinalReward();
        return;
      }
      saveLevel();
    }
    generateNewTrial();
  }

  void addVisibleStar() {
    setState(() {
      collectedStars.add(const Icon(Icons.star_rounded, color: Colors.amber, size: 34));
      if (collectedStars.length > 6) collectedStars.removeAt(0);
    });
  }

  void showFingerHint() async {
    if (showHint || isCountingHint) return;

    setState(() {
      showHint = true;
      isCountingHint = true;
      currentHintIndex = 0;
    });

    speak(isAddition ? "Let's count together." : "Let's take away together.");

    int totalToCount = isAddition ? a + b : a;

    for (int i = 0; i < totalToCount; i++) {
      if (!mounted) return;
      setState(() => currentHintIndex = i);
      await Future.delayed(const Duration(milliseconds: 900));
    }

    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() {
        showHint = false;
        isCountingHint = false;
      });
    }
  }

  void showFinalReward() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40.r)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 40),
            Text("🎉 Congratulations! 🎉", style: GoogleFonts.fredoka(fontSize: 36.sp, fontWeight: FontWeight.bold, color: AppTheme.success)),
            const SizedBox(height: 20),
            if (widget.rewardImagePath != null && widget.rewardImagePath!.isNotEmpty)
              Image.asset(widget.rewardImagePath!, height: 220.h, fit: BoxFit.contain)
            else
              const Icon(Icons.emoji_events, size: 180, color: Colors.amber),
            const SizedBox(height: 30),
            Text("You finished all levels!", style: GoogleFonts.fredoka(fontSize: 24.sp)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onSessionComplete();
              },
              child: const Text("Finish Session"),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget buildProblem() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // First Group
        Wrap(
          spacing: 18.w,
          runSpacing: 18.h,
          alignment: WrapAlignment.center,
          children: List.generate(a, (index) {
            final isHighlighted = showHint && index == currentHintIndex && isAddition;
            return Stack(
              alignment: Alignment.center,
              children: [
                AnimatedScale(
                  scale: isHighlighted ? 1.35 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Image.asset(currentObject, width: 52.w, height: 52.w, color: isHighlighted ? Colors.amberAccent : null),
                ),
                if (isHighlighted && isCountingHint)
                  Container(
                    width: 52.w,
                    height: 52.w,
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), shape: BoxShape.circle),
                    child: Center(child: Text("${index + 1}", style: GoogleFonts.fredoka(fontSize: 26.sp, fontWeight: FontWeight.bold, color: Colors.white))),
                  ),
              ],
            );
          }),
        ),

        SizedBox(height: 12.h),

        // + or - Symbol
        Text(
          isAddition ? "+" : "−",
          style: GoogleFonts.fredoka(fontSize: 52.sp, fontWeight: FontWeight.bold, color: Colors.orange),
        ),

        SizedBox(height: 12.h),

        // Second Group
        Wrap(
          spacing: 18.w,
          runSpacing: 18.h,
          alignment: WrapAlignment.center,
          children: List.generate(b, (index) {
            final isHighlighted = showHint && (isAddition 
                ? index + a == currentHintIndex 
                : index < b && currentHintIndex >= a); // For subtraction highlight removal area
            return Stack(
              alignment: Alignment.center,
              children: [
                AnimatedScale(
                  scale: isHighlighted ? 1.35 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Image.asset(currentObject, width: 52.w, height: 52.w, color: isHighlighted ? Colors.amberAccent : null),
                ),
                if (isHighlighted && isCountingHint && !isAddition)
                  Container(
                    width: 52.w,
                    height: 52.w,
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.7), shape: BoxShape.circle),
                    child: const Center(child: Icon(Icons.remove, color: Colors.white, size: 28)),
                  ),
              ],
            );
          }),
        ),

        SizedBox(height: 30.h),

        // Equation
        Text(
          isAddition ? "$a + $b" : "$a - $b",
          style: GoogleFonts.fredoka(fontSize: 48.sp, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
        ),
      ],
    );
  }

  Widget buildAnswerChoices() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: choices.map((num) {
          final isCorrectChoice = num == answer && showPrompt;
          final isWrongChoice = hasAnswered && num != answer && showPrompt;

          return InkWell(
            onTap: hasAnswered ? null : () => handleTap(num),
            borderRadius: BorderRadius.circular(32.r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 118.w,
              height: 130.h,
              decoration: BoxDecoration(
                color: isCorrectChoice 
                    ? Colors.green.withOpacity(0.25) 
                    : isWrongChoice 
                        ? Colors.red.withOpacity(0.25) 
                        : null,
                borderRadius: BorderRadius.circular(32.r),
                border: Border.all(
                  color: isCorrectChoice 
                      ? Colors.green 
                      : isWrongChoice 
                          ? Colors.red 
                          : Colors.orange,
                  width: isCorrectChoice || isWrongChoice ? 8 : 4,
                ),
              ),
              child: Center(
                child: Text(
                  num.toString(),
                  style: GoogleFonts.fredoka(fontSize: 58.sp, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        widget.onSessionComplete(); // Direct exit to dashboard - no dialog
      },
      child: Scaffold(
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
                        onPressed: () => widget.onSessionComplete(),
                        icon: Icon(Icons.arrow_back_rounded, size: 30.w, color: colorScheme.primary),
                      ),
                      const Spacer(),
                      Text('Basic Math', style: GoogleFonts.fredoka(fontSize: 26.sp, fontWeight: FontWeight.w500, color: colorScheme.primary)),
                      const Spacer(),
                      IconButton(onPressed: showFingerHint, icon: Icon(Icons.lightbulb_outline_rounded, size: 32.w, color: Colors.orangeAccent)),
                      IconButton(onPressed: () {
                        setState(() {
                          currentTrial = 0;
                          totalCorrect = 0;
                          starsEarned = 0;
                          rewardCounter = 0;
                          collectedStars.clear();
                        });
                        generateNewTrial();
                      }, icon: Icon(Icons.refresh_rounded, size: 30.w, color: Colors.orange)),
                    ],
                  ),
                ),

                Padding(
                  padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 8.h),
                  child: LinearProgressIndicator(
                    value: (rewardCounter + 1) / (subLevelsPerLevel.reduce((a, b) => a + b) * 2),
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    color: colorScheme.primary,
                    minHeight: 14.h,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),

                Text("Level $currentLevel  |  Sublevel $currentSubLevel", style: GoogleFonts.fredoka(fontSize: 22.sp, color: colorScheme.primary)),
                SizedBox(height: 16.h),

                // Problem Area - Two clear groups
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40.r)),
                  margin: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Container(
                    constraints: BoxConstraints(minHeight: 300.h),
                    padding: EdgeInsets.all(32.w),
                    child: Center(child: buildProblem()),
                  ),
                ),

                SizedBox(height: 32.h),
                Text(getInstructionText(), style: GoogleFonts.fredoka(fontSize: 28.sp, fontWeight: FontWeight.w600, color: colorScheme.primary)),
                SizedBox(height: 40.h),

                buildAnswerChoices(),

                SizedBox(height: 30.h),
                if (showHint)
                  Text("Hint: Let's count together!", style: GoogleFonts.fredoka(fontSize: 20.sp, color: Colors.orange)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}