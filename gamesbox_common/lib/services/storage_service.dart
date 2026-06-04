import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/game_entry.dart';

class StorageService {
  // Local storage keys
  static const String _keyParentPin = 'parent_pin';
  static const String _keyIsRegistered = 'is_registered';
  static const String _keyDailyLimit = 'daily_limit';
  static const String _keyTotalPlayedSeconds = 'total_played_seconds';
  static const String _keyLastResetDate = 'last_reset_date';
  static const String _keyGamePrefix = 'game_sec_';
  static const String _keyGamesList = 'allowed_games_list';
  
  // Firebase sync keys
  static const String _keyFamilyId = 'family_id';
  static const String _keyOtpSecret = 'otp_secret';
  static const String _keyUseFirebase = 'use_firebase';

  // ──── FAMILY ID MANAGEMENT ────
  static Future<void> saveFamilyId(String familyId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFamilyId, familyId);
  }

  static Future<String?> getFamilyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFamilyId);
  }

  static Future<bool> hasFamilyId() async {
    final familyId = await getFamilyId();
    return familyId != null && familyId.isNotEmpty;
  }

  // ──── OTP SECRET MANAGEMENT ────
  static Future<void> saveOtpSecret(String secret) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOtpSecret, secret);
  }

  static Future<String?> getOtpSecret() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyOtpSecret);
  }

  // ──── FIREBASE SYNC FLAG ────
  static Future<void> setUseFirebase(bool use) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseFirebase, use);
  }

  static Future<bool> isFirebaseEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyUseFirebase) ?? false;
  }

  // ──── PIN MANAGEMENT (backward compatibility) ────
  static Future<void> saveParentPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyParentPin, pin);
    await prefs.setBool(_keyIsRegistered, true);
  }

  static Future<String> getParentPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyParentPin) ?? '1234';
  }

  // ──── REGISTRATION STATUS ────
  static Future<bool> isRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsRegistered) ?? false;
  }

  // ──── DAILY LIMIT ────
  static Future<void> saveDailyLimit(int limitMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDailyLimit, limitMinutes);
  }

  static Future<int> getDailyLimit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyDailyLimit) ?? 60;
  }

  // ──── TOTAL PLAYED TIME ────
  static Future<void> saveTotalPlayed(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTotalPlayedSeconds, seconds);
  }

  static Future<int> getTotalPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    await _checkAndResetDailyIfNeeded(prefs);
    return prefs.getInt(_keyTotalPlayedSeconds) ?? 0;
  }

  // ──── GAME PLAYED TIME ────
  static Future<void> saveGamePlayed(String gameName, int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyGamePrefix + gameName, seconds);
  }

  static Future<int> getGamePlayed(String gameName) async {
    final prefs = await SharedPreferences.getInstance();
    await _checkAndResetDailyIfNeeded(prefs);
    return prefs.getInt(_keyGamePrefix + gameName) ?? 0;
  }

  // ──── GAMES LIST ────
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

  // ──── RESET DAILY ────
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

  // ──── HELPER METHODS ────
  static Future<void> _checkAndResetDailyIfNeeded(
    SharedPreferences prefs,
  ) async {
    final lastReset = prefs.getString(_keyLastResetDate);
    final today = _getCurrentDateString();

    if (lastReset != today) {
      await resetDailyData();
    }
  }

  static String _getCurrentDateString() {
    final now = DateTime.now();
    return "${now.year}-${now.month}-${now.day}";
  }

  /// Clear all data (for logout/reset)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
