// lib/screens/shapes_activity.dart
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
// Shape trace tutorial
// Animates a finger emoji along the actual outline of the current shape so
// the child can see exactly how to trace it – not just a horizontal slide.
// ─────────────────────────────────────────────────────────────────────────────
class _ShapeTraceTutorial extends StatefulWidget {
  final List<Offset> path;
  final VoidCallback onDone;

  const _ShapeTraceTutorial({required this.path, required this.onDone});

  @override
  State<_ShapeTraceTutorial> createState() => _ShapeTraceTutorialState();
}

class _ShapeTraceTutorialState extends State<_ShapeTraceTutorial>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _t;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    // Ease in/out along the path for a natural-looking trace
    _t = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 8),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 82),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 10),
    ]).animate(_ctrl);

    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });

    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Linearly interpolates along the polyline path at parameter t ∈ [0,1].
  Offset _positionAt(double t) {
    final path = widget.path;
    if (path.isEmpty) return Offset.zero;
    if (path.length == 1) return path.first;
    final totalSeg = path.length - 1;
    final raw = t * totalSeg;
    final seg = raw.floor().clamp(0, totalSeg - 1);
    return Offset.lerp(path[seg], path[seg + 1], raw - seg)!;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final pos = _positionAt(_t.value);
        return Positioned(
          left: pos.dx - 24,
          top: pos.dy - 24,
          child: IgnorePointer(
            child: Opacity(
              opacity: _opacity.value.clamp(0.0, 1.0),
              child: const Text(
                '☝️',
                style: TextStyle(
                    fontSize: 48,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 8)]),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Shapes Activity
// ─────────────────────────────────────────────────────────────────────────────
class ShapesActivityScreen extends StatefulWidget {
  final VoidCallback onSessionComplete;
  final String? rewardImagePath;
  final int? maxDurationMinutes;

  const ShapesActivityScreen({
    super.key,
    required this.onSessionComplete,
    this.rewardImagePath,
    this.maxDurationMinutes,
  });

  @override
  State<ShapesActivityScreen> createState() => _ShapesActivityScreenState();
}

class _ShapesActivityScreenState extends State<ShapesActivityScreen>
    with TickerProviderStateMixin {
  // ── Configuration ──────────────────────────────────────────────────────────
  // Reduced from 4 → 2: fewer repetitions of the same target shape per sub-level
  // so the child doesn't feel overwhelmed by seeing the exact same prompt
  // multiple times in a row.
  static const int trialsPerSubLevel = 2;
  static const int maxShapeIndex = 5; // circle(0) … oval(5)
  final List<int> subLevelsPerShape = [3, 3, 3, 3, 3, 3];

  // ── Game state ─────────────────────────────────────────────────────────────
  int currentShapeIndex = 0;
  int currentSubLevel = 1;
  int correctInSubLevel = 0;
  int currentTrial = 0;
  int totalCorrect = 0;
  int starsEarned = 0;
  int lifetimeStars = 0;

  String targetShape = '';
  List<String> choices = [];
  bool hasAnswered = false;
  bool showNextButton = false;
  bool showHint = false;
  bool isTracing = false;
  bool _hintRunning = false;

  // ── Tutorial (tracing) state ───────────────────────────────────────────────
  bool _showTutorial = false;
  List<Offset>? _tutorialPath;

  // ── Shape data ─────────────────────────────────────────────────────────────
  // Each shape now has:
  //   • a unique colour for visual identity across all sub-levels
  //   • a real-life emoji + label so children see where the shape exists in the
  //     real world (circle → sun, square → window, etc.)
  // The 'description' field has been removed: it added no value for young
  // learners and created verbal clutter.
  final List<Map<String, dynamic>> shapesData = [
    {
      'name': 'circle',
      'displayName': 'Circle',
      'color': Colors.orange,
      'realLife': '🌞',
      'realLifeLabel': 'Sun',
    },
    {
      'name': 'square',
      'displayName': 'Square',
      'color': Colors.blue,
      'realLife': '🪟',
      'realLifeLabel': 'Window',
    },
    {
      'name': 'triangle',
      'displayName': 'Triangle',
      'color': Colors.red,
      'realLife': '🍕',
      'realLifeLabel': 'Pizza slice',
    },
    {
      'name': 'star',
      'displayName': 'Star',
      'color': Colors.amber,
      'realLife': '⭐',
      'realLifeLabel': 'Star',
    },
    {
      'name': 'rectangle',
      'displayName': 'Rectangle',
      'color': Colors.purple,
      'realLife': '📺',
      'realLifeLabel': 'Screen',
    },
    {
      'name': 'oval',
      'displayName': 'Oval',
      'color': Colors.teal,
      'realLife': '🥚',
      'realLifeLabel': 'Egg',
    },
  ];

  // ── Keys ───────────────────────────────────────────────────────────────────
  final List<GlobalKey> _choiceKeys =
      [GlobalKey(), GlobalKey(), GlobalKey(), GlobalKey()];
  final GlobalKey _targetAreaKey = GlobalKey();

  // ── Timers ─────────────────────────────────────────────────────────────────
  Timer? _hintTimer;
  Timer? _wrongClearTimer;

  // ── TTS ────────────────────────────────────────────────────────────────────
  late FlutterTts _tts;
  bool _ttsReady = false;
  bool _soundEnabled = true;
  Completer<void>? _ttsCompleter;

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _celebrationController;

  DateTime? sessionStartTime;
  List<Widget> collectedStars = [];
  String? _wrongTappedShape;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    sessionStartTime = DateTime.now();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

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
      await _tts.setVoice({"name": "en-US-x-tpf-local", "locale": "en-US"});
    } catch (_) {}

    if (mounted) setState(() => _ttsReady = true);
    await _loadSoundPreference();
  }

  Future<void> _loadSoundPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;
  }

  Future<void> _speak(String text,
      {Duration timeout = const Duration(seconds: 5)}) async {
    if (!mounted || !_ttsReady || !_soundEnabled) return;

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
    _hintTimer?.cancel();
    _wrongClearTimer?.cancel();
    _hintRunning = false;
    if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
      _ttsCompleter!.complete();
    }
    _celebrationController.dispose();
    _tts.stop();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> _loadPersistentData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      currentShapeIndex = prefs.getInt('shapes_shape_index') ?? 0;
      currentSubLevel = prefs.getInt('shapes_sublevel') ?? 1;
      lifetimeStars = prefs.getInt('lifetime_stars') ?? 0;
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('shapes_shape_index', currentShapeIndex);
    await prefs.setInt('shapes_sublevel', currentSubLevel);
  }

  Future<void> _saveLifetimeStars() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lifetime_stars', lifetimeStars);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool _timeIsUp() {
    if (widget.maxDurationMinutes == null || sessionStartTime == null) return false;
    return DateTime.now().difference(sessionStartTime!).inMinutes >=
        widget.maxDurationMinutes!;
  }

  int get _totalExpectedTrials =>
      subLevelsPerShape.reduce((a, b) => a + b) * trialsPerSubLevel;

  double get overallProgress {
    int completedSubLevels = 0;
    for (int i = 0; i < currentShapeIndex; i++) {
      completedSubLevels += subLevelsPerShape[i];
    }
    completedSubLevels += currentSubLevel - 1;
    final total = subLevelsPerShape.reduce((a, b) => a + b);
    return (completedSubLevels + correctInSubLevel / trialsPerSubLevel) / total;
  }

  void _cancelAllTimers() {
    _hintTimer?.cancel();
    _wrongClearTimer?.cancel();
    _hintRunning = false;
  }

  // ── Shape-path computation for tracing animation ───────────────────────────
  //
  // Returns a list of screen-space Offsets that form the outline of [shape],
  // centred at [center] with approximate radius [radius].  The finger emoji
  // is then animated along this polyline.
  static List<Offset> _computeShapePath(
      String shape, Offset center, double radius) {
    const steps = 28; // smooth enough for circles/ovals
    switch (shape) {
      case 'circle':
        // Full circle, starting at the top
        return List.generate(steps + 1, (i) {
          final a = (i / steps) * 2 * pi - pi / 2;
          return center + Offset(radius * cos(a), radius * sin(a));
        });

      case 'oval':
        // Wider than tall (matches the widget proportions 1.4 × 1.0)
        return List.generate(steps + 1, (i) {
          final a = (i / steps) * 2 * pi - pi / 2;
          return center + Offset(radius * 1.35 * cos(a), radius * sin(a));
        });

      case 'square':
        final s = radius * 0.82;
        return [
          center + Offset(-s, -s), // top-left  → start
          center + Offset(s, -s),  // top-right
          center + Offset(s, s),   // bottom-right
          center + Offset(-s, s),  // bottom-left
          center + Offset(-s, -s), // back to start (close path)
        ];

      case 'rectangle':
        final w = radius * 1.15, h = radius * 0.70;
        return [
          center + Offset(-w, -h),
          center + Offset(w, -h),
          center + Offset(w, h),
          center + Offset(-w, h),
          center + Offset(-w, -h),
        ];

      case 'triangle':
        return [
          center + Offset(0, -radius),            // apex (top centre)
          center + Offset(radius * 0.95, radius * 0.72),  // bottom-right
          center + Offset(-radius * 0.95, radius * 0.72), // bottom-left
          center + Offset(0, -radius),            // back to apex
        ];

      case 'star':
        final pts = <Offset>[];
        for (int i = 0; i < 10; i++) {
          final a = (i / 10) * 2 * pi - pi / 2;
          // Alternate between outer (odd) and inner (even) radius
          final r = i.isEven ? radius : radius * 0.42;
          pts.add(center + Offset(r * cos(a), r * sin(a)));
        }
        pts.add(pts.first); // close
        return pts;

      default:
        return [center];
    }
  }

  // ── Trial generation ───────────────────────────────────────────────────────

  void _generateNewTrial() {
    _cancelAllTimers();
    _tts.stop();
    if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
      _ttsCompleter!.complete();
      _ttsCompleter = null;
    }

    if (_timeIsUp()) {
      _endSession(naturalCompletion: true);
      return;
    }

    targetShape = shapesData[currentShapeIndex]['name'] as String;

    setState(() {
      hasAnswered = false;
      showNextButton = false;
      showHint = false;
      isTracing = (currentSubLevel == 2);
      _showTutorial = false;
      _tutorialPath = null;
      _wrongTappedShape = null;
      _generateChoices();
    });

    // Speak only the shape name – simple, single word, no description.
    final displayName =
        shapesData[currentShapeIndex]['displayName'] as String;
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _speak(displayName);
    });
  }

  void _generateChoices() {
    choices = [targetShape];
    final Set<String> used = {targetShape};

    if (currentSubLevel == 1) {
      // Errorless: only one choice so the child cannot fail on first exposure
      return;
    }

    final numDistractors = currentSubLevel >= 3 ? 3 : 1;
    for (int i = 0;
        i <= currentShapeIndex && choices.length <= numDistractors;
        i++) {
      final s = shapesData[i]['name'] as String;
      if (!used.contains(s)) {
        choices.add(s);
        used.add(s);
      }
    }
    while (choices.length <= numDistractors) {
      final s =
          shapesData[Random().nextInt(shapesData.length)]['name'] as String;
      if (!used.contains(s)) {
        choices.add(s);
        used.add(s);
      }
    }
    choices.shuffle();
  }

  // ── Hint button ────────────────────────────────────────────────────────────
  // Speaks just the shape name (no description).  In tracing mode it also
  // triggers the finger-trace animation.

  void _onHintPressed() async {
    if (_hintRunning || !_ttsReady || !mounted) return;
    final name = shapesData[currentShapeIndex]['displayName'] as String;

    if (isTracing && !hasAnswered) {
      _hintRunning = true;
      await _speak(name);
      if (mounted) _triggerTracingTutorial();
      _hintRunning = false;
      return;
    }

    _hintRunning = true;
    setState(() => showHint = true);
    await _speak(name);
    if (mounted) {
      _hintTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => showHint = false);
      });
    }
    _hintRunning = false;
  }

  // ── Tracing tutorial ───────────────────────────────────────────────────────
  // Computes the shape-specific path and starts the finger animation.

  void _triggerTracingTutorial() {
    if (_showTutorial || !mounted) return;

    final box =
        _targetAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final center = box.localToGlobal(box.size.center(Offset.zero));
    // Use ~40 % of the shorter dimension so the path fits comfortably inside
    // the target container regardless of device size.
    final radius = box.size.shortestSide * 0.40;

    final path = _computeShapePath(targetShape, center, radius);

    setState(() {
      _tutorialPath = path;
      _showTutorial = true;
    });
  }

  // ── Interaction ────────────────────────────────────────────────────────────

  void _handleTap(String selected) {
    if (!mounted || hasAnswered || _timeIsUp() || isTracing) return;
    if (_showTutorial) setState(() => _showTutorial = false);

    if (selected == targetShape) {
      setState(() {
        hasAnswered = true;
        showNextButton = true;
        totalCorrect++;
        starsEarned++;
        lifetimeStars++;
        correctInSubLevel++;
        _addVisibleStar();
      });
      _saveLifetimeStars();
      _speak("Well done!");
      if (totalCorrect % 3 == 0) _showWellDoneAnimation();
    } else {
      _wrongTappedShape = selected;
      _wrongClearTimer?.cancel();
      _wrongClearTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _wrongTappedShape = null);
      });
    }
  }

  /// Called when the child taps "I traced it!" during the tracing sub-level.
  void _handleTracingDone() {
    if (!mounted || hasAnswered) return;
    setState(() {
      hasAnswered = true;
      showNextButton = true;
      totalCorrect++;
      starsEarned++;
      lifetimeStars++;
      correctInSubLevel++;
      _addVisibleStar();
      _showTutorial = false;
    });
    _saveLifetimeStars();
    _speak("Well done!");
    if (totalCorrect % 3 == 0) _showWellDoneAnimation();
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
      if (currentSubLevel < subLevelsPerShape[currentShapeIndex]) {
        setState(() {
          currentSubLevel++;
          correctInSubLevel = 0;
        });
        _saveProgress();
        _speak("Great job!");
        _showSubLevelReward();
      } else if (currentShapeIndex < maxShapeIndex) {
        setState(() {
          currentShapeIndex++;
          currentSubLevel = 1;
          correctInSubLevel = 0;
        });
        _saveProgress();
        _speak("Amazing! New shape!");
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

  void _addVisibleStar() {
    setState(() {
      collectedStars
          .add(const Icon(Icons.star_rounded, color: Colors.amber, size: 32));
      if (collectedStars.length > 6) collectedStars.removeAt(0);
    });
  }

  // ── Exit dialog ────────────────────────────────────────────────────────────

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
              Text('Time to go?',
                  style: GoogleFonts.fredoka(
                      fontSize: 26.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 28.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _dialogButton(
                      ctx, false, '🎮', 'Keep playing', AppTheme.success),
                  _dialogButton(
                      ctx, true, '🏠', 'Go home', Colors.orange),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (leave == true && mounted) {
      _cancelAllTimers();
      Navigator.of(context).pop();
    }
  }

  Widget _dialogButton(BuildContext ctx, bool value, String emoji,
      String label, Color color) {
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
              });
              _generateNewTrial();
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ── Reward dialogs ─────────────────────────────────────────────────────────

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
            ],
          ),
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
        (starsEarned / max(1, _totalExpectedTrials) * 3).round().clamp(0, 3);
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
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Icon(
                      i < starCount
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 80.w,
                      color: i < starCount ? Colors.amber : Colors.grey,
                    ),
                  ),
                ),
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

  // ── Shape widget builder ───────────────────────────────────────────────────

  Widget _buildShapeWidget(String shape, double size,
      {bool isTarget = false}) {
    // Each shape has its own colour; choice cards use the primary theme colour
    final data = shapesData.firstWhere((s) => s['name'] == shape,
        orElse: () => shapesData.first);
    final color = isTarget
        ? (data['color'] as Color)
        : Theme.of(context).colorScheme.primary;

    switch (shape) {
      case 'circle':
        return Container(
            width: size,
            height: size,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: color));
      case 'square':
        return Container(width: size, height: size, color: color);
      case 'triangle':
        return CustomPaint(
            size: Size(size, size),
            painter: _TrianglePainter(color: color));
      case 'star':
        return Icon(Icons.star_rounded, size: size, color: color);
      case 'rectangle':
        return Container(width: size * 1.4, height: size, color: color);
      case 'oval':
        return Container(
          width: size * 1.4,
          height: size,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size / 2),
              color: color),
        );
      default:
        return Icon(Icons.help, size: size);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shapeInfo = shapesData[currentShapeIndex];
    final shapeColor = shapeInfo['color'] as Color;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    // ── Top bar ─────────────────────────────────────────────
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
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
                                size: 26.w, color: colorScheme.primary),
                          ),
                          Row(children: [
                            Icon(Icons.star_rounded,
                                color: Colors.amber, size: 24.sp),
                            SizedBox(width: 4.w),
                            Text('$lifetimeStars',
                                style: GoogleFonts.fredoka(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold)),
                          ]),
                          const Spacer(),
                          ...collectedStars.take(6),
                          const Spacer(),
                          IconButton(
                            onPressed: (_hintRunning || showHint)
                                ? null
                                : _onHintPressed,
                            icon: Icon(
                              (showHint || _hintRunning)
                                  ? Icons.lightbulb
                                  : Icons.lightbulb_outline_rounded,
                              size: 26.w,
                              color: Colors.orange,
                            ),
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

                    // ── Progress bar (colour matches current shape) ─────────
                    Padding(
                      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 8.h),
                      child: LinearProgressIndicator(
                        value: overallProgress,
                        backgroundColor:
                            colorScheme.surfaceContainerHighest,
                        color: shapeColor,
                        minHeight: 12.h,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // ── Target area + real-life association ─────────────────
                    // Side-by-side layout (works well in landscape):
                    //   LEFT  → geometric shape inside a rounded card
                    //   RIGHT → large real-life emoji + label
                    // This gives children a concrete anchor
                    // (e.g. "circle = sun") without any verbal description.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Geometric shape card
                        Column(
                          children: [
                            Container(
                              key: _targetAreaKey,
                              width: 220.w,
                              height: 220.h,
                              decoration: BoxDecoration(
                                color: showHint
                                    ? Colors.amber.withOpacity(0.15)
                                    : shapeColor.withOpacity(0.08),
                                borderRadius:
                                    BorderRadius.circular(44.r),
                                border: Border.all(
                                  color: showHint
                                      ? Colors.amber
                                      : shapeColor.withOpacity(0.6),
                                  width: showHint ? 10.w : 8.w,
                                ),
                              ),
                              child: Center(
                                child: _buildShapeWidget(
                                    targetShape, 138.w,
                                    isTarget: true),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            // Shape name – large, friendly, colour-coded
                            Text(
                              shapeInfo['displayName'] as String,
                              style: GoogleFonts.fredoka(
                                fontSize: 22.sp,
                                fontWeight: FontWeight.bold,
                                color: shapeColor,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(width: 36.w),

                        // Real-life emoji column
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              shapeInfo['realLife'] as String,
                              style: TextStyle(fontSize: 76.sp),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              shapeInfo['realLifeLabel'] as String,
                              style: GoogleFonts.fredoka(
                                fontSize: 15.sp,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // ── Tracing sub-level UI ────────────────────────────────
                    if (isTracing) ...[
                      SizedBox(height: 20.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.touch_app_rounded,
                              color: shapeColor, size: 28.w),
                          SizedBox(width: 8.w),
                          Text(
                            'Trace the shape with your finger!',
                            style: GoogleFonts.fredoka(
                                fontSize: 19.sp, color: shapeColor),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      if (!hasAnswered)
                        ElevatedButton.icon(
                          onPressed: _handleTracingDone,
                          icon: const Icon(
                              Icons.check_circle_outline_rounded),
                          label: Text('I traced it!',
                              style: GoogleFonts.fredoka(fontSize: 18.sp)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: shapeColor,
                            padding: EdgeInsets.symmetric(
                                horizontal: 28.w, vertical: 14.h),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(24.r)),
                          ),
                        ),
                    ],

                    SizedBox(height: 24.h),

                    // ── Choice cards (matching sub-levels) ──────────────────
                    if (!isTracing)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Wrap(
                          spacing: 20.w,
                          runSpacing: 20.h,
                          alignment: WrapAlignment.center,
                          children:
                              choices.asMap().entries.map((e) {
                            final idx = e.key;
                            final shape = e.value;
                            final isCorrect =
                                shape == targetShape && hasAnswered;
                            final isWrong = _wrongTappedShape == shape;

                            return GestureDetector(
                              key: _choiceKeys[idx],
                              onTap: hasAnswered
                                  ? null
                                  : () => _handleTap(shape),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 250),
                                width: 130.w,
                                height: 140.h,
                                decoration: BoxDecoration(
                                  color: isCorrect
                                      ? Colors.green.withOpacity(0.18)
                                      : isWrong
                                          ? Colors.red.withOpacity(0.13)
                                          : Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(36.r),
                                  border: Border.all(
                                    color: isCorrect
                                        ? Colors.green
                                        : isWrong
                                            ? Colors.red
                                            : Colors.grey.shade300,
                                    width: isCorrect || isWrong
                                        ? 6.w
                                        : 4.w,
                                  ),
                                  boxShadow: isWrong
                                      ? [
                                          BoxShadow(
                                              color: Colors.red
                                                  .withOpacity(0.25),
                                              blurRadius: 14,
                                              spreadRadius: 3)
                                        ]
                                      : isCorrect
                                          ? [
                                              BoxShadow(
                                                  color: Colors.green
                                                      .withOpacity(0.25),
                                                  blurRadius: 14,
                                                  spreadRadius: 3)
                                            ]
                                          : null,
                                ),
                                child: Center(
                                    child:
                                        _buildShapeWidget(shape, 85.w)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                    SizedBox(height: 20.h),
                    if (showNextButton)
                      ElevatedButton.icon(
                        onPressed: _onNextPressed,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text('Next',
                            style: GoogleFonts.fredoka(fontSize: 18.sp)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          padding: EdgeInsets.symmetric(
                              horizontal: 30.w, vertical: 12.h),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24.r)),
                        ),
                      ),
                    SizedBox(height: 24.h),
                  ],
                ),
              ),

              // ── Tracing tutorial overlay ────────────────────────────────
              if (_showTutorial &&
                  _tutorialPath != null &&
                  !hasAnswered)
                _ShapeTraceTutorial(
                  path: _tutorialPath!,
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

// ── Triangle painter ────────────────────────────────────────────────────────
class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}