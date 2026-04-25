// lib/screens/basicmath.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:nyota/theme.dart';

class BasicMathActivityScreen extends StatefulWidget {
  final VoidCallback onSessionComplete;
  final String? rewardImagePath;
  final String sessionMode; // 'addition', 'subtraction', or 'mixed'
  final int sessionDuration; // in minutes, required

  const BasicMathActivityScreen({
    super.key,
    required this.onSessionComplete,
    this.rewardImagePath,
    this.sessionMode = 'mixed',
    required this.sessionDuration,
  });

  @override
  State<BasicMathActivityScreen> createState() =>
      _BasicMathActivityScreenState();
}

class _BasicMathActivityScreenState extends State<BasicMathActivityScreen>
    with TickerProviderStateMixin {
  // ── Configuration ──────────────────────────────────────────────────────────
  static const int trialsPerSubLevel = 4;
  static const int maxLevel = 3;
  final List<int> subLevelsPerLevel = [3, 3, 3];

  // ── Game State ─────────────────────────────────────────────────────────────
  int currentLevel = 1;
  int additionSubLevel = 1;
  int subtractionSubLevel = 1;
  int correctInAddition = 0;
  int correctInSubtraction = 0;

  // For 'mixed' mode: complete ALL subtraction sublevels before starting addition.
  // Subtraction is taught first because it extends counting backwards.
  bool _subtractionPhaseComplete = false;

  int currentTrial = 0;
  int totalCorrect = 0;
  int starsEarned = 0;
  int lifetimeStars = 0;

  // Tracks streak for the 🎉 celebration every 3 consecutive correct answers
  int _consecutiveCorrect = 0;

  int firstOperand = 2, secondOperand = 3, answer = 5;
  bool isAddition = true;
  List<int> choices = [];

  bool showPrompt = false;
  bool hasAnswered = false;
  bool showHint = false;
  bool isShowMeActive = false;
  int? selectedAnswer;

  // Adaptive tracking
  final List<bool> _recentAddition = [];
  final List<bool> _recentSubtraction = [];

  // ── Timers ─────────────────────────────────────────────────────────────────
  Timer? _advanceTimer;
  Timer? _hintTimer;
  Timer? _speakTimer;
  Timer? _showMeTimer;
  Timer? _sessionTimer;
  int _remainingSeconds = 0;

  // New session flags
  bool _sessionTimerExpired = false;
  bool _allLevelsComplete = false;

  // ── TTS ────────────────────────────────────────────────────────────────────
  late FlutterTts flutterTts;
  bool _ttsInitialized = false;
  bool _soundEnabled = true;

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _shakeController;

  DateTime? sessionStartTime;
  List<Widget> collectedStars = [];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    sessionStartTime = DateTime.now();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _initTts();

    // Session timer based on parent schedule
    _remainingSeconds = widget.sessionDuration * 60;
    _startSessionTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPersistentData().then((_) {
        if (mounted) _generateNewTrial();
      });
    });
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          t.cancel();
          _sessionTimerExpired = true;
          _endSession(naturalCompletion: true);
        }
      });
    });
  }

  Future<void> _initTts() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.42);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.1);
    try {
      await flutterTts
          .setVoice({"name": "en-US-x-tpf-local", "locale": "en-US"});
    } catch (_) {}
    if (mounted) setState(() => _ttsInitialized = true);
    _loadSoundPreference();
  }

  Future<void> _loadSoundPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _soundEnabled = prefs.getBool('sound_enabled') ?? true);
    }
  }

  Future<void> _speak(String text) async {
    if (!mounted || !_ttsInitialized || !_soundEnabled) return;
    await flutterTts.stop();
    await flutterTts.speak(text);
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _hintTimer?.cancel();
    _speakTimer?.cancel();
    _showMeTimer?.cancel();
    _sessionTimer?.cancel();
    _shakeController.dispose();
    flutterTts.stop();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> _loadPersistentData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      currentLevel = prefs.getInt('basicmath_level') ?? 1;
      additionSubLevel = prefs.getInt('basicmath_add_sub') ?? 1;
      subtractionSubLevel = prefs.getInt('basicmath_sub_sub') ?? 1;
      lifetimeStars = prefs.getInt('lifetime_stars') ?? 0;
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('basicmath_level', currentLevel);
    await prefs.setInt('basicmath_add_sub', additionSubLevel);
    await prefs.setInt('basicmath_sub_sub', subtractionSubLevel);
  }

  Future<void> _saveLifetimeStars() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lifetime_stars', lifetimeStars);
  }

  bool _timeIsUp() =>
      widget.sessionDuration != null && _remainingSeconds <= 0;

  // ── Phase logic ─────────────────────────────────────────────────────────────

  bool get _inSubtractionPhase {
    if (widget.sessionMode == 'subtraction') return true;
    if (widget.sessionMode == 'addition') return false;
    return !_subtractionPhaseComplete; // mixed: subtraction first
  }

  // ── Number range helpers ────────────────────────────────────────────────────

  int get _effectiveSubLevel =>
      _inSubtractionPhase ? subtractionSubLevel : additionSubLevel;

  int get maxNumber {
    final base = (currentLevel == 1) ? 3 : (currentLevel == 2) ? 6 : 10;
    return (base + _effectiveSubLevel * 2).clamp(3, 20);
  }

  int get minNumber => currentLevel == 1 ? 1 : 2;

  void _cancelAllTimers() {
    _advanceTimer?.cancel();
    _hintTimer?.cancel();
    _speakTimer?.cancel();
    _showMeTimer?.cancel();
  }

  // ── Trial generation ────────────────────────────────────────────────────────

  void _generateNewTrial() {
    _cancelAllTimers();
    if (_timeIsUp() || _allLevelsComplete) {
      if (_timeIsUp()) _endSession(naturalCompletion: true);
      return;
    }

    final bool subMode = _inSubtractionPhase;

    setState(() {
      hasAnswered = false;
      showPrompt = false;
      showHint = false;
      isShowMeActive = false;
      selectedAnswer = null;
      isAddition = !subMode;

      final maxNum = maxNumber;
      final minNum = minNumber;
      if (isAddition) {
        firstOperand = minNum + Random().nextInt(maxNum - minNum + 1);
        secondOperand = minNum + Random().nextInt(maxNum - minNum + 1);
        answer = firstOperand + secondOperand;
      } else {
        secondOperand = minNum + Random().nextInt(maxNum ~/ 2 - minNum + 1);
        int maxFirst = (maxNum).clamp(secondOperand + 1, 30);
        firstOperand = secondOperand +
            Random().nextInt(maxFirst - secondOperand + 1);
        answer = firstOperand - secondOperand;
      }

      _generateChoices();
    });

    _speakTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        _speak(isAddition
            ? "What is $firstOperand plus $secondOperand?"
            : "What is $firstOperand take away $secondOperand?");
      }
    });

    // Auto-hint after 20 seconds of no response
    _hintTimer = Timer(const Duration(seconds: 20), () {
      if (mounted && !hasAnswered && !showHint && !isShowMeActive) {
        _triggerHint(autoHint: true);
      }
    });
  }

  void _generateChoices() {
    choices = [answer];
    final used = <int>{answer};

    void tryAdd(int c) {
      if (c > 0 && !used.contains(c)) {
        choices.add(c);
        used.add(c);
      }
    }

    // Pedagogically meaningful distractors
    if (isAddition) {
      tryAdd(answer + 1);
      tryAdd(answer > 1 ? answer - 1 : answer + 2);
      tryAdd(firstOperand);          // forgot to add
      tryAdd(secondOperand);
    } else {
      tryAdd(answer + 1);
      tryAdd(answer > 1 ? answer - 1 : answer + 3);
      tryAdd(firstOperand);          // forgot to subtract
      tryAdd(firstOperand + secondOperand); // added instead
    }

    // Sequential fallback to guarantee exactly 4 choices
    int fallback = answer + choices.length + 1;
    int guard = 0;
    while (choices.length < 4 && guard < 20) {
      tryAdd(fallback++);
      guard++;
    }

    choices.shuffle();
  }

  // ── Concept explanation (spoken by hint/Show Me, no on‑screen text) ──────────

  String _conceptExplanation() {
    if (isAddition) {
      return "$firstOperand plus $secondOperand means putting together "
          "$firstOperand things and $secondOperand things. "
          "Count them all together. The answer is $answer.";
    } else {
      return "$firstOperand take away $secondOperand means starting with "
          "$firstOperand things and removing $secondOperand. "
          "Count what is left. The answer is $answer.";
    }
  }

  // ── Interaction ─────────────────────────────────────────────────────────────

  void _handleTap(int selected) {
    if (!mounted || hasAnswered || isShowMeActive || _allLevelsComplete) return;

    final isCorrect = selected == answer;

    if (isAddition) {
      _recentAddition.add(isCorrect);
      if (_recentAddition.length > 5) _recentAddition.removeAt(0);
    } else {
      _recentSubtraction.add(isCorrect);
      if (_recentSubtraction.length > 5) _recentSubtraction.removeAt(0);
    }

    setState(() {
      hasAnswered = true;
      showPrompt = true;
      selectedAnswer = selected;
    });

    if (isCorrect) {
      HapticFeedback.lightImpact();
      _hintTimer?.cancel();
      _consecutiveCorrect++;

      setState(() {
        totalCorrect++;
        starsEarned++;
        lifetimeStars++;
        if (isAddition) correctInAddition++;
        else correctInSubtraction++;
        _addVisibleStar();
      });
      _saveLifetimeStars();
      _speak("Great job! ${_verboseEquation()} Well done!");

      if (_consecutiveCorrect % 3 == 0) _showWellDoneAnimation();

      _advanceTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) {
          currentTrial++;
          _advanceAfterCorrect();
        }
      });
    } else {
      HapticFeedback.mediumImpact();
      _consecutiveCorrect = 0;
      _shakeController.forward(from: 0.0);

      _speak("Not quite.");
      currentTrial++;

      _hintTimer?.cancel();
      _hintTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() => showHint = true);
          _speak(_conceptExplanation());
        }
      });
    }
  }

  String _verboseEquation() {
    return isAddition
        ? "$firstOperand plus $secondOperand equals $answer."
        : "$firstOperand take away $secondOperand equals $answer.";
  }

  // ── Progression ─────────────────────────────────────────────────────────────

  void _advanceAfterCorrect() {
    bool subLevelAdvanced = false;

    if (!isAddition) {
      // ── Subtraction phase ────────────────────────────────────────────────
      if (correctInSubtraction >= trialsPerSubLevel) {
        if (subtractionSubLevel < subLevelsPerLevel[currentLevel - 1]) {
          setState(() { subtractionSubLevel++; correctInSubtraction = 0; });
          _recentSubtraction.clear();
          subLevelAdvanced = true;
          _saveProgress();
          _speak("Excellent subtraction! Let's try harder numbers.");
          _showSubLevelReward();
        } else {
          // All subtraction sublevels done for this level
          if (widget.sessionMode == 'mixed') {
            setState(() { _subtractionPhaseComplete = true; correctInSubtraction = 0; });
            _saveProgress();
            _showPhaseTransitionDialog();
            return;
          } else {
            if (currentLevel < maxLevel) { _doLevelUp(); }
            else { _onAllLevelsComplete(); }
            return;
          }
        }
      }
    } else {
      // ── Addition phase ───────────────────────────────────────────────────
      if (correctInAddition >= trialsPerSubLevel) {
        if (additionSubLevel < subLevelsPerLevel[currentLevel - 1]) {
          setState(() { additionSubLevel++; correctInAddition = 0; });
          _recentAddition.clear();
          subLevelAdvanced = true;
          _saveProgress();
          _speak("Excellent addition! Let's try harder numbers.");
          _showSubLevelReward();
        } else {
          if (currentLevel < maxLevel) { _doLevelUp(); }
          else { _onAllLevelsComplete(); }
          return;
        }
      }
    }

    if (!subLevelAdvanced) _maybeAdjustSubLevels();

    if (currentTrial >= _totalExpectedTrials || _timeIsUp()) {
      _endSession(naturalCompletion: true);
    } else {
      _generateNewTrial();
    }
  }

  void _doLevelUp() {
    setState(() {
      currentLevel++;
      additionSubLevel = 1;
      subtractionSubLevel = 1;
      correctInAddition = 0;
      correctInSubtraction = 0;
      _subtractionPhaseComplete = false; // new level, start with subtraction again
    });
    _saveProgress();
    _speak("Amazing! You reached Level $currentLevel! You are doing so well!");
    _showLevelUpDialog();
  }

  int get _totalExpectedTrials {
    final base = subLevelsPerLevel.reduce((a, b) => a + b) * trialsPerSubLevel;
    return widget.sessionMode == 'mixed' ? base * 2 : base;
  }

  double get overallProgress {
    if (widget.sessionMode == 'mixed') {
      final totalSub = subLevelsPerLevel.reduce((a, b) => a + b) * 2;
      int completed = 0;
      for (int i = 0; i < currentLevel - 1; i++) {
        completed += subLevelsPerLevel[i] * 2;
      }
      final subMax = subLevelsPerLevel[currentLevel - 1];
      final subDone =
          _subtractionPhaseComplete ? subMax : (subtractionSubLevel - 1);
      final addDone = _subtractionPhaseComplete ? (additionSubLevel - 1) : 0;
      completed += subDone + addDone;
      final correctNow = isAddition ? correctInAddition : correctInSubtraction;
      return ((completed + correctNow / trialsPerSubLevel) / totalSub)
          .clamp(0.0, 1.0);
    } else {
      final totalSub = subLevelsPerLevel.reduce((a, b) => a + b);
      int completed = 0;
      for (int i = 0; i < currentLevel - 1; i++) {
        completed += subLevelsPerLevel[i];
      }
      final currentSub =
          isAddition ? additionSubLevel : subtractionSubLevel;
      completed += currentSub - 1;
      final correctNow = isAddition ? correctInAddition : correctInSubtraction;
      return ((completed + correctNow / trialsPerSubLevel) / totalSub)
          .clamp(0.0, 1.0);
    }
  }

  void _maybeAdjustSubLevels() {
    if (!isAddition && _recentSubtraction.length >= 5) {
      final acc =
          _recentSubtraction.where((c) => c).length / _recentSubtraction.length;
      if (acc >= 0.8 &&
          subtractionSubLevel < subLevelsPerLevel[currentLevel - 1]) {
        setState(() { subtractionSubLevel++; correctInSubtraction = 0; });
        _recentSubtraction.clear();
        _saveProgress();
        _speak("Great at taking away! Let's try harder problems.");
      } else if (acc <= 0.4 && subtractionSubLevel > 1) {
        setState(() { subtractionSubLevel--; correctInSubtraction = 0; });
        _recentSubtraction.clear();
        _saveProgress();
        _speak("Let's practice subtraction a bit more.");
      }
    }

    if (isAddition && _recentAddition.length >= 5) {
      final acc =
          _recentAddition.where((c) => c).length / _recentAddition.length;
      if (acc >= 0.8 &&
          additionSubLevel < subLevelsPerLevel[currentLevel - 1]) {
        setState(() { additionSubLevel++; correctInAddition = 0; });
        _recentAddition.clear();
        _saveProgress();
        _speak("Great at adding! Let's try harder problems.");
      } else if (acc <= 0.4 && additionSubLevel > 1) {
        setState(() { additionSubLevel--; correctInAddition = 0; });
        _recentAddition.clear();
        _saveProgress();
        _speak("Let's practice addition a bit more.");
      }
    }
  }

  void _addVisibleStar() {
    collectedStars.add(
        const Icon(Icons.star_rounded, color: Colors.amber, size: 32));
    if (collectedStars.length > 7) collectedStars.removeAt(0);
  }

  // ── Hint / Show Me ──────────────────────────────────────────────────────────

  void _triggerHint({bool autoHint = false}) {
    if (showHint || !mounted) return;
    setState(() { showHint = true; isShowMeActive = false; });
    _speak(_conceptExplanation());
  }

  void _activateShowMe() {
    if (isShowMeActive || hasAnswered || !mounted) return;
    setState(() { isShowMeActive = true; showHint = false; });

    final speech = isAddition
        ? "Watch this! $firstOperand plus $secondOperand means putting together "
          "$firstOperand things and $secondOperand things. "
          "The answer is $answer! Now you try!"
        : "Watch this! $firstOperand take away $secondOperand means starting "
          "with $firstOperand things and removing $secondOperand. "
          "The answer is $answer! Now you try!";

    _speak(speech);

    _showMeTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => isShowMeActive = false);
    });
  }

  // ── Visual math aid ─────────────────────────────────────────────────────────
  Widget _buildVisualAid() {
    final int maxDotsPerGroup = 8;
    final int showFirst = firstOperand.clamp(0, maxDotsPerGroup);
    final int showSecond = secondOperand.clamp(0, maxDotsPerGroup);

    if (isAddition) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dotGroup(showFirst, Colors.blue),
              SizedBox(width: 12.w),
              Text('+', style: TextStyle(fontSize: 36.sp, fontWeight: FontWeight.bold)),
              SizedBox(width: 12.w),
              _dotGroup(showSecond, Colors.orange),
              SizedBox(width: 12.w),
              Text('=', style: TextStyle(fontSize: 36.sp, fontWeight: FontWeight.bold)),
              SizedBox(width: 12.w),
              _dotGroup(showFirst + showSecond, Colors.green),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            '$firstOperand + $secondOperand = $answer',
            style: GoogleFonts.fredoka(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700),
          ),
        ],
      );
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dotGroup(showFirst, Colors.red.shade300, withCrossout: false),
          SizedBox(height: 4.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('−', style: TextStyle(fontSize: 36.sp, fontWeight: FontWeight.bold)),
              SizedBox(width: 6.w),
              _dotGroup(showSecond, Colors.red.shade300, withCrossout: true),
              SizedBox(width: 12.w),
              Text('=', style: TextStyle(fontSize: 36.sp, fontWeight: FontWeight.bold)),
              SizedBox(width: 12.w),
              _dotGroup(answer, Colors.green),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            '$firstOperand − $secondOperand = $answer',
            style: GoogleFonts.fredoka(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700),
          ),
        ],
      );
    }
  }

  Widget _dotGroup(int count, Color baseColor, {bool withCrossout = false}) {
    return Wrap(
      spacing: 2.w,
      runSpacing: 2.h,
      children: List.generate(count, (i) => Container(
        width: 18.w,
        height: 18.w,
        margin: EdgeInsets.all(1.w),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: baseColor.withOpacity(0.7),
        ),
        child: withCrossout
            ? Center(
                child: Icon(Icons.close, size: 12.w, color: Colors.white))
            : null,
      )),
    );
  }

  // ── Exit dialog ─────────────────────────────────────────────────────────────

  Future<void> _confirmExit() async {
    flutterTts.stop();
    final leave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(36.r)),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 36.w, vertical: 32.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('😊', style: TextStyle(fontSize: 64.sp)),
              SizedBox(height: 10.h),
              Text('Time to go?',
                  style: GoogleFonts.fredoka(
                      fontSize: 26.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 28.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _exitBtn(ctx, false, '🎮', 'Keep playing', AppTheme.success),
                  _exitBtn(ctx, true, '🏠', 'Go home', Colors.orange),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (leave == true && mounted) {
      _cancelAllTimers();
      _sessionTimer?.cancel();
      Navigator.of(context).pop();
    }
  }

  Widget _exitBtn(
      BuildContext ctx, bool value, String emoji, String label, Color color) {
    return GestureDetector(
      onTap: () => Navigator.of(ctx).pop(value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 26.w, vertical: 18.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: color, width: 3.w),
        ),
        child: Column(
          children: [
            Text(emoji, style: TextStyle(fontSize: 40.sp)),
            SizedBox(height: 6.h),
            Text(label,
                style: GoogleFonts.fredoka(
                    fontSize: 15.sp,
                    color: color,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _restartActivity() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.r)),
        title: Text('Start Over?',
            style: GoogleFonts.fredoka(
                fontWeight: FontWeight.bold, fontSize: 22.sp)),
        content: Text('This will start a new session.',
            style: GoogleFonts.fredoka(fontSize: 16.sp)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('Cancel', style: GoogleFonts.fredoka(fontSize: 16.sp))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                currentTrial = 0;
                totalCorrect = 0;
                starsEarned = 0;
                correctInAddition = 0;
                correctInSubtraction = 0;
                _consecutiveCorrect = 0;
                _subtractionPhaseComplete = false;
                collectedStars.clear();
                _recentAddition.clear();
                _recentSubtraction.clear();
                selectedAnswer = null;
                _allLevelsComplete = false;
              });
              _speak("Let's do math together!");
              _generateNewTrial();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Start Over',
                style: GoogleFonts.fredoka(
                    fontSize: 16.sp, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _endSession({required bool naturalCompletion}) {
    _cancelAllTimers();
    _sessionTimer?.cancel();
    if (naturalCompletion && _sessionTimerExpired) {
      _saveProgress();
      _showSessionReward();
    } else {
      // Early exit or timer not done – just go back
      Navigator.of(context).pop();
    }
  }

  /// Called when all levels/sublevels are complete before session timer ends.
  void _onAllLevelsComplete() {
    if (_allLevelsComplete) return;
    setState(() => _allLevelsComplete = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32.r)),
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events_rounded,
                  color: Colors.amber, size: 80.w),
              SizedBox(height: 16.h),
              Text(
                'All levels complete!',
                style: GoogleFonts.fredoka(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.success),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              Text(
                'Keep practising until the session time ends.',
                style: GoogleFonts.fredoka(fontSize: 16.sp),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success),
                child: Text('OK',
                    style: GoogleFonts.fredoka(
                        fontSize: 20.sp, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reward dialogs ──────────────────────────────────────────────────────────

  void _showWellDoneAnimation() {
    if (!mounted) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => Center(
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.2, end: 1.2).animate(
            CurvedAnimation(
                parent: ModalRoute.of(context)!.animation!,
                curve: Curves.elasticOut),
          ),
          child: Text('🎉', style: TextStyle(fontSize: 200.sp)),
        ),
      ),
    );
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    });
  }

  void _showSubLevelReward() {
    if (!mounted) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      pageBuilder: (_, __, ___) => Center(
        child: Container(
          padding: EdgeInsets.all(28.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(36.r),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.success.withOpacity(0.3),
                  blurRadius: 24,
                  spreadRadius: 6)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded,
                  color: AppTheme.success, size: 80.w),
              SizedBox(height: 16.h),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                    3,
                    (_) => Icon(Icons.star_rounded,
                        color: Colors.amber, size: 44.w)),
              ),
            ],
          ),
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    });
  }

  void _showPhaseTransitionDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32.r)),
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🌟', style: TextStyle(fontSize: 80.sp)),
              SizedBox(height: 14.h),
              Text(
                'Subtraction complete! Amazing!',
                style: GoogleFonts.fredoka(
                    fontSize: 26.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.success),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10.h),
              Text(
                "Now let's learn addition!",
                style: GoogleFonts.fredoka(fontSize: 20.sp),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Text(
                "Addition is joining groups together.\n"
                "You already know how to take apart – now put them together!",
                style: GoogleFonts.fredoka(
                    fontSize: 15.sp, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 28.h),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _generateNewTrial();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  padding: EdgeInsets.symmetric(
                      horizontal: 40.w, vertical: 14.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r)),
                ),
                child: Text(
                  "Let's go! 🚀",
                  style: GoogleFonts.fredoka(
                      fontSize: 22.sp, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    _speak("You finished all of subtraction! Amazing work! "
        "Now let's learn addition. "
        "Addition is putting groups together. Let's see how it works!");
  }

  void _showLevelUpDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32.r)),
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events_rounded,
                  color: Colors.amber, size: 80.w),
              SizedBox(height: 14.h),
              Text('Level Up! 🎉',
                  style: GoogleFonts.fredoka(
                      fontSize: 34.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.success)),
              SizedBox(height: 6.h),
              Text('You reached Level $currentLevel!',
                  style: GoogleFonts.fredoka(fontSize: 22.sp)),
              SizedBox(height: 28.h),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _generateNewTrial();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  padding: EdgeInsets.symmetric(
                      horizontal: 40.w, vertical: 14.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r)),
                ),
                child: Text('Keep Going! 🚀',
                    style: GoogleFonts.fredoka(
                        fontSize: 22.sp, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSessionReward() {
    if (!mounted) return;
    final starCount =
        (starsEarned / _totalExpectedTrials.clamp(1, 9999) * 3)
            .round()
            .clamp(0, 3);
    _speak(starCount == 3
        ? "Amazing work! You are a math star!"
        : "Well done! Great job today!");
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40.r)),
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (i) => Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10.w),
                    child: Icon(
                      i < starCount
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 72.w,
                      color: i < starCount
                          ? Colors.amber
                          : Colors.grey.shade300,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                starCount == 3 ? "Amazing Work! 🎉" : "Well Done! 👍",
                style: GoogleFonts.fredoka(
                    fontSize: 30.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.success),
              ),
              SizedBox(height: 6.h),
              Text("You got $totalCorrect correct!",
                  style: GoogleFonts.fredoka(fontSize: 20.sp)),
              Text("Total stars: $lifetimeStars ⭐",
                  style: GoogleFonts.fredoka(
                      fontSize: 18.sp, fontWeight: FontWeight.bold)),
              if (widget.rewardImagePath != null && starCount >= 2) ...[
                SizedBox(height: 16.h),
                Image.asset(widget.rewardImagePath!, height: 110.h),
              ],
              SizedBox(height: 24.h),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  widget.onSessionComplete();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  padding: EdgeInsets.symmetric(
                      horizontal: 50.w, vertical: 14.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r)),
                ),
                child: Text("Continue",
                    style: GoogleFonts.fredoka(
                        fontSize: 22.sp, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── UI helpers ──────────────────────────────────────────────────────────────

  String get _levelLabel => 'Level $currentLevel';

  String get _phaseLabel {
    if (widget.sessionMode == 'addition') return '+ Addition';
    if (widget.sessionMode == 'subtraction') return '− Subtraction';
    return _inSubtractionPhase ? '− Subtraction' : '+ Addition';
  }

  Color get _phaseColor =>
      _inSubtractionPhase ? Colors.orange : Colors.green;

  Widget _buildTimerDisplay() {
    if (widget.sessionDuration == 0) return const SizedBox.shrink();
    final mins = _remainingSeconds ~/ 60;
    final secs = _remainingSeconds % 60;
    final isLow = _remainingSeconds < 60;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_rounded,
            size: 20.w,
            color: isLow ? Colors.red : Colors.grey.shade600),
        SizedBox(width: 4.w),
        Text(
          '$mins:${secs.toString().padLeft(2, '0')}',
          style: GoogleFonts.fredoka(
            fontSize: 18.sp,
            color: isLow ? Colors.red : Colors.grey.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildProblemCard() {
    final cs = Theme.of(context).colorScheme;
    Color borderCol = cs.primary.withOpacity(0.2);
    Color? glowColor;
    if (isShowMeActive) { borderCol = Colors.blue; glowColor = Colors.blue; }
    else if (showHint) { borderCol = _phaseColor; glowColor = _phaseColor; }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 380.w,
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 20.h),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(40.r),
        border: Border.all(
            color: borderCol,
            width: glowColor != null ? 5.w : 4.w),
        boxShadow: glowColor != null
            ? [BoxShadow(
                color: glowColor.withOpacity(0.25),
                blurRadius: 16,
                spreadRadius: 4)]
            : [BoxShadow(
                color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isAddition
                ? '$firstOperand + $secondOperand = ?'
                : '$firstOperand − $secondOperand = ?',
            style: GoogleFonts.fredoka(
              fontSize: 52.sp,
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
          ),
          if (isShowMeActive || showHint) ...[
            SizedBox(height: 16.h),
            _buildVisualAid(),
          ],
        ],
      ),
    );
  }

  Widget _buildChoiceCard(int num) {
    final cs = Theme.of(context).colorScheme;
    final isCorrect = num == answer;
    final isSelected = selectedAnswer == num;
    final correctHighlighted = isCorrect && (showPrompt || showHint);
    final wrongSelected = isSelected && !isCorrect && hasAnswered;

    final Color borderColor = correctHighlighted
        ? Colors.green
        : wrongSelected
            ? Colors.red
            : Colors.grey.shade300;
    final Color bgColor = correctHighlighted
        ? Colors.green.withOpacity(0.15)
        : wrongSelected
            ? Colors.red.withOpacity(0.10)
            : Colors.white;
    final Color textColor = correctHighlighted
        ? Colors.green.shade700
        : wrongSelected
            ? Colors.red.shade700
            : cs.primary;

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final shakeX = wrongSelected
            ? sin(_shakeController.value * pi * 4) * 10.0
            : 0.0;
        return Transform.translate(offset: Offset(shakeX, 0), child: child);
      },
      child: GestureDetector(
        onTap: (hasAnswered || isShowMeActive) ? null : () => _handleTap(num),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 110.w,
          height: 130.h,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(28.r),
            border: Border.all(
                color: borderColor,
                width: correctHighlighted ? 5.w : 3.w),
            boxShadow: correctHighlighted
                ? [BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2)]
                : [BoxShadow(
                    color: Colors.black.withOpacity(0.06), blurRadius: 4)],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                num.toString(),
                style: GoogleFonts.fredoka(
                  fontSize: 48.sp,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              if (correctHighlighted)
                Positioned(
                    top: 6.h,
                    right: 6.w,
                    child: Icon(Icons.check_circle,
                        color: Colors.green, size: 22.w)),
              if (wrongSelected)
                Positioned(
                    top: 6.h,
                    right: 6.w,
                    child: Icon(Icons.cancel,
                        color: Colors.red, size: 22.w)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // ── Top bar ─────────────────────────────────────────────────
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 16.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: cs.surface,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 4)
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _confirmExit,
                      icon: Icon(Icons.arrow_back_rounded,
                          size: 28.w, color: cs.primary),
                      tooltip: 'Exit',
                    ),
                    Row(children: [
                      Icon(Icons.star_rounded,
                          color: Colors.amber, size: 26.w),
                      SizedBox(width: 4.w),
                      Text('$lifetimeStars',
                          style: GoogleFonts.fredoka(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold)),
                    ]),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _levelLabel,
                        key: ValueKey(_levelLabel),
                        style: GoogleFonts.fredoka(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w600,
                            color: cs.primary),
                      ),
                    ),
                    const Spacer(),
                    _buildTimerDisplay(),
                    // Show Me
                    IconButton(
                      onPressed: (isShowMeActive || hasAnswered)
                          ? null
                          : _activateShowMe,
                      icon: Icon(Icons.play_circle_outline_rounded,
                          size: 30.w,
                          color: isShowMeActive
                              ? Colors.grey
                              : Colors.blue),
                      tooltip: 'Show Me',
                    ),
                    // Hint
                    IconButton(
                      onPressed:
                          (showHint || isShowMeActive || hasAnswered)
                              ? null
                              : _triggerHint,
                      icon: Icon(
                        showHint
                            ? Icons.lightbulb
                            : Icons.lightbulb_outline_rounded,
                        size: 30.w,
                        color: Colors.orange,
                      ),
                      tooltip: 'Hint',
                    ),
                    IconButton(
                      onPressed: _restartActivity,
                      icon: Icon(Icons.refresh_rounded,
                          size: 28.w, color: Colors.orange),
                      tooltip: 'Restart',
                    ),
                  ],
                ),
              ),

              // ── Progress bar (phase colour) ─────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(24.w, 10.h, 24.w, 4.h),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: LinearProgressIndicator(
                    value: overallProgress,
                    backgroundColor: cs.surfaceContainerHighest,
                    color: _phaseColor,
                    minHeight: 12.h,
                  ),
                ),
              ),

              // ── Scrollable content ───────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: 14.h),

                      // Phase pill
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        child: Container(
                          key: ValueKey(_phaseLabel),
                          padding: EdgeInsets.symmetric(
                              horizontal: 16.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: _phaseColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Text(
                            _phaseLabel,
                            style: GoogleFonts.fredoka(
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w600,
                              color: _phaseColor,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 14.h),

                      // Problem card with embedded visual aid
                      _buildProblemCard(),

                      SizedBox(height: 20.h),

                      Text(
                        "Choose the answer:",
                        style: GoogleFonts.fredoka(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withOpacity(0.65)),
                      ),

                      SizedBox(height: 18.h),

                      // Choice cards
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceEvenly,
                          children:
                              choices.map(_buildChoiceCard).toList(),
                        ),
                      ),

                      SizedBox(height: 20.h),

                      if (collectedStars.isNotEmpty)
                        Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 24.w),
                          child: Wrap(
                            spacing: 6.w,
                            children: collectedStars,
                          ),
                        ),

                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}