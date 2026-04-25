import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nyota/theme.dart';
import '../services/storage_service.dart';

// Activity screens
import 'shapesactivity.dart';
import 'countingmath.dart';
import 'basicmath.dart';
import 'advancemath.dart';

// ─── SharedPreferences keys ────────────────────────────────────
const _kName   = 'child_name';
const _kAge    = 'child_age';
const _kAvatar = 'child_avatar';

class ChildDashboard extends StatefulWidget {
  const ChildDashboard({super.key});

  @override
  State<ChildDashboard> createState() => _ChildDashboardState();
}

class _ChildDashboardState extends State<ChildDashboard> {
  // Profile
  String? _childName;
  String? _avatarPath;
  int _childAge = 6;

  /// True only on the very first ever launch (no cache, no Firestore doc).
  bool _needsSetup = false;

  /// True only while reading the local cache (usually < 10 ms).
  bool _isLoading = true;

  bool _isSavingProfile = false;

  // Onboarding temp state
  int _selectedAge = 6;
  String? _selectedAvatar;
  final TextEditingController _nameController = TextEditingController();

  // Activities
  Map<String, List<Map<String, dynamic>>> _activitySchedules = {};
  Map<String, String?> _rewardImages = {};
  Map<String, bool> _completedToday = {};

  final List<String> _activityNames = [
    'Shapes',
    'Counting',
    'Basic Math',
    'Advanced Math',
  ];

  // ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initDashboard();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  //  INIT — reads local cache first (fast), then syncs in background
  // ─────────────────────────────────────────────────────────────
  Future<void> _initDashboard() async {
    final prefs = await SharedPreferences.getInstance();

    final cachedName   = prefs.getString(_kName);
    final cachedAge    = prefs.getInt(_kAge);
    final cachedAvatar = prefs.getString(_kAvatar);

    if (cachedName != null && cachedAvatar != null) {
      // ✅ We have a local profile — show the dashboard immediately.
      final completedList = prefs.getStringList('completedToday') ?? [];

      setState(() {
        _childName   = cachedName;
        _childAge    = cachedAge ?? 6;
        _avatarPath  = cachedAvatar;
        _completedToday = {for (final n in completedList) n: true};
        _needsSetup  = false;
        _isLoading   = false;   // ← UI renders NOW
      });

      // Load schedules + sync Firestore in parallel, both non-blocking.
      unawaited(Future.wait([
        _loadSchedulesBackground(),
        _syncProfileFromFirestore(prefs),
      ]));
    } else {
      // No cache — need to check Firestore once.
      await _checkFirestoreProfile(prefs);
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  FIRESTORE — only called when local cache is empty
  // ─────────────────────────────────────────────────────────────
  Future<void> _checkFirestoreProfile(SharedPreferences prefs) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { _needsSetup = true; _isLoading = false; });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final name   = data['name']   as String? ?? '';
        final age    = (data['age']   as int?)   ?? 6;
        final avatar = data['avatar'] as String? ?? '';

        // Populate cache so next launch is instant.
        await _writeLocalCache(prefs, name, age, avatar);

        final completedList = prefs.getStringList('completedToday') ?? [];

        setState(() {
          _childName  = name;
          _childAge   = age;
          _avatarPath = avatar;
          _completedToday = {for (final n in completedList) n: true};
          _needsSetup = false;
          _isLoading  = false;
        });

        unawaited(_loadSchedulesBackground());
      } else {
        // No profile anywhere — show onboarding.
        setState(() { _needsSetup = true; _isLoading = false; });
      }
    } catch (e) {
      debugPrint('⚠️  Firestore profile fetch failed: $e');
      // Fall back to onboarding rather than hanging.
      setState(() { _needsSetup = true; _isLoading = false; });
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  BACKGROUND — keep local cache in sync (silent, non-blocking)
  // ─────────────────────────────────────────────────────────────
  Future<void> _syncProfileFromFirestore(SharedPreferences prefs) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists || doc.data() == null) return;
      final data = doc.data()!;

      final name   = data['name']   as String? ?? _childName ?? '';
      final age    = (data['age']   as int?)   ?? _childAge;
      final avatar = data['avatar'] as String? ?? _avatarPath ?? '';

      await _writeLocalCache(prefs, name, age, avatar);

      // Update UI only if something actually changed.
      if (mounted &&
          (name != _childName || age != _childAge || avatar != _avatarPath)) {
        setState(() {
          _childName  = name;
          _childAge   = age;
          _avatarPath = avatar;
        });
      }
    } catch (e) {
      debugPrint('ℹ️  Background Firestore sync skipped: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  SCHEDULES — always runs in the background
  // ─────────────────────────────────────────────────────────────
  Future<void> _loadSchedulesBackground() async {
    try {
      final storage = StorageService();
      // Run init + load in parallel.
      await storage.init();
      final results = await Future.wait([
        storage.loadActivitySchedules(),
        storage.loadRewardImages(),
      ]);

      final schedules = results[0] as Map<String, List<Map<String, dynamic>>>;
      final rewards   = results[1] as Map<String, String?>;

      if (mounted) {
        setState(() {
          _activitySchedules = schedules;
          _rewardImages      = rewards;
        });
      }
    } catch (e) {
      debugPrint('⚠️  Schedule load failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't load schedules: $e")),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  SAVE PROFILE — optimistic: write cache → show dashboard
  //                             → Firestore in background
  // ─────────────────────────────────────────────────────────────
  Future<void> _saveProfile(String name, int age, String avatar) async {
    setState(() => _isSavingProfile = true);

    final prefs = await SharedPreferences.getInstance();

    // 1. Write local cache immediately (synchronous feel, < 5 ms).
    await _writeLocalCache(prefs, name, age, avatar);

    // 2. Show dashboard right away — no waiting for the network.
    if (mounted) {
      setState(() {
        _childName       = name;
        _childAge        = age;
        _avatarPath      = avatar;
        _needsSetup      = false;
        _isLoading       = false;
        _isSavingProfile = false;
      });
    }

    // 3. Start background tasks in parallel.
    unawaited(Future.wait([
      _loadSchedulesBackground(),
      _pushProfileToFirestore(name, age, avatar),
    ]));
  }

  Future<void> _pushProfileToFirestore(
      String name, int age, String avatar) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'name': name, 'age': age, 'avatar': avatar},
              SetOptions(merge: true));
      debugPrint('✅ Profile synced to Firestore');
    } catch (e) {
      debugPrint('⚠️  Firestore profile save failed (will retry next launch): $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  CACHE HELPERS
  // ─────────────────────────────────────────────────────────────
  Future<void> _writeLocalCache(
      SharedPreferences prefs, String name, int age, String avatar) async {
    await Future.wait([
      prefs.setString(_kName,   name),
      prefs.setInt   (_kAge,    age),
      prefs.setString(_kAvatar, avatar),
    ]);
  }

  // ─────────────────────────────────────────────────────────────
  //  MARK COMPLETED
  // ─────────────────────────────────────────────────────────────
  Future<void> _markCompleted(String activityName) async {
    final prefs = await SharedPreferences.getInstance();
    _completedToday[activityName] = true;
    await prefs.setStringList('completedToday', _completedToday.keys.toList());
    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────────────────────
  //  START ACTIVITY
  // ─────────────────────────────────────────────────────────────
  void _startActivity(String activityName) {
    final sessions = _activitySchedules[activityName] ?? [];
    final duration  = sessions.isNotEmpty
        ? (sessions.first['duration'] as int? ?? 15)
        : 15;
    final rewardPath = _rewardImages[activityName];

    void go(Widget screen) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

    switch (activityName) {
      case 'Shapes':
        go(ShapesActivityScreen(
          sessionDuration:    duration,
          onSessionComplete:  () => _markCompleted(activityName),
          rewardImagePath:    rewardPath,
        ));
      case 'Counting':
        go(CountingActivityScreen(
          sessionDuration:    duration,
          onSessionComplete:  () => _markCompleted(activityName),
          rewardImagePath:    rewardPath,
        ));
      case 'Basic Math':
        go(BasicMathActivityScreen(
          sessionDuration:    duration,
          onSessionComplete:  () => _markCompleted(activityName),
          rewardImagePath:    rewardPath,
        ));
      case 'Advanced Math':
        go(AdvancedMathActivityScreen(
          sessionDuration:    duration,
          onSessionComplete:  () => _markCompleted(activityName),
          rewardImagePath:    rewardPath,
        ));
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("'$activityName' not implemented yet")),
        );
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  SCHEDULE HELPERS
  // ─────────────────────────────────────────────────────────────
  List<String> _getTodaysScheduledActivities() {
    final scheduled = _activityNames
        .where((n) => (_activitySchedules[n] ?? []).isNotEmpty)
        .toList();

    scheduled.sort((a, b) {
      String earliest(String name) {
        final times = (_activitySchedules[name] ?? [])
            .map((s) => s['startTime'] as String? ?? '99:99');
        return times.isEmpty
            ? '99:99'
            : times.reduce((x, y) => x.compareTo(y) < 0 ? x : y);
      }
      return earliest(a).compareTo(earliest(b));
    });

    return scheduled;
  }

  String _getTimeHint(String activityName) {
    final sessions = _activitySchedules[activityName] ?? [];
    if (sessions.isEmpty) return 'Not scheduled';
    final earliest = sessions
        .map((s) => s['startTime'] as String? ?? '??:??')
        .reduce((a, b) => a.compareTo(b) < 0 ? a : b);
    final duration = sessions.first['duration'] as int? ?? 15;
    return '$earliest • $duration min';
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Loading only lasts until SharedPreferences responds (< 10 ms usually).
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_needsSetup) return _buildOnboardingScreen();

    final scheduledActivities = _getTodaysScheduledActivities();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    backgroundImage:
                        _avatarPath != null ? AssetImage(_avatarPath!) : null,
                    child: _avatarPath == null
                        ? const Icon(Icons.person, size: 40)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    "Hi ${_childName ?? 'Friend'}!",
                    style: GoogleFonts.fredoka(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),

            // ── Activity list ────────────────────────────────────
            Expanded(
              child: scheduledActivities.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: scheduledActivities.length,
                      itemBuilder: (context, index) {
                        final name = scheduledActivities[index];
                        return _buildActivityCard(
                            name, _completedToday[name] == true);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  ONBOARDING
  // ─────────────────────────────────────────────────────────────
  Widget _buildOnboardingScreen() {
    final colorScheme = Theme.of(context).colorScheme;
    const avatarOptions = [
      'assets/images/avatar1.png', 'assets/images/avatar2.png',
      'assets/images/avatar3.png', 'assets/images/avatar4.png',
      'assets/images/avatar5.png', 'assets/images/avatar6.png',
      'assets/images/avatar7.png', 'assets/images/avatar8.png',
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Hi there! Let's get to know you",
                  style: GoogleFonts.fredoka(
                      fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Your name",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 24),
              Text("How old are you?",
                  style: GoogleFonts.fredoka(fontSize: 18)),
              Slider(
                value: _selectedAge.toDouble(),
                min: 3,
                max: 13,
                divisions: 10,
                label: _selectedAge.toString(),
                onChanged: (v) => setState(() => _selectedAge = v.round()),
              ),
              const SizedBox(height: 24),
              Text("Pick your avatar!",
                  style: GoogleFonts.fredoka(fontSize: 18)),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: avatarOptions.length,
                  itemBuilder: (context, index) {
                    final path     = avatarOptions[index];
                    final selected = _selectedAvatar == path;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedAvatar = path),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? colorScheme.primary
                                : Colors.transparent,
                            width: 4,
                          ),
                        ),
                        child: CircleAvatar(
                            radius: 40,
                            backgroundImage: AssetImage(path)),
                      ),
                    );
                  },
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSavingProfile
                      ? null
                      : () {
                          if (_nameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text("Please enter your name!")));
                            return;
                          }
                          if (_selectedAvatar == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text("Please pick an avatar!")));
                            return;
                          }
                          _saveProfile(_nameController.text.trim(),
                              _selectedAge, _selectedAvatar!);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    disabledBackgroundColor:
                        colorScheme.primary.withOpacity(0.5),
                  ),
                  child: _isSavingProfile
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                    colorScheme.onPrimary),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text("Saving...",
                                style: GoogleFonts.fredoka(
                                    fontSize: 18,
                                    color: colorScheme.onPrimary)),
                          ],
                        )
                      : Text("Let's Start!",
                          style: GoogleFonts.fredoka(
                              fontSize: 20, color: colorScheme.onPrimary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  ACTIVITY CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildActivityCard(String activityName, bool completed) {
    final colorScheme = Theme.of(context).colorScheme;
    final color       = _getActivityColor(activityName);
    final timeHint    = _getTimeHint(activityName);

    return GestureDetector(
      onTap: completed ? null : () => _startActivity(activityName),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: completed
              ? color.withOpacity(0.15)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: completed
              ? Border.all(color: AppTheme.success, width: 3)
              : null,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20)),
              child: Icon(_getActivityIcon(activityName),
                  size: 48, color: color),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(activityName,
                      style: GoogleFonts.fredoka(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: completed
                              ? AppTheme.success
                              : colorScheme.onSurface)),
                  const SizedBox(height: 4),
                  Text(timeHint,
                      style: GoogleFonts.fredoka(
                          fontSize: 15,
                          color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (completed)
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.success, size: 40),
          ],
        ),
      ),
    );
  }

  IconData _getActivityIcon(String name) {
    switch (name) {
      case 'Shapes':        return Icons.category_rounded;
      case 'Counting':      return Icons.calculate_rounded;
      case 'Basic Math':    return Icons.add_circle_rounded;
      case 'Advanced Math': return Icons.grid_view_rounded;
      default:              return Icons.star_rounded;
    }
  }

  Color _getActivityColor(String name) {
    switch (name) {
      case 'Shapes':        return const Color(0xFFFF6B6B);
      case 'Counting':      return const Color(0xFF4ECDC4);
      case 'Basic Math':    return const Color(0xFF45B7D1);
      case 'Advanced Math': return const Color(0xFF96CEB4);
      default:              return AppTheme.seedColor;
    }
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sentiment_satisfied_alt_rounded,
                size: 90,
                color: colorScheme.secondary.withOpacity(0.6)),
            const SizedBox(height: 24),
            Text("Nothing planned today",
                style: GoogleFonts.fredoka(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text("Your parent will add some fun learning soon!",
                style: GoogleFonts.fredoka(
                    fontSize: 16, color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}