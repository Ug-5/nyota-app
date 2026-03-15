// lib/screens/parentdashboard_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:nyota/theme.dart';
import '../services/storage_service.dart';
import '../services/pin.dart';  // ← Make sure this file exists (see below)

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  bool _isLoading = true;

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

    // Check if PIN is already set
    final hasPin = await PinService.hasPin();

    if (!hasPin) {
      // First time: let parent set PIN
      await _setPinDialog();
    } else {
      // Ask for PIN
      await _verifyPinDialog();
    }
  }

  Future<void> _setPinDialog() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text("Set Your Parent PIN", style: GoogleFonts.fredoka(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Choose a 4–6 digit PIN. You'll need it every time you open the parent dashboard.",
              style: GoogleFonts.fredoka(fontSize: 15),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Your PIN',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: AppTheme.surfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Later", style: GoogleFonts.fredoka()),
          ),
          ElevatedButton(
            onPressed: () async {
              final pin = controller.text.trim();
              if (pin.length >= 4 && pin.length <= 6 && int.tryParse(pin) != null) {
                await PinService.setPin(pin);
                if (mounted) {
                  setState(() {}); // refresh UI
                  _loadData();
                }
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("PIN must be 4–6 digits")),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: Text("Save PIN", style: GoogleFonts.fredoka()),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  Future<void> _verifyPinDialog({bool isRetry = false}) async {
    final controller = TextEditingController();

    final isValid = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(isRetry ? 'Incorrect PIN – Try Again' : 'Enter Parent PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Enter your 4–6 digit PIN to access parent settings.",
              style: GoogleFonts.fredoka(fontSize: 15),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'PIN',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: AppTheme.surfaceVariant,
                errorText: isRetry ? 'Incorrect PIN' : null,
              ),
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
            onPressed: () async {
              final entered = controller.text.trim();
              final valid = await PinService.verifyPin(entered);
              Navigator.pop(dialogContext, valid);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: Text('Unlock', style: GoogleFonts.fredoka()),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );

    if (isValid == true && mounted) {
      await _loadData();
    } else if (isValid == false && mounted) {
      _verifyPinDialog(isRetry: true);
    }
  }

  Future<void> _loadData() async {
    final storage = StorageService();
    await storage.init();

    final loadedSchedules = await storage.loadActivitySchedules();
    final loadedRewards = await storage.loadRewardImages();

    if (!mounted) return;

    setState(() {
      _schedules = loadedSchedules;
      _rewardImages = loadedRewards;
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text("Parent Dashboard", style: GoogleFonts.fredoka(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                "Hi! Let's plan today's learning",
                style: GoogleFonts.fredoka(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
            ),

            Text(
              "Daily Schedule",
              style: GoogleFonts.fredoka(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            ..._activities.map((act) => _buildSchedulerCard(act)),

            const SizedBox(height: 40),

            Text(
              "Reward Settings",
              style: GoogleFonts.fredoka(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            ..._activities.map((act) => _buildRewardCard(act)),

            const SizedBox(height: 40),

            Text(
              "App Settings",
              style: GoogleFonts.fredoka(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text("Sound Effects", style: GoogleFonts.fredoka(fontSize: 16, fontWeight: FontWeight.w500)),
                    subtitle: Text("Play sounds during activities", style: GoogleFonts.fredoka(fontSize: 13, color: AppTheme.textSecondary)),
                    value: _soundEnabled,
                    activeColor: AppTheme.secondary,
                    onChanged: (v) => setState(() => _soundEnabled = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: Text("Dark Mode", style: GoogleFonts.fredoka(fontSize: 16, fontWeight: FontWeight.w500)),
                    subtitle: Text("Reduce eye strain at night", style: GoogleFonts.fredoka(fontSize: 13, color: AppTheme.textSecondary)),
                    value: _isDarkMode,
                    activeColor: AppTheme.secondary,
                    onChanged: (v) => setState(() => _isDarkMode = v),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_reset),
                    title: Text("Change Password", style: GoogleFonts.fredoka(fontSize: 16, fontWeight: FontWeight.w500)),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: const Text('Change password coming soon')),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download_rounded),
                label: Text("Download Progress Report", style: GoogleFonts.fredoka(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: _downloadReport,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulerCard(String activity) {
    final sessions = _schedules[activity] ?? [];
    final text = sessions.isEmpty ? "No sessions scheduled" : "${sessions.length} session${sessions.length == 1 ? '' : 's'} today";

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withOpacity(0.15),
          radius: 28,
          child: Icon(_getActivityIcon(activity), color: AppTheme.primary, size: 32),
        ),
        title: Text(activity, style: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.w700)),
        subtitle: Text(text, style: GoogleFonts.fredoka(fontSize: 14, color: AppTheme.textSecondary)),
        trailing: IconButton(
          icon: const Icon(Icons.edit_calendar_rounded, color: AppTheme.primary),
          onPressed: () => _openScheduleEditor(activity),
        ),
      ),
    );
  }

  Widget _buildRewardCard(String activity) {
    final path = _rewardImages[activity];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(_getActivityIcon(activity), color: AppTheme.primary, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(activity, style: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    path == null ? "No reward set" : "Reward ready",
                    style: GoogleFonts.fredoka(fontSize: 14, color: path == null ? AppTheme.textSecondary : AppTheme.success),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.image_rounded, size: 18),
              label: Text("Set", style: GoogleFonts.fredoka(fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

// Bottom Sheet Editor (unchanged)
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
        _sessions[index]['startTime'] = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _changeDuration(int index, int newDuration) {
    setState(() => _sessions[index]['duration'] = newDuration);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Schedule ${widget.activityName}",
            style: GoogleFonts.fredoka(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            "Add or change times and duration",
            style: GoogleFonts.fredoka(fontSize: 15, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),

          if (_sessions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  "No sessions yet\nTap + to add one",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fredoka(fontSize: 16, color: AppTheme.textSecondary),
                ),
              ),
            )
          else
            ...List.generate(_sessions.length, (i) {
              final session = _sessions[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickTime(i),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            session['startTime'],
                            style: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: session['duration'],
                      items: List.generate(12, (i) => (i + 1) * 5)
                          .map((min) => DropdownMenuItem(value: min, child: Text('$min min', style: GoogleFonts.fredoka())))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) _changeDuration(i, v);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _removeSession(i),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: Text("Add Session", style: GoogleFonts.fredoka()),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: _addSession,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onSave(_sessions);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text("Save", style: GoogleFonts.fredoka(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}