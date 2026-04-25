// lib/screens/counting_activity.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:nyota/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Animated finger tutorial widget
// ─────────────────────────────────────────────────────────────────────────────
class _FingerTutorial extends StatefulWidget {
  final Offset start;   // screen-space centre of start target
  final Offset? end;    // if set → drag mode (level 3)
  final VoidCallback onDone;

  const _FingerTutorial({
    required this.start,
    this.end,
    required this.onDone,
  });

  @override
  State<_FingerTutorial> createState() => _FingerTutorialState();
}

class _FingerTutorialState extends State<_FingerTutorial>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _dy;
  late Animation<double> _dx;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  bool get _isDrag => widget.end != null;

  @override
  void initState() {
    super.initState();
    final ms = _isDrag ? 1200 : 750;
    _ctrl = AnimationController(
        vsync: this, duration: Duration(milliseconds: ms));

    if (_isDrag) {
      // appear → grab → slide to target → release → fade
      _dx = TweenSequence<double>([
        TweenSequenceItem(tween: ConstantTween(0.0), weight: 12),
        TweenSequenceItem(tween: ConstantTween(0.0), weight: 10),
        TweenSequenceItem(
            tween: Tween(begin: 0.0, end: 1.0)
                .chain(CurveTween(curve: Curves.easeInOut)),
            weight: 52),
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 16),
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 10),
      ]).animate(_ctrl);

      _dy = ConstantTween<double>(0.0).animate(_ctrl);

      _scale = TweenSequence<double>([
        TweenSequenceItem(
            tween: Tween(begin: 1.0, end: 1.0), weight: 12),
        TweenSequenceItem(
            tween: Tween(begin: 1.0, end: 1.3), weight: 10),
        TweenSequenceItem(tween: ConstantTween(1.3), weight: 52),
        TweenSequenceItem(
            tween: Tween(begin: 1.3, end: 1.0), weight: 16),
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 10),
      ]).animate(_ctrl);

      _opacity = TweenSequence<double>([
        TweenSequenceItem(
            tween: Tween(begin: 0.0, end: 1.0), weight: 10),
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 80),
        TweenSequenceItem(
            tween: Tween(begin: 1.0, end: 0.0), weight: 10),
      ]).animate(_ctrl);
    } else {
      // drop in → tap down → lift → tap down → lift → fade
      _dy = TweenSequence<double>([
        TweenSequenceItem(
            tween: Tween(begin: -28.0, end: 0.0)
                .chain(CurveTween(curve: Curves.easeOut)),
            weight: 12),
        TweenSequenceItem(
            tween: Tween(begin: 0.0, end: 24.0)
                .chain(CurveTween(curve: Curves.easeIn)),
            weight: 14),
        TweenSequenceItem(
            tween: Tween(begin: 24.0, end: -8.0)
                .chain(CurveTween(curve: Curves.easeOut)),
            weight: 14),
        TweenSequenceItem(
            tween: Tween(begin: -8.0, end: 24.0)
                .chain(CurveTween(curve: Curves.easeIn)),
            weight: 14),
        TweenSequenceItem(
            tween: Tween(begin: 24.0, end: -8.0)
                .chain(CurveTween(curve: Curves.easeOut)),
            weight: 14),
        TweenSequenceItem(tween: ConstantTween(-8.0), weight: 22),
      ]).animate(_ctrl);

      _dx = ConstantTween<double>(0.0).animate(_ctrl);

      _scale = TweenSequence<double>([
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 12),
        TweenSequenceItem(
            tween: Tween(begin: 1.0, end: 1.25), weight: 14),
        TweenSequenceItem(
            tween: Tween(begin: 1.25, end: 1.0), weight: 14),
        TweenSequenceItem(
            tween: Tween(begin: 1.0, end: 1.25), weight: 14),
        TweenSequenceItem(
            tween: Tween(begin: 1.25, end: 1.0), weight: 14),
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 32),
      ]).animate(_ctrl);

      _opacity = TweenSequence<double>([
        TweenSequenceItem(
            tween: Tween(begin: 0.0, end: 1.0), weight: 8),
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 78),
        TweenSequenceItem(
            tween: Tween(begin: 1.0, end: 0.0), weight: 14),
      ]).animate(_ctrl);
    }

    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });

    // Brief settle delay before the finger appears
    Future.delayed(const Duration(milliseconds: 550),
        () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final lerpX = _isDrag
            ? (widget.end!.dx - widget.start.dx) * _dx.value
            : 0.0;
        final lerpY = _isDrag
            ? (widget.end!.dy - widget.start.dy) * _dx.value
            : _dy.value;

        return Positioned(
          left: widget.start.dx + lerpX - 24,
          top: widget.start.dy + lerpY - 24,
          child: IgnorePointer(
            child: Opacity(
              opacity: _opacity.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: _scale.value,
                child: const Text(
                  '👆',
                  style: TextStyle(
                    fontSize: 48,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 8)],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main activity
// ─────────────────────────────────────────────────────────────────────────────
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
    with TickerProviderStateMixin {
  // ── Configuration ────────────────────────────────────────────────────────────
  static const int trialsPerSubLevel = 4;
  static const int maxLevel = 3;
  final List<int> subLevelsPerLevel = [4, 4, 4];

  // ── Game state ───────────────────────────────────────────────────────────────
  int currentLevel = 1;
  int currentSubLevel = 1;
  int correctInSubLevel = 0;
  int currentTrial = 0;
  int totalCorrect = 0;
  int starsEarned = 0;
  int countingStars = 0;

  int targetCount = 0;
  List<int> choices = [];
  bool hasAnswered = false;
  bool showNextButton = false;   // ← paces the child manually

  bool showHint = false;
  bool isCountingHint = false;
  int currentHintIndex = -1;
  int? _wrongTappedChoice;
  int _wrongAttempts = 0;
  bool _hintRunning = false;

  // ── Tutorial state ───────────────────────────────────────────────────────────
  bool _showTutorial = false;
  Offset? _tutorialStart;
  Offset? _tutorialEnd;
  // Which levels have already shown their tutorial
  final Set<int> _tutorialShownForLevel = {};

  // ── Keys ─────────────────────────────────────────────────────────────────────
  // One key per card position (0,1,2) — NOT per value
  final List<GlobalKey> _choiceKeys = [GlobalKey(), GlobalKey(), GlobalKey()];
  final GlobalKey _dropZoneKey = GlobalKey();
  final GlobalKey _objectsAreaKey = GlobalKey();
  final List<GlobalKey> _objectKeys = [];

  // ── Assets ───────────────────────────────────────────────────────────────────
  final List<String> objectImages = [
    'assets/images/apple.png',
    'assets/images/banana.png',
    'assets/images/ball.png',
    'assets/images/star.png',
    'assets/images/car.png',
    'assets/images/cube.png',
  ];

  // ── Timers ───────────────────────────────────────────────────────────────────
  Timer? _wrongClearTimer;
  Timer? _hintAutoTimer;

  // ── TTS ──────────────────────────────────────────────────────────────────────
  late FlutterTts _tts;
  bool _ttsReady = false;
  bool _soundEnabled = true;
  // Per-utterance completer — resolved by completion/error/cancel handlers
  Completer<void>? _ttsCompleter;

  // ── Animations ───────────────────────────────────────────────────────────────
  late AnimationController _shakeController;
  late AnimationController _celebrationController;

  DateTime? sessionStartTime;
  List<Widget> collectedStars = [];

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    sessionStartTime = DateTime.now();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _celebrationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);

    _initTts();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPersistentData().then((_) {
        if (mounted) _generateNewTrial();
      });
    });
  }

  Future<void> _initTts() async {
    _tts = FlutterTts();
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.42);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.1);

    void resolve() {
      if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
        _ttsCompleter!.complete();
      }
      _ttsCompleter = null;
    }

    _tts.setCompletionHandler(resolve);
    _tts.setErrorHandler((_) => resolve());
    _tts.setCancelHandler(resolve);

    try {
      await _tts.setVoice(
          {"name": "en-US-x-tpf-local", "locale": "en-US"});
    } catch (_) {}

    if (mounted) setState(() => _ttsReady = true);
    await _loadSoundPreference();
  }

  Future<void> _loadSoundPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;
  }

  /// Stops the current utterance, speaks [text], and awaits completion
  /// (or [timeout] — whichever comes first) so the hint loop stays in sync
  /// without ever freezing the UI.
  Future<void> _speak(String text,
      {Duration timeout = const Duration(seconds: 5)}) async {
    if (!mounted || !_ttsReady || !_soundEnabled) return;

    // Resolve any pending completer then stop current speech
    if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
      _ttsCompleter!.complete();
    }
    await _tts.stop();

    _ttsCompleter = Completer<void>();
    await _tts.speak(text);

    try {
      await _ttsCompleter!.future.timeout(timeout);
    } on TimeoutException {
      _ttsCompleter = null;
    }
  }

  @override
  void dispose() {
    _wrongClearTimer?.cancel();
    _hintAutoTimer?.cancel();
    _hintRunning = false;
    if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
      _ttsCompleter!.complete();
    }
    _shakeController.dispose();
    _celebrationController.dispose();
    _tts.stop();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // ── Persistence ──────────────────────────────────────────────────────────────

  Future<void> _loadPersistentData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      currentLevel = prefs.getInt('counting_level') ?? 1;
      currentSubLevel = prefs.getInt('counting_sublevel') ?? 1;
      countingStars = prefs.getInt('counting_stars') ?? 0;
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('counting_level', currentLevel);
    await prefs.setInt('counting_sublevel', currentSubLevel);
  }

  Future<void> _saveCountingStars() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('counting_stars', countingStars);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  bool _timeIsUp() {
    if (widget.maxDurationMinutes == null || sessionStartTime == null) {
      return false;
    }
    return DateTime.now().difference(sessionStartTime!).inMinutes >=
        widget.maxDurationMinutes!;
  }

  int get minObjects => 2 + currentSubLevel;
  int get maxObjects => 3 + currentSubLevel * 2;

  int get _totalExpectedTrials =>
      subLevelsPerLevel.reduce((a, b) => a + b) * trialsPerSubLevel;

  double get overallProgress {
    int completedSubLevels = 0;
    for (int i = 0; i < currentLevel - 1; i++) {
      completedSubLevels += subLevelsPerLevel[i];
    }
    completedSubLevels += currentSubLevel - 1;
    final total = subLevelsPerLevel.reduce((a, b) => a + b);
    return (completedSubLevels + correctInSubLevel / trialsPerSubLevel) / total;
  }

  void _cancelAllTimers() {
    _wrongClearTimer?.cancel();
    _hintAutoTimer?.cancel();
    _hintRunning = false;
  }

  // ── Trial generation ─────────────────────────────────────────────────────────

  void _generateNewTrial() {
    _cancelAllTimers();
    // Always stop TTS before starting a new trial — prevents bleed-over speech
    _tts.stop();
    if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
      _ttsCompleter!.complete();
      _ttsCompleter = null;
    }

    if (_timeIsUp()) {
      _endSession(naturalCompletion: true);
      return;
    }

    _objectKeys.clear();

    setState(() {
      hasAnswered = false;
      showNextButton = false;   // ← hide Next button
      showHint = false;
      isCountingHint = false;
      currentHintIndex = -1;
      _wrongTappedChoice = null;
      _wrongAttempts = 0;
      _showTutorial = false;
      targetCount =
          minObjects + Random().nextInt(maxObjects - minObjects + 1);
      _generateChoices();
    });

    for (int i = 0; i < targetCount; i++) {
      _objectKeys.add(GlobalKey());
    }

    // Wait a frame for objects to render, then show the tutorial immediately
    // and speak the question in parallel.
    Future.delayed(const Duration(milliseconds: 750), () async {
      if (!mounted || _hintRunning) return;

      // 👈 FIXED: Show tutorial BEFORE TTS so it can't be skipped by an early answer
      if (mounted) _maybeTriggerTutorial();

      await _speak("How many?");
    });
  }

  void _generateChoices() {
    choices = [targetCount];
    while (choices.length < 3) {
      int d = minObjects + Random().nextInt(maxObjects - minObjects + 1);
      if (d != targetCount && !choices.contains(d)) choices.add(d);
    }
    choices.shuffle();
  }

  // ── Tutorial ─────────────────────────────────────────────────────────────────

  void _maybeTriggerTutorial() {
    if (_tutorialShownForLevel.contains(currentLevel)) return;
    _tutorialShownForLevel.add(currentLevel);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || hasAnswered) return;

      final correctCardIndex = choices.indexOf(targetCount);

      if (currentLevel == 3) {
        final cardBox = _choiceKeys[correctCardIndex]
            .currentContext
            ?.findRenderObject() as RenderBox?;
        final dropBox =
            _dropZoneKey.currentContext?.findRenderObject() as RenderBox?;
        if (cardBox != null && dropBox != null) {
          setState(() {
            _tutorialStart =
                cardBox.localToGlobal(cardBox.size.center(Offset.zero));
            _tutorialEnd =
                dropBox.localToGlobal(dropBox.size.center(Offset.zero));
            _showTutorial = true;
          });
        }
      } else {
        final box = _choiceKeys[correctCardIndex]
            .currentContext
            ?.findRenderObject() as RenderBox?;
        if (box != null) {
          setState(() {
            _tutorialStart =
                box.localToGlobal(box.size.center(Offset.zero));
            _tutorialEnd = null;
            _showTutorial = true;
          });
        }
      }
    });
  }

  // ── Interaction ──────────────────────────────────────────────────────────────

  void _handleTap(int selected) {
    if (!mounted || hasAnswered || _timeIsUp()) return;
    if (_showTutorial) setState(() => _showTutorial = false);

    if (selected == targetCount) {
      // ── Correct ──
      setState(() {
        hasAnswered = true;
        showNextButton = true;  // ← show manual Next button
        _wrongTappedChoice = null;
        totalCorrect++;
        starsEarned++;
        countingStars++;
        correctInSubLevel++;
        _addVisibleStar();
      });
      _saveCountingStars();
      _speak("Well done!");

      if (totalCorrect % 3 == 0) _showWellDoneAnimation();

      // No automatic advance – child presses Next
    } else {
      // ── Wrong — highlight red, do NOT lock interaction ──
      _wrongAttempts++;
      setState(() => _wrongTappedChoice = selected);
      _shakeController.forward(from: 0.0);
      _speak("Try again.");

      _wrongClearTimer?.cancel();
      _wrongClearTimer =
          Timer(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _wrongTappedChoice = null);
      });

      // Auto-hint after 2 wrong attempts
      if (_wrongAttempts >= 2 && !showHint) {
        _hintAutoTimer = Timer(const Duration(milliseconds: 2400), () {
          if (mounted && !showHint && !hasAnswered) _showVisualHint();
        });
      }
    }
  }

  void _onNextPressed() {
    if (!hasAnswered || !mounted) return;
    setState(() {
      showNextButton = false;
      currentTrial++;
    });
    _advanceAfterCorrect();
  }

  void _advanceAfterCorrect() {
    if (correctInSubLevel >= trialsPerSubLevel) {
      if (currentSubLevel < subLevelsPerLevel[currentLevel - 1]) {
        setState(() {
          currentSubLevel++;
          correctInSubLevel = 0;
        });
        _saveProgress();
        _speak("Great job! Keep going.");
        _showSubLevelReward();
      } else if (currentLevel < maxLevel) {
        setState(() {
          currentLevel++;
          currentSubLevel = 1;
          correctInSubLevel = 0;
        });
        _saveProgress();
        _speak("Amazing! You reached a new level!");
        _showLevelUpReward();
      } else {
        _endSession(naturalCompletion: true);
        return;
      }
    }

    if (currentTrial >= _totalExpectedTrials || _timeIsUp()) {
      _endSession(naturalCompletion: true);
    } else {
      _generateNewTrial();
    }
  }

  // ── TTS-synced hint ──────────────────────────────────────────────────────────

  void _showVisualHint() async {
    if (showHint || !mounted) return;
    _hintRunning = true;

    setState(() {
      showHint = true;
      isCountingHint = true;
      currentHintIndex = -1;
    });

    await _speak("Let's count together.",
        timeout: const Duration(seconds: 4));

    for (int i = 0; i < targetCount; i++) {
      if (!mounted || !_hintRunning) return;
      setState(() => currentHintIndex = i);
      // Each number awaits TTS finish (with timeout) before moving to the next
      await _speak("${i + 1}", timeout: const Duration(seconds: 3));
      if (!mounted || !_hintRunning) return;
      await Future.delayed(const Duration(milliseconds: 260));
    }

    if (mounted && _hintRunning) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        setState(() => currentHintIndex = -1);
        _speak("Now you try!");
      }
    }
    _hintRunning = false;
  }

  void _addVisibleStar() {
    collectedStars
        .add(const Icon(Icons.star_rounded, color: Colors.amber, size: 32));
    if (collectedStars.length > 6) collectedStars.removeAt(0);
  }

  // ── Exit dialog ──────────────────────────────────────────────────────────────

  Future<void> _confirmExit() async {
    _tts.stop();
    final leave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(36.r)),
        child: Container(
          padding:
              EdgeInsets.symmetric(horizontal: 36.w, vertical: 32.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('😊', style: TextStyle(fontSize: 64.sp)),
              SizedBox(height: 10.h),
              Text(
                'Time to go?',
                style: GoogleFonts.fredoka(
                    fontSize: 26.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 28.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Stay
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(false),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 26.w, vertical: 18.h),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(24.r),
                        border: Border.all(
                            color: AppTheme.success, width: 3.w),
                      ),
                      child: Column(
                        children: [
                          Text('🎮',
                              style: TextStyle(fontSize: 40.sp)),
                          SizedBox(height: 6.h),
                          Text('Keep playing',
                              style: GoogleFonts.fredoka(
                                  fontSize: 15.sp,
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  // Leave
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(true),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 26.w, vertical: 18.h),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(24.r),
                        border: Border.all(
                            color: Colors.orange, width: 3.w),
                      ),
                      child: Column(
                        children: [
                          Text('🏠',
                              style: TextStyle(fontSize: 40.sp)),
                          SizedBox(height: 6.h),
                          Text('Go home',
                              style: GoogleFonts.fredoka(
                                  fontSize: 15.sp,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (leave == true && mounted) {
      _cancelAllTimers();
      Navigator.of(context).pop(); // → child dashboard
    } else if (mounted && !_hintRunning) {
      _speak("How many?");
    }
  }

  void _endSession({required bool naturalCompletion}) {
    _cancelAllTimers();
    _tts.stop();
    if (naturalCompletion) {
      _saveProgress();
      _showSessionReward();
    } else {
      Navigator.of(context).pop();
    }
  }

  // ── Reward dialogs ───────────────────────────────────────────────────────────

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
              curve: Curves.elasticOut,
            ),
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
              ]),
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

  void _showLevelUpReward() {
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
                    color: Colors.amber.withOpacity(0.35),
                    blurRadius: 28,
                    spreadRadius: 8)
              ]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events_rounded,
                  color: Colors.amber, size: 90.w),
              SizedBox(height: 16.h),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                    3,
                    (_) => Icon(Icons.star_rounded,
                        color: Colors.amber, size: 54.w)),
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

  void _showSessionReward() {
    final starCount =
        (starsEarned / _totalExpectedTrials * 3).round().clamp(0, 3);
    _speak("Amazing! You did it!");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40.r)),
        child: Container(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    3,
                    (i) => Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12.w),
                          child: Icon(
                            i < starCount
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 80.w,
                            color: i < starCount
                                ? Colors.amber
                                : Colors.grey,
                          ),
                        )),
              ),
              SizedBox(height: 24.h),
              if (widget.rewardImagePath != null && starCount >= 2)
                Image.asset(widget.rewardImagePath!, height: 120.h),
              SizedBox(height: 30.h),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onSessionComplete();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    shape: const CircleBorder(),
                    padding: EdgeInsets.all(20.w)),
                child: Icon(Icons.check_rounded,
                    size: 40.w, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Object display ───────────────────────────────────────────────────────────

  Widget _buildObjects(int count) {
    return Wrap(
      key: _objectsAreaKey,
      spacing: 28.w,
      runSpacing: 28.h,
      alignment: WrapAlignment.center,
      children: List.generate(count, (index) {
        final isHighlighted =
            isCountingHint && index == currentHintIndex;
        final isAlreadyCounted = isCountingHint &&
            currentHintIndex >= 0 &&
            index < currentHintIndex;

        final imageToUse = currentLevel == 2
            ? objectImages[index % objectImages.length]
            : (currentLevel == 1 ? objectImages[0] : objectImages[2]);

        return Container(
          key: _objectKeys.isNotEmpty && index < _objectKeys.length
              ? _objectKeys[index]
              : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedScale(
                scale: isHighlighted ? 1.4 : 1.0,
                duration: const Duration(milliseconds: 240),
                child: AnimatedOpacity(
                  opacity: isAlreadyCounted ? 0.42 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Image.asset(
                    imageToUse,
                    width: 70.w,
                    height: 70.w,
                    color: isHighlighted ? Colors.amberAccent : null,
                    colorBlendMode:
                        isHighlighted ? BlendMode.modulate : null,
                    errorBuilder: (_, __, ___) => Container(
                      width: 70.w,
                      height: 70.w,
                      color: Colors.grey[300],
                      child: Icon(Icons.image_not_supported,
                          size: 40.w),
                    ),
                  ),
                ),
              ),
              // Big number badge on the active item
              if (isHighlighted)
                Container(
                  width: 76.w,
                  height: 76.w,
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      "${index + 1}",
                      style: GoogleFonts.fredoka(
                          fontSize: 38.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ),
              // Small green tick badge on counted items
              if (isAlreadyCounted)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 26.w,
                    height: 26.w,
                    decoration: BoxDecoration(
                        color: AppTheme.success, shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        "${index + 1}",
                        style: GoogleFonts.fredoka(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  // ── Choice cards ─────────────────────────────────────────────────────────────

  Widget _buildChoiceCard(int num, int positionIndex) {
    final isCorrect = num == targetCount && hasAnswered;
    final isWrong = _wrongTappedChoice == num;

    final Color cardColor;
    final Color borderColor;
    final double borderWidth;
    final Color textColor;

    if (isCorrect) {
      cardColor = Colors.green.withOpacity(0.18);
      borderColor = Colors.green;
      borderWidth = 6.w;
      textColor = Colors.green;
    } else if (isWrong) {
      cardColor = Colors.red.withOpacity(0.13);
      borderColor = Colors.red;
      borderWidth = 6.w;
      textColor = Colors.red;
    } else {
      cardColor = Colors.white;
      borderColor = Colors.grey.shade300;
      borderWidth = 4.w;
      textColor = Theme.of(context).colorScheme.primary;
    }

    return GestureDetector(
      key: _choiceKeys[positionIndex],
      onTap: (hasAnswered || currentLevel == 3)
          ? null
          : () => _handleTap(num),
      child: AnimatedBuilder(
        animation: _shakeController,
        builder: (context, child) {
          final shakeX = isWrong
              ? sin(_shakeController.value * pi * 5) * 9.0
              : 0.0;
          return Transform.translate(
              offset: Offset(shakeX, 0), child: child);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 130.w,
          height: 150.h,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(32.r),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: isWrong
                ? [
                    BoxShadow(
                        color: Colors.red.withOpacity(0.25),
                        blurRadius: 14,
                        spreadRadius: 3)
                  ]
                : isCorrect
                    ? [
                        BoxShadow(
                            color: Colors.green.withOpacity(0.25),
                            blurRadius: 14,
                            spreadRadius: 3)
                      ]
                    : null,
          ),
          child: Center(
            child: Text(
              num.toString(),
              style: GoogleFonts.fredoka(
                  fontSize: 60.sp,
                  fontWeight: FontWeight.w700,
                  color: textColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableChoice(int num, int positionIndex) {
    return Draggable<int>(
      data: num,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 130.w,
          height: 150.h,
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32.r),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10)
              ]),
          child: Center(
              child: Text(num.toString(),
                  style: GoogleFonts.fredoka(
                      fontSize: 60.sp, fontWeight: FontWeight.bold))),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: Container(
          width: 130.w,
          height: 150.h,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32.r),
              border: Border.all(color: Colors.grey)),
        ),
      ),
      child: Container(
        key: _choiceKeys[positionIndex],
        width: 130.w,
        height: 150.h,
        decoration: BoxDecoration(
          color: hasAnswered && num == targetCount
              ? Colors.green.withOpacity(0.3)
              : Colors.white,
          borderRadius: BorderRadius.circular(32.r),
          border: Border.all(
              color: hasAnswered && num == targetCount
                  ? Colors.green
                  : Colors.orange,
              width: hasAnswered && num == targetCount ? 6 : 4),
        ),
        child: Center(
            child: Text(num.toString(),
                style: GoogleFonts.fredoka(
                    fontSize: 60.sp, fontWeight: FontWeight.bold))),
      ),
    );
  }

  Widget _buildLevel3Area() {
    return DragTarget<int>(
      key: _dropZoneKey,
      onWillAccept: (data) => !hasAnswered,
      onAccept: (data) {
        if (mounted) setState(() => _showTutorial = false);
        if (data == targetCount) {
          _handleTap(data);
        } else {
          _speak("Try again.");
        }
      },
      builder: (context, candidateData, _) => Container(
        width: double.infinity,
        height: 280.h,
        decoration: BoxDecoration(
            border: Border.all(
                color: candidateData.isNotEmpty
                    ? Colors.green
                    : Colors.grey.shade300,
                width: 4),
            borderRadius: BorderRadius.circular(30.r)),
        child: Center(child: _buildObjects(targetCount)),
      ),
    );
  }

  void _restartActivity() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.r)),
        title: Row(children: [
          const Icon(Icons.refresh_rounded, color: Colors.orange),
          SizedBox(width: 8.w),
          Text('Restart?',
              style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
        ]),
        content: const Text('Start a new session?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                currentTrial = 0;
                totalCorrect = 0;
                starsEarned = 0;
                correctInSubLevel = 0;
                collectedStars.clear();
                _tutorialShownForLevel.clear(); // tutorials replay on restart
              });
              _generateNewTrial();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange),
            child:
                const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              // ── Scrollable main content ───────────────────────────────
              SingleChildScrollView(
                child: Column(
                  children: [
                    // Top bar
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                          color: colorScheme.surface,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 4)
                          ]),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _confirmExit,
                            icon: Icon(Icons.arrow_back_rounded,
                                size: 26.w,
                                color: colorScheme.primary),
                            tooltip: 'Back',
                          ),
                          Row(children: [
                            Icon(Icons.star_rounded,
                                color: Colors.amber, size: 24.sp),
                            SizedBox(width: 4.w),
                            Text('$countingStars',
                                style: GoogleFonts.fredoka(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold)),
                          ]),
                          const Spacer(),
                          ...collectedStars.take(6),
                          const Spacer(),
                          IconButton(
                            onPressed: (showHint || _hintRunning)
                                ? null
                                : _showVisualHint,
                            icon: Icon(
                                (showHint || _hintRunning)
                                    ? Icons.lightbulb
                                    : Icons.lightbulb_outline_rounded,
                                size: 26.w,
                                color: Colors.orange),
                            tooltip: 'Hint',
                          ),
                          IconButton(
                            onPressed: _restartActivity,
                            icon: Icon(Icons.refresh_rounded,
                                size: 26.w, color: Colors.orange),
                            tooltip: 'Restart',
                          ),
                        ],
                      ),
                    ),

                    // Progress bar
                    Padding(
                      padding:
                          EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 8.h),
                      child: LinearProgressIndicator(
                        value: overallProgress,
                        backgroundColor:
                            colorScheme.surfaceContainerHighest,
                        color: colorScheme.primary,
                        minHeight: 12.h,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),

                    SizedBox(height: 16.h),

                    // Objects area
                    if (currentLevel == 3)
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 24.w),
                        child: _buildLevel3Area(),
                      )
                    else
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40.r)),
                        margin:
                            EdgeInsets.symmetric(horizontal: 24.w),
                        child: Container(
                          constraints:
                              BoxConstraints(minHeight: 220.h),
                          padding: EdgeInsets.all(20.w),
                          child: Center(
                              child: _buildObjects(targetCount)),
                        ),
                      ),

                    SizedBox(height: 28.h),

                    // Choice row
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 20.w),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceEvenly,
                        children: currentLevel == 3
                            ? choices
                                .asMap()
                                .entries
                                .map((e) => _buildDraggableChoice(
                                    e.value, e.key))
                                .toList()
                            : choices
                                .asMap()
                                .entries
                                .map((e) =>
                                    _buildChoiceCard(e.value, e.key))
                                .toList(),
                      ),
                    ),

                    // ── Next button (child‑paced) ───────────────────────────
                    if (showNextButton)
                      Padding(
                        padding: EdgeInsets.only(top: 24.h),
                        child: ElevatedButton.icon(
                          onPressed: _onNextPressed,
                          icon: Icon(Icons.arrow_forward_rounded),
                          label: Text("Next"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            padding: EdgeInsets.symmetric(
                                horizontal: 30.w, vertical: 12.h),
                          ),
                        ),
                      ),

                    SizedBox(height: 20.h),
                  ],
                ),
              ),

              // ── Finger tutorial overlay (floats above everything) ─────
              if (_showTutorial &&
                  _tutorialStart != null &&
                  !hasAnswered)
                _FingerTutorial(
                  start: _tutorialStart!,
                  end: _tutorialEnd,
                  onDone: () {
                    if (mounted) setState(() => _showTutorial = false);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}