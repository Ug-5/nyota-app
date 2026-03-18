// lib/screens/parentdashboard_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:nyota/theme.dart';
import '../services/storage_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';   // ← Added for persistent settings

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  bool _isLoading = true;
  bool _isAuthenticatedLocally = false;

  // ──────────────────────────────────────────────
  // Core dashboard state
  // ──────────────────────────────────────────────
  Map<String, List<Map<String, dynamic>>> _schedules = {
    'Shapes': [],
    'Counting': [],
    'Basic Math': [],
    'Advanced Math': [],
  };

  Map<String, String?> _rewardImages = {};

  final List<String> _activities = [
    'Shapes',
    'Counting',
    'Basic Math',
    'Advanced Math',
  ];

  bool _soundEnabled = true;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    setState(() => _isLoading = false);
    await _showPasswordPrompt();
  }

  Future<void> _showPasswordPrompt({bool isRetry = false}) async {
    final controller = TextEditingController();

    bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: Text(
            isRetry ? 'Incorrect Password' : 'Parent Verification Required',
            style: GoogleFonts.fredoka(fontWeight: FontWeight.w700, fontSize: 22.sp),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please enter your password to access the parent dashboard.\n\n'
                'This extra step helps keep your child’s settings safe.',
                style: GoogleFonts.fredoka(fontSize: 15.sp, height: 1.4),
              ),
              SizedBox(height: 20.h),
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
                  filled: true,
                  fillColor: AppTheme.surfaceVariant,
                ),
                onSubmitted: (_) => Navigator.pop(dialogContext, true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                FirebaseAuth.instance.signOut();
                Navigator.pop(dialogContext, false);
              },
              child: Text('Log out', style: GoogleFonts.fredoka(color: AppTheme.error)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
              ),
              child: Text('Unlock', style: GoogleFonts.fredoka(fontWeight: FontWeight.w600)),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
          contentPadding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 8.h),
        ),
      ),
    );

    if (confirmed != true || !mounted) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    final entered = controller.text.trim();
    if (entered.isEmpty) {
      _showPasswordPrompt(isRetry: true);
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) throw Exception('No authenticated user');

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: entered,
      );

      await user.reauthenticateWithCredential(credential);

      if (mounted) {
        setState(() => _isAuthenticatedLocally = true);
        _loadData();
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Incorrect password';
      if (e.code == 'wrong-password') msg = 'Incorrect password';
      if (e.code == 'too-many-requests') msg = 'Too many attempts. Please try again later.';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, style: GoogleFonts.fredoka()),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
        _showPasswordPrompt(isRetry: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error verifying password', style: GoogleFonts.fredoka()),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _loadData() async {
    final storage = StorageService();
    await storage.init();

    final loadedSchedules = await storage.loadActivitySchedules();
    final loadedRewards = await storage.loadRewardImages();

    // Load persistent settings
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _schedules = loadedSchedules;
      _rewardImages = loadedRewards;
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
    });
  }

  Future<void> _saveData() async {
    final storage = StorageService();
    await storage.saveActivitySchedules(_schedules);
    await storage.saveRewardImages(_rewardImages);
  }

  void _openScheduleEditor(String activity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28.r))),
      builder: (context) => _ScheduleEditorBottomSheet(
        activityName: activity,
        currentSessions: _schedules[activity] ?? [],
        onSave: (newSessions) {
          setState(() => _schedules[activity] = newSessions);
          _saveData();
        },
      ),
    );
  }

  void _pickRewardImage(String activity) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) {
      setState(() => _rewardImages[activity] = picked.path);
      _saveData();
    }
  }

  void _downloadReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Report downloaded (placeholder)'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Change Password", style: GoogleFonts.fredoka(fontWeight: FontWeight.w700, fontSize: 20.sp)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Current Password",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
              ),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "New Password",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
              ),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Confirm New Password",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: GoogleFonts.fredoka(fontSize: 16.sp)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newCtrl.text == confirmCtrl.text && newCtrl.text.length >= 6) {
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null && user.email != null) {
                    final credential = EmailAuthProvider.credential(
                      email: user.email!,
                      password: oldCtrl.text,
                    );
                    await user.reauthenticateWithCredential(credential);
                    await user.updatePassword(newCtrl.text);

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: const Text("Password updated"), backgroundColor: AppTheme.success),
                    );
                  }
                } on FirebaseAuthException catch (e) {
                  String msg = "Error updating password";
                  if (e.code == 'wrong-password') msg = "Current password is incorrect";
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: const Text("Passwords don't match or too short"), backgroundColor: AppTheme.error),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: Text("Save", style: GoogleFonts.fredoka(fontSize: 16.sp)),
          ),
        ],
      ),
    );
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || !_isAuthenticatedLocally) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text("Parent Dashboard", style: GoogleFonts.fredoka(fontWeight: FontWeight.w700, fontSize: 22.sp)),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 80.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 20.h),
                child: Text(
                  "Hi! Let's plan today's learning",
                  style: GoogleFonts.fredoka(fontSize: 24.sp, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
              ),

              Text(
                "Daily Schedule",
                style: GoogleFonts.fredoka(fontSize: 20.sp, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
              SizedBox(height: 12.h),
              ..._activities.map((act) => _buildSchedulerCard(act)),

              SizedBox(height: 40.h),

              Text(
                "Reward Settings",
                style: GoogleFonts.fredoka(fontSize: 20.sp, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
              SizedBox(height: 12.h),
              ..._activities.map((act) => _buildRewardCard(act)),

              SizedBox(height: 40.h),

              Text(
                "App Settings",
                style: GoogleFonts.fredoka(fontSize: 20.sp, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
              SizedBox(height: 12.h),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text("Sound Effects", style: GoogleFonts.fredoka(fontSize: 16.sp, fontWeight: FontWeight.w500)),
                      subtitle: Text("Play voice instructions during activities", style: GoogleFonts.fredoka(fontSize: 13.sp, color: AppTheme.textSecondary)),
                      value: _soundEnabled,
                      activeColor: AppTheme.secondary,
                      onChanged: (v) async {
                        setState(() => _soundEnabled = v);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('sound_enabled', v);
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: Text("Dark Mode", style: GoogleFonts.fredoka(fontSize: 16.sp, fontWeight: FontWeight.w500)),
                      subtitle: Text("Reduce eye strain at night", style: GoogleFonts.fredoka(fontSize: 13.sp, color: AppTheme.textSecondary)),
                      value: _isDarkMode,
                      activeColor: AppTheme.secondary,
                      onChanged: (v) async {
                        setState(() => _isDarkMode = v);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('dark_mode', v);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.lock_reset),
                      title: Text("Change Password", style: GoogleFonts.fredoka(fontSize: 16.sp, fontWeight: FontWeight.w500)),
                      onTap: _showChangePasswordDialog,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 40.h),

              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download_rounded),
                  label: Text("Download Progress Report", style: GoogleFonts.fredoka(fontSize: 16.sp)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.onPrimary,
                    padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
                  ),
                  onPressed: _downloadReport,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSchedulerCard(String activity) {
    final sessions = _schedules[activity] ?? [];
    final text = sessions.isEmpty
        ? "No sessions scheduled"
        : "${sessions.length} session${sessions.length == 1 ? '' : 's'} today";

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withOpacity(0.15),
          radius: 28.r,
          child: Icon(_getActivityIcon(activity), color: AppTheme.primary, size: 32.w),
        ),
        title: Text(activity, style: GoogleFonts.fredoka(fontSize: 18.sp, fontWeight: FontWeight.w700)),
        subtitle: Text(text, style: GoogleFonts.fredoka(fontSize: 14.sp, color: AppTheme.textSecondary)),
        trailing: IconButton(
          icon: Icon(Icons.edit_calendar_rounded, color: AppTheme.primary, size: 28.w),
          onPressed: () => _openScheduleEditor(activity),
        ),
      ),
    );
  }

  Widget _buildRewardCard(String activity) {
    final path = _rewardImages[activity];
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Container(
              width: 64.w,
              height: 64.h,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Icon(_getActivityIcon(activity), color: AppTheme.primary, size: 32.w),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(activity, style: GoogleFonts.fredoka(fontSize: 18.sp, fontWeight: FontWeight.w700)),
                  SizedBox(height: 4.h),
                  Text(
                    path == null ? "No reward set" : "Reward ready",
                    style: GoogleFonts.fredoka(
                      fontSize: 14.sp,
                      color: path == null ? AppTheme.textSecondary : AppTheme.success,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.image_rounded, size: 18.w),
              label: Text("Set", style: GoogleFonts.fredoka(fontSize: 14.sp)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              ),
              onPressed: () => _pickRewardImage(activity),
            ),
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
}

// ──────────────────────────────────────────────
// Bottom Sheet Editor
// ──────────────────────────────────────────────

class _ScheduleEditorBottomSheet extends StatefulWidget {
  final String activityName;
  final List<Map<String, dynamic>> currentSessions;
  final ValueChanged<List<Map<String, dynamic>>> onSave;

  const _ScheduleEditorBottomSheet({
    required this.activityName,
    required this.currentSessions,
    required this.onSave,
  });

  @override
  State<_ScheduleEditorBottomSheet> createState() => _ScheduleEditorBottomSheetState();
}

class _ScheduleEditorBottomSheetState extends State<_ScheduleEditorBottomSheet> {
  late List<Map<String, dynamic>> _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = List.from(widget.currentSessions);
  }

  void _addSession() {
    setState(() {
      _sessions.add({'startTime': '09:00', 'duration': 15});
    });
  }

  void _removeSession(int index) {
    setState(() => _sessions.removeAt(index));
  }

  Future<void> _pickTime(int index) async {
    final parts = _sessions[index]['startTime'].split(':');
    final initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: AppTheme.primary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _sessions[index]['startTime'] =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _changeDuration(int index, int newDuration) {
    setState(() => _sessions[index]['duration'] = newDuration);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, MediaQuery.of(context).viewInsets.bottom + 24.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Schedule ${widget.activityName}",
            style: GoogleFonts.fredoka(fontSize: 24.sp, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          SizedBox(height: 8.h),
          Text(
            "Add or change times and duration",
            style: GoogleFonts.fredoka(fontSize: 15.sp, color: AppTheme.textSecondary),
          ),
          SizedBox(height: 24.h),

          if (_sessions.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40.h),
                child: Text(
                  "No sessions yet\nTap + to add one",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fredoka(fontSize: 16.sp, color: AppTheme.textSecondary),
                ),
              ),
            )
          else
            ...List.generate(_sessions.length, (i) {
              final s = _sessions[i];
              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickTime(i),
                        borderRadius: BorderRadius.circular(16.r),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Text(
                            s['startTime'],
                            style: GoogleFonts.fredoka(fontSize: 18.sp, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    DropdownButton<int>(
                      value: s['duration'],
                      items: List.generate(12, (i) => (i + 1) * 5)
                          .map((min) => DropdownMenuItem(value: min, child: Text('$min min', style: GoogleFonts.fredoka(fontSize: 16.sp))))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) _changeDuration(i, v);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.redAccent, size: 24.w),
                      onPressed: () => _removeSession(i),
                    ),
                  ],
                ),
              );
            }),

          SizedBox(height: 24.h),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(Icons.add_rounded, size: 20.w),
                  label: Text("Add Session", style: GoogleFonts.fredoka(fontSize: 16.sp)),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    side: BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                  ),
                  onPressed: _addSession,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onSave(_sessions);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.onPrimary,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                  ),
                  child: Text("Save", style: GoogleFonts.fredoka(fontSize: 16.sp, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}