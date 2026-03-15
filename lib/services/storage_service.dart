import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';

/// Storage service for managing user data locally
/// Implements CRUD operations for users
class StorageService {
    static const String _rewardImagesKey = 'reward_images';
    static const String _activitySchedulesKey = 'activity_schedules';
    Map<String, String?> _rewardImagesCache = {};
    Map<String, List<Map<String, dynamic>>> _activitySchedulesCache = {};

    /// Save reward images mapping to local storage
    Future<void> saveRewardImages(Map<String, String?> rewardImages) async {
      final rewardImagesJson = jsonEncode(rewardImages);
      await _prefs.setString(_rewardImagesKey, rewardImagesJson);
      _rewardImagesCache = Map<String, String?>.from(rewardImages);
    }

    /// Load reward images mapping from local storage
    Future<Map<String, String?>> loadRewardImages() async {
      final rewardImagesJsonStr = _prefs.getString(_rewardImagesKey);
      if (rewardImagesJsonStr == null) return {};
      final decoded = jsonDecode(rewardImagesJsonStr) as Map<String, dynamic>;
      _rewardImagesCache = decoded.map((k, v) => MapEntry(k, v as String?));
      return _rewardImagesCache;
    }

    /// Save activity schedules mapping to local storage
    Future<void> saveActivitySchedules(Map<String, List<Map<String, dynamic>>> schedules) async {
      final schedulesJson = jsonEncode(schedules);
      await _prefs.setString(_activitySchedulesKey, schedulesJson);
      _activitySchedulesCache = Map<String, List<Map<String, dynamic>>>.from(schedules);
    }

    /// Load activity schedules mapping from local storage
    Future<Map<String, List<Map<String, dynamic>>>> loadActivitySchedules() async {
      final schedulesJsonStr = _prefs.getString(_activitySchedulesKey);
      if (schedulesJsonStr == null) return {
        'Shapes': [],
        'Counting': [],
        'Basic Math': [],
        'Advanced Math': [],
      };
      final decoded = jsonDecode(schedulesJsonStr) as Map<String, dynamic>;
      final result = <String, List<Map<String, dynamic>>>{};
      decoded.forEach((k, v) {
        result[k] = (v as List).map((item) => Map<String, dynamic>.from(item)).toList();
      });
      _activitySchedulesCache = result;
      return result;
    }
  static const String _usersKey = 'users';
  static const String _currentUserKey = 'current_user';
  static final StorageService _instance = StorageService._internal();

  late SharedPreferences _prefs;
  final Map<String, User> _usersCache = {};

  factory StorageService() {
    return _instance;
  }

  StorageService._internal();

  /// Initialize the storage service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadUsersFromStorage();
  }

  /// Load all users from local storage
  Future<void> _loadUsersFromStorage() async {
    final usersJson = _prefs.getStringList(_usersKey) ?? [];
    _usersCache.clear();

    for (final userJsonStr in usersJson) {
      try {
        final userJson = jsonDecode(userJsonStr) as Map<String, dynamic>;
        final user = User.fromJson(userJson);
        _usersCache[user.id] = user;
      } catch (e) {
        print('Error loading user from storage: $e');
      }
    }
  }

  /// Get a user by ID
  Future<User?> getUser(String id) async {
    return _usersCache[id];
  }

  /// Get a user by username
  Future<User?> getUserByUsername(String username) async {
    try {
      return _usersCache.values.firstWhere(
        (user) => user.username == username,
      );
    } catch (e) {
      return null;
    }
  }

  /// Create a new user
  Future<User> createUser(InsertUser insertUser) async {
    final user = User(
      id: _generateUUID(),
      username: insertUser.username,
    );

    _usersCache[user.id] = user;
    await _saveUsersToStorage();
    return user;
  }

  /// Save current logged-in user
  Future<void> saveCurrentUser(User user) async {
    await _prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
  }

  /// Get current logged-in user
  Future<User?> getCurrentUser() async {
    final userJsonStr = _prefs.getString(_currentUserKey);
    if (userJsonStr == null) return null;

    try {
      final userJson = jsonDecode(userJsonStr) as Map<String, dynamic>;
      return User.fromJson(userJson);
    } catch (e) {
      print('Error loading current user: $e');
      return null;
    }
  }

  /// Clear current user (logout)
  Future<void> clearCurrentUser() async {
    await _prefs.remove(_currentUserKey);
  }

  /// Save all users to local storage
  Future<void> _saveUsersToStorage() async {
    final usersJson = _usersCache.values
        .map((user) => jsonEncode(user.toJson()))
        .toList();
    await _prefs.setStringList(_usersKey, usersJson);
  }

  /// Generate a simple UUID-like string
  String _generateUUID() {
    return '${DateTime.now().millisecondsSinceEpoch}-${_usersCache.length}';
  }

  /// Clear all data
  Future<void> clearAll() async {
    _usersCache.clear();
    await _prefs.clear();
  }
}
