// lib/screens/child_dashboard.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nyota/theme.dart';
import '../services/storage_service.dart';

// Correct imports for your existing activity screens
import 'shapesactivity.dart';           // ShapesActivityScreen
import 'countingmath.dart'; // CountingActivityScreen
import 'basicmath.dart'; // BasicMathActivityScreen
import 'advancemath.dart'; // AdvancedMathActivityScreen

class ChildDashboard extends StatefulWidget {
  const ChildDashboard({super.key});

  @override
  State<ChildDashboard> createState() => _ChildDashboardState();
}

class _ChildDashboardState extends State<ChildDashboard> {
  String? _childName;
  String? _avatarPath;
  bool _isLoading = true;

  Map<String, List<Map<String, dynamic>>> _activitySchedules = {};
  Map<String, String?> _rewardImages = {};
  Map<String, bool> _completedToday = {};

  final List<String> _activityNames = [
    'Shapes',
    'Counting',
    'Basic Math',
    'Advanced Math',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileAndSchedule();
  }

  Future<void> _loadProfileAndSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _childName = prefs.getString('childName') ?? 'Friend';
      _avatarPath = prefs.getString('avatarPath');
    });

    final storage = StorageService();
    await storage.init();

    try {
      final schedules = await storage.loadActivitySchedules();
      final rewards = await storage.loadRewardImages();

      final completedList = prefs.getStringList('completedToday') ?? [];
      final completedMap = {for (var name in completedList) name: true};

      setState(() {
        _activitySchedules = schedules;
        _rewardImages = rewards;
        _completedToday = completedMap;
        _isLoading = false;
      });

      print("Child dashboard loaded: ${_activitySchedules.length} activities scheduled");
    } catch (e) {
      print("Error loading child data: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markCompleted(String activityName) async {
    final prefs = await SharedPreferences.getInstance();
    _completedToday[activityName] = true;
    await prefs.setStringList('completedToday', _completedToday.keys.toList());
    setState(() {});
  }

  List<String> _getTodaysScheduledActivities() {
    final scheduled = <String>[];

    for (final name in _activityNames) {
      final sessions = _activitySchedules[name] ?? [];
      if (sessions.isNotEmpty) {
        scheduled.add(name);
      }
    }

    // Sort by earliest start time
    scheduled.sort((a, b) {
      final timesA = (_activitySchedules[a] ?? [])
          .map((s) => s['startTime'] as String? ?? '99:99')
          .toList();
      final timesB = (_activitySchedules[b] ?? [])
          .map((s) => s['startTime'] as String? ?? '99:99')
          .toList();

      final earliestA = timesA.isEmpty ? '99:99' : timesA.reduce((x, y) => x.compareTo(y) < 0 ? x : y);
      final earliestB = timesB.isEmpty ? '99:99' : timesB.reduce((x, y) => x.compareTo(y) < 0 ? x : y);

      return earliestA.compareTo(earliestB);
    });

    return scheduled;
  }

  String _getTimeHint(String activityName) {
    final sessions = _activitySchedules[activityName] ?? [];
    if (sessions.isEmpty) return 'Not scheduled';

    final earliest = sessions
        .map((s) => s['startTime'] as String? ?? '??:??')
        .reduce((a, b) => a.compareTo(b) < 0 ? a : b);

    final duration = sessions.isNotEmpty ? sessions.first['duration'] as int? ?? 15 : 15;

    return '$earliest • ${duration} min';
  }

  void _startActivity(String activityName) {
    Widget screen;

    switch (activityName) {
      case 'Shapes':
        screen = ShapesActivityScreen(
          onSessionComplete: () {
            _markCompleted(activityName);
            Navigator.pop(context);
          },
          rewardImagePath: _rewardImages[activityName],
        );
        break;
      case 'Counting':
        screen = CountingActivityScreen(
          onSessionComplete: () => _markCompleted(activityName),
          rewardImagePath: _rewardImages[activityName],
        );
        break;
      case 'Basic Math':
        screen = BasicMathActivityScreen(
          onSessionComplete: () => _markCompleted(activityName),
          rewardImagePath: _rewardImages[activityName],
          sessionMode: 'mixed', // or 'addition' / 'subtraction'
        );
        break;
      case 'Advanced Math':
        screen = AdvancedMathActivityScreen(
          onSessionComplete: () => _markCompleted(activityName),
          rewardImagePath: _rewardImages[activityName],
          sessionMode: 'mixed', // or 'multiplication' / 'division'
        );
        break;
      default:
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final scheduledActivities = _getTodaysScheduledActivities();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Avatar + name header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: AppTheme.surface,
                    backgroundImage: _avatarPath != null ? FileImage(File(_avatarPath!)) : null,
                    child: _avatarPath == null
                        ? Icon(Icons.person, size: 40, color: AppTheme.textSecondary)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _childName ?? 'Friend',
                    style: GoogleFonts.fredoka(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: scheduledActivities.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: scheduledActivities.length,
                      itemBuilder: (context, index) {
                        final name = scheduledActivities[index];
                        final completed = _completedToday[name] == true;
                        return _buildActivityCard(name, completed);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(String activityName, bool completed) {
    final color = AppTheme.getActivityColor(activityName); // assuming you have this helper
    final timeHint = _getTimeHint(activityName);

    return GestureDetector(
      onTap: completed ? null : () => _startActivity(activityName),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: completed ? color.withOpacity(0.15) : AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: completed ? Border.all(color: AppTheme.success, width: 3) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _getActivityIcon(activityName),
                size: 48,
                color: color,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activityName,
                    style: GoogleFonts.fredoka(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: completed ? AppTheme.success : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeHint,
                    style: GoogleFonts.fredoka(
                      fontSize: 15,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (completed)
              Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 40),
          ],
        ),
      ),
    );
  }

  IconData _getActivityIcon(String name) {
    switch (name) {
      case 'Shapes': return Icons.category_rounded;
      case 'Counting': return Icons.calculate_rounded;
      case 'Basic Math': return Icons.add_circle_rounded;
      case 'Advanced Math': return Icons.grid_view_rounded;
      default: return Icons.star_rounded;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sentiment_satisfied_alt_rounded,
              size: 90,
              color: AppTheme.secondary.withOpacity(0.6),
            ),
            const SizedBox(height: 24),
            Text(
              "Nothing planned today",
              style: GoogleFonts.fredoka(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Your parent will add some fun learning soon!",
              style: GoogleFonts.fredoka(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}