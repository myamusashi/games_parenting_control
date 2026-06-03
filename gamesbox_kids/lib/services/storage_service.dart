import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/game_entry.dart';

class StorageService {
  static const String _keyParentPin = 'parent_pin';
  static const String _keyIsRegistered = 'is_registered';
  static const String _keyDailyLimit = 'daily_limit';
  static const String _keyTotalPlayedSeconds = 'total_played_seconds';
  static const String _keyLastResetDate = 'last_reset_date';
  static const String _keyGamePrefix = 'game_sec_';
  static const String _keyGamesList = 'allowed_games_list';

  static Future<void> saveDailyLimit(int limitMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDailyLimit, limitMinutes);
  }

  static Future<int> getDailyLimit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyDailyLimit) ?? 60;
  }

  static Future<void> saveTotalPlayed(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTotalPlayedSeconds, seconds);
  }

  static Future<bool> isRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsRegistered) ?? false;
  }

  static Future<int> getTotalPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    await _checkAndResetDailyIfNeeded(prefs);
    return prefs.getInt(_keyTotalPlayedSeconds) ?? 0;
  }

  static Future<void> saveGamePlayed(String gameName, int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyGamePrefix + gameName, seconds);
  }

  static Future<void> saveParentPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyParentPin, pin);
    await prefs.setBool(_keyIsRegistered, true);
  }

  static Future<String> getParentPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyParentPin) ?? '1234';
  }

  static Future<int> getGamePlayed(String gameName) async {
    final prefs = await SharedPreferences.getInstance();
    await _checkAndResetDailyIfNeeded(prefs);
    return prefs.getInt(_keyGamePrefix + gameName) ?? 0;
  }

  static Future<void> resetDailyData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTotalPlayedSeconds, 0);
    // Reset all games
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith(_keyGamePrefix)) {
        await prefs.setInt(key, 0);
      }
    }
    await prefs.setString(_keyLastResetDate, _getCurrentDateString());
  }

  static Future<void> _checkAndResetDailyIfNeeded(
    SharedPreferences prefs,
  ) async {
    final lastReset = prefs.getString(_keyLastResetDate);
    final today = _getCurrentDateString();

    if (lastReset != today) {
      await resetDailyData();
    }
  }

  static Future<void> saveGames(List<GameEntry> games) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(games.map((e) => e.toJson()).toList());
    await prefs.setString(_keyGamesList, encoded);
  }

  static Future<List<GameEntry>> getGames() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encoded = prefs.getString(_keyGamesList);
    if (encoded == null) return [];
    final List<dynamic> decoded = jsonDecode(encoded);
    return decoded.map((e) => GameEntry.fromJson(e)).toList();
  }

  static String _getCurrentDateString() {
    final now = DateTime.now();
    return "${now.year}-${now.month}-${now.day}";
  }
}
