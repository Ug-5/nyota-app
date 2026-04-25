// lib/screens/advancemath.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nyota/theme.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';

class AdvancedMathActivityScreen extends StatefulWidget {
  final VoidCallback onSessionComplete;
  final String? rewardImagePath;
  final String sessionMode; // 'multiplication', 'division', or 'mixed'
  final int sessionDuration; // in minutes, required

  const AdvancedMathActivityScreen({
    super.key,
    required this.onSessionComplete,
    this.rewardImagePath,
    this.sessionMode = 'mixed',
    required this.sessionDuration,
  });

  @override
  State<AdvancedMathActivityScreen> createState() =>
      _AdvancedMathActivityScreenState();
}

class _AdvancedMathActivityScreenState
    extends State<AdvancedMathActivityScreen> with TickerProviderStateMixin {

  // ── Configuration ──────────────────────────────────────────────────────────
  static const int trialsPerSubLevel = 4;
  static const int maxLevel = 4;
  final List<int> subLevelsPerLevel = [3, 3, 4, 4];

  // ── Game State ─────────────────────────────────────────────────────────────
  int currentLevel = 1;
  int multiplicationSubLevel = 1;
  int divisionSubLevel = 1;
  int correctInMultiplication = 0;
  int correctInDivision = 0;

  bool _divisionPhaseComplete = false;

  int currentTrial = 0;
  int totalCorrect = 0;
  int starsEarned = 0;
  int lifetimeStars = 0;

  int _consecutiveCorrect = 0;

  int a = 2, b = 3, answer = 6;
  bool isMultiplication = true;
  List<int> choices = [];

  bool showPrompt = false;
  bool hasAnswered = false;
  bool showHint = false;
  bool isShowMeActive = false;
  int? selectedAnswer;

  final List<bool> _recentMultiplication = [];
  final List<bool> _recentDivision = [];

  // ── Timers ─────────────────────────────────────────────────────────────────
  Timer? _advanceTimer;
  Timer? _hintTimer;
  Timer? _speakTimer;
  Timer? _showMeTimer;
  Timer? _sessionTimer;
  int _remainingSeconds = 0;

  // New session state flags
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
      currentLevel = prefs.getInt('advancedmath_level') ?? 1;
      multiplicationSubLevel = prefs.getInt('advancedmath_mult_sub') ?? 1;
      divisionSubLevel = prefs.getInt('advancedmath_div_sub') ?? 1;
      lifetimeStars = prefs.getInt('lifetime_stars') ?? 0;
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('advancedmath_level', currentLevel);
    await prefs.setInt('advancedmath_mult_sub', multiplicationSubLevel);
    await prefs.setInt('advancedmath_div_sub', divisionSubLevel);
  }

  Future<void> _saveLifetimeStars() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lifetime_stars', lifetimeStars);
  }

  bool _timeIsUp() =>
      widget.sessionDuration != null && _remainingSeconds <= 0;

  // ── Phase logic ─────────────────────────────────────────────────────────────

  bool get _inDivisionPhase {
    if (widget.sessionMode == 'division') return true;
    if (widget.sessionMode == 'multiplication') return false;
    return !_divisionPhaseComplete;
  }

  int get _effectiveSubLevel =>
      _inDivisionPhase ? divisionSubLevel : multiplicationSubLevel;

  int get maxFactor {
    final base = 2 + (currentLevel - 1) * 2;
    return (base + _effectiveSubLevel).clamp(3, 12);
  }

  int get minFactor =>
      currentLevel == 1 ? 2 : (_effectiveSubLevel > 1 ? 3 : 2);

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

    final bool divMode = _inDivisionPhase;

    setState(() {
      hasAnswered = false;
      showPrompt = false;
      showHint = false;
      isShowMeActive = false;
      selectedAnswer = null;
      isMultiplication = !divMode;

      final maxNum = maxFactor;
      final minNum = minFactor;
      if (isMultiplication) {
        a = minNum + Random().nextInt(maxNum - minNum + 1);
        b = minNum + Random().nextInt(maxNum - minNum + 1);
        answer = a * b;
      } else {
        b = minNum + Random().nextInt(maxNum - minNum + 1);
        final multiplier = minNum + Random().nextInt(maxNum - minNum + 1);
        a = b * multiplier;
        answer = multiplier;
      }

      _generateChoices();
    });

    _speakTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        _speak(isMultiplication
            ? "What is $a times $b?"
            : "What is $a divided by $b?");
      }
    });

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
      if (c > 0 && c <= 150 && !used.contains(c)) {
        choices.add(c);
        used.add(c);
      }
    }

    if (isMultiplication) {
      tryAdd(a + b);
      tryAdd(answer + 1);
      tryAdd((a + 1) * b);
      tryAdd(a * (b + 1));
    } else {
      tryAdd(answer + 1);
      tryAdd(answer + 2);
      tryAdd(b);
      tryAdd(answer > 2 ? answer - 1 : answer + 3);
    }

    int fallback = answer + choices.length + 1;
    int guard = 0;
    while (choices.length < 4 && guard < 20) {
      tryAdd(fallback++);
      guard++;
    }

    choices.shuffle();
  }

  String _conceptExplanation() {
    if (isMultiplication) {
      final cap = a.clamp(1, 5);
      final countList = List.generate(cap, (i) => '${(i + 1) * b}').join(', ');
      return "$a times $b means $a groups of $b. "
          "Count with me: $countList. "
          "The answer is $answer.";
    } else {
      return "$a divided by $b means sharing $a things equally into $b groups. "
          "Each group gets $answer. "
          "The answer is $answer.";
    }
  }

  // ── Interaction ─────────────────────────────────────────────────────────────

  void _handleTap(int selected) {
    if (!mounted || hasAnswered || isShowMeActive || _allLevelsComplete) return;

    final isCorrect = selected == answer;

    if (isMultiplication) {
      _recentMultiplication.add(isCorrect);
      if (_recentMultiplication.length > 5) _recentMultiplication.removeAt(0);
    } else {
      _recentDivision.add(isCorrect);
      if (_recentDivision.length > 5) _recentDivision.removeAt(0);
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
        if (isMultiplication) correctInMultiplication++;
        else correctInDivision++;
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
    return isMultiplication
        ? "$a times $b equals $answer."
        : "$a divided by $b equals $answer.";
  }

  // ── Progression ─────────────────────────────────────────────────────────────

  void _advanceAfterCorrect() {
    bool subLevelAdvanced = false;

    if (!isMultiplication) {
      if (correctInDivision >= trialsPerSubLevel) {
        if (divisionSubLevel < subLevelsPerLevel[currentLevel - 1]) {
          setState(() { divisionSubLevel++; correctInDivision = 0; });
          _recentDivision.clear();
          subLevelAdvanced = true;
          _saveProgress();
          _speak("Excellent division! Let's try harder numbers.");
          _showSubLevelReward();
        } else {
          if (widget.sessionMode == 'mixed') {
            setState(() { _divisionPhaseComplete = true; correctInDivision = 0; });
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
      if (correctInMultiplication >= trialsPerSubLevel) {
        if (multiplicationSubLevel < subLevelsPerLevel[currentLevel - 1]) {
          setState(() { multiplicationSubLevel++; correctInMultiplication = 0; });
          _recentMultiplication.clear();
          subLevelAdvanced = true;
          _saveProgress();
          _speak("Excellent multiplication! Let's try harder numbers.");
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
      multiplicationSubLevel = 1;
      divisionSubLevel = 1;
      correctInMultiplication = 0;
      correctInDivision = 0;
      _divisionPhaseComplete = false;
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
      final divMax = subLevelsPerLevel[currentLevel - 1];
      final divDone = _divisionPhaseComplete ? divMax : (divisionSubLevel - 1);
      final multDone = _divisionPhaseComplete ? (multiplicationSubLevel - 1) : 0;
      completed += divDone + multDone;
      final correctNow =
          isMultiplication ? correctInMultiplication : correctInDivision;
      return ((completed + correctNow / trialsPerSubLevel) / totalSub)
          .clamp(0.0, 1.0);
    } else {
      final totalSub = subLevelsPerLevel.reduce((a, b) => a + b);
      int completed = 0;
      for (int i = 0; i < currentLevel - 1; i++) {
        completed += subLevelsPerLevel[i];
      }
      final currentSub =
          isMultiplication ? multiplicationSubLevel : divisionSubLevel;
      completed += currentSub - 1;
      final correctNow =
          isMultiplication ? correctInMultiplication : correctInDivision;
      return ((completed + correctNow / trialsPerSubLevel) / totalSub)
          .clamp(0.0, 1.0);
    }
  }

  void _maybeAdjustSubLevels() {
    if (!isMultiplication && _recentDivision.length >= 5) {
      final acc =
          _recentDivision.where((c) => c).length / _recentDivision.length;
      if (acc >= 0.8 &&
          divisionSubLevel < subLevelsPerLevel[currentLevel - 1]) {
        setState(() { divisionSubLevel++; correctInDivision = 0; });
        _recentDivision.clear();
        _saveProgress();
        _speak("You are great at division! Let's try harder problems.");
      } else if (acc <= 0.4 && divisionSubLevel > 1) {
        setState(() { divisionSubLevel--; correctInDivision = 0; });
        _recentDivision.clear();
        _saveProgress();
        _speak("Let's practice this step a little more.");
      }
    }

    if (isMultiplication && _recentMultiplication.length >= 5) {
      final acc = _recentMultiplication.where((c) => c).length /
          _recentMultiplication.length;
      if (acc >= 0.8 &&
          multiplicationSubLevel < subLevelsPerLevel[currentLevel - 1]) {
        setState(() { multiplicationSubLevel++; correctInMultiplication = 0; });
        _recentMultiplication.clear();
        _saveProgress();
        _speak("You are great at multiplication! Let's try harder problems.");
      } else if (acc <= 0.4 && multiplicationSubLevel > 1) {
        setState(() { multiplicationSubLevel--; correctInMultiplication = 0; });
        _recentMultiplication.clear();
        _saveProgress();
        _speak("Let's practice this step a little more.");
      }
    }
  }

  void _addVisibleStar() {
    collectedStars
        .add(const Icon(Icons.star_rounded, color: Colors.amber, size: 32));
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

    final speech = isMultiplication
        ? "Watch this! $a times $b means $a groups of $b. "
          "${_buildCountingText()} "
          "So the answer is $answer! Now you try!"
        : "Watch this! $a divided by $b means sharing $a things "
          "equally into $b groups. "
          "Each group gets $answer. "
          "The answer is $answer! Now you try!";

    _speak(speech);

    _showMeTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => isShowMeActive = false);
    });
  }

  String _buildCountingText() {
    final cap = a.clamp(1, 5);
    return "Count with me: ${List.generate(cap, (i) => '${(i + 1) * b}').join(', ')}.";
  }

  // ── Visual math aid ──────────────────────────────────────────────────────────

  Widget _buildVisualAid() {
    final int rows = a.clamp(1, 5);
    final int cols = b.clamp(1, 5);
    final bool truncated = a > 5 || b > 5;

    if (isMultiplication) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$a groups of $b",
            style: GoogleFonts.fredoka(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple.shade500),
          ),
          SizedBox(height: 6.h),
          ...List.generate(rows, (r) {
            final runningTotal = (r + 1) * b;
            return Padding(
              padding: EdgeInsets.only(bottom: 4.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...List.generate(
                    cols,
                    (_) => Padding(
                      padding: EdgeInsets.symmetric(horizontal: 3.w),
                      child: CircleAvatar(
                        radius: 7.w,
                        backgroundColor: Colors.deepPurple.withOpacity(0.55),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    '= $runningTotal',
                    style: GoogleFonts.fredoka(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepPurple.shade700),
                  ),
                ],
              ),
            );
          }),
          if (truncated)
            Text('(showing first 5 groups)',
                style: GoogleFonts.fredoka(
                    fontSize: 11.sp, color: Colors.grey.shade500)),
          SizedBox(height: 4.h),
          Text('$a × $b = $answer',
              style: GoogleFonts.fredoka(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade700)),
        ],
      );
    } else {
      final int groups = answer.clamp(1, 5);
      final int perGroup = b.clamp(1, 5);
      final bool truncDiv = answer > 5 || b > 5;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$a shared equally into $b groups",
            style: GoogleFonts.fredoka(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade700),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(groups, (g) => Container(
              margin: EdgeInsets.symmetric(horizontal: 4.w),
              padding: EdgeInsets.all(5.w),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.08),
                border: Border.all(color: Colors.teal.shade400, width: 2),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      perGroup,
                      (_) => Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2.w),
                        child: CircleAvatar(
                          radius: 6.w,
                          backgroundColor: Colors.teal.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    '$answer each',
                    style: GoogleFonts.fredoka(
                        fontSize: 11.sp, color: Colors.teal.shade700),
                  ),
                ],
              ),
            )),
          ),
          if (truncDiv)
            Text('(showing first 5 groups)',
                style: GoogleFonts.fredoka(
                    fontSize: 11.sp, color: Colors.grey.shade500)),
          SizedBox(height: 4.h),
          Text('$a ÷ $b = $answer',
              style: GoogleFonts.fredoka(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade700)),
        ],
      );
    }
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
          padding:
              EdgeInsets.symmetric(horizontal: 36.w, vertical: 32.h),
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
                correctInMultiplication = 0;
                correctInDivision = 0;
                _consecutiveCorrect = 0;
                _divisionPhaseComplete = false;
                collectedStars.clear();
                _recentMultiplication.clear();
                _recentDivision.clear();
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
      // Early exit or timer not expired – do NOT mark dashboard completion
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
                'Division done! Amazing!',
                style: GoogleFonts.fredoka(
                    fontSize: 26.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.success),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10.h),
              Text(
                "Now let's learn multiplication!",
                style: GoogleFonts.fredoka(fontSize: 20.sp),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Text(
                "Multiplication is the opposite of division.\n"
                "Instead of sharing, we build groups!",
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
    _speak("You finished all of division! Amazing work! "
        "Now let's learn multiplication. "
        "It is the opposite of division. "
        "Instead of sharing, we build groups. Ready?");
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
    if (widget.sessionMode == 'multiplication') return '✖  Multiplication';
    if (widget.sessionMode == 'division') return '÷  Division';
    return _inDivisionPhase ? '÷  Division' : '✖  Multiplication';
  }

  Color get _phaseColor =>
      _inDivisionPhase ? Colors.teal : Colors.deepPurple;

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
            isMultiplication ? '$a × $b = ?' : '$a ÷ $b = ?',
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

              // ── Progress bar ─────────────────────────────────────────────
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