import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  // ─── Secure storage instance ──────────────────────────────────────────────
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ─── Local storage keys (non-sensitive) ───────────────────────────────────
  static const String _keyIsRegistered = 'is_registered';
  static const String _keyDailyLimit = 'daily_limit';
  static const String _keyBaseDailyLimit = 'base_daily_limit';
  static const String _keyTotalPlayedSeconds = 'total_played_seconds';
  static const String _keyLastResetDate = 'last_reset_date';
  static const String _keyGamePrefix = 'game_sec_';
  static const String _keyFamilyId = 'family_id';
  static const String _keyKidId = 'kid_id';
  static const String _keyKidName = 'kid_name';
  static const String _keyUseFirebase = 'use_firebase';

  // ─── Secure storage keys (sensitive) ─────────────────────────────────────
  static const String _secKeyParentPin = 'parent_pin';
  static const String _secKeyOtpSecret = 'otp_secret';

  // ─── FAMILY ID MANAGEMENT ────────────────────────────────────────────────
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

  // ─── KID ID MANAGEMENT ───────────────────────────────────────────────────
  static Future<void> saveKidId(String kidId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyKidId, kidId);
  }

  static Future<String?> getKidId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyKidId);
  }

  // ─── KID NAME MANAGEMENT (UX-K-02) ───────────────────────────────────────
  static Future<void> saveKidName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyKidName, name);
  }

  static Future<String> getKidName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyKidName) ?? 'Anak';
  }

  // ─── OTP SECRET — now in secure storage (SEC-01) ─────────────────────────
  static Future<void> saveOtpSecret(String secret) async {
    await _secure.write(key: _secKeyOtpSecret, value: secret);
  }

  static Future<String?> getOtpSecret() async {
    try {
      return await _secure.read(key: _secKeyOtpSecret);
    } catch (_) {
      // Fallback to SharedPreferences for backward compatibility
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('otp_secret');
    }
  }

  // ─── FIREBASE SYNC FLAG ───────────────────────────────────────────────────
  static Future<void> setUseFirebase(bool use) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseFirebase, use);
  }

  static Future<bool> isFirebaseEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyUseFirebase) ?? false;
  }

  // ─── PIN MANAGEMENT — now in secure storage (SEC-02) ─────────────────────
  static Future<void> saveParentPin(String pin) async {
    await _secure.write(key: _secKeyParentPin, value: pin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsRegistered, true);
  }

  static Future<String> getParentPin() async {
    try {
      final pin = await _secure.read(key: _secKeyParentPin);
      if (pin != null) return pin;
    } catch (_) {
      // ignore
    }
    // Fallback: migrate from plain SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final legacyPin = prefs.getString('parent_pin');
    if (legacyPin != null) {
      // Migrate to secure storage
      await _secure.write(key: _secKeyParentPin, value: legacyPin);
      await prefs.remove('parent_pin');
      return legacyPin;
    }
    return '1234';
  }

  // ─── REGISTRATION STATUS ─────────────────────────────────────────────────
  static Future<bool> isRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsRegistered) ?? false;
  }

  // ─── DAILY LIMIT ─────────────────────────────────────────────────────────
  static Future<void> saveDailyLimit(int limitMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDailyLimit, limitMinutes);
  }

  static Future<int> getDailyLimit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyDailyLimit) ?? 60;
  }

  static Future<void> saveBaseDailyLimit(int limitMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBaseDailyLimit, limitMinutes);
  }

  static Future<int> getBaseDailyLimit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyBaseDailyLimit) ?? 60;
  }

  // ─── TOTAL PLAYED TIME ───────────────────────────────────────────────────
  static Future<void> saveTotalPlayed(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTotalPlayedSeconds, seconds);
  }

  static Future<int> getTotalPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    await _checkAndResetDailyIfNeeded(prefs);
    return prefs.getInt(_keyTotalPlayedSeconds) ?? 0;
  }

  // ─── GAME PLAYED TIME ────────────────────────────────────────────────────
  static Future<void> saveGamePlayed(String gameName, int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyGamePrefix + gameName, seconds);
  }

  static Future<int> getGamePlayed(String gameName) async {
    final prefs = await SharedPreferences.getInstance();
    await _checkAndResetDailyIfNeeded(prefs);
    return prefs.getInt(_keyGamePrefix + gameName) ?? 0;
  }

  // ─── RESET DAILY ─────────────────────────────────────────────────────────
  static Future<void> resetDailyData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTotalPlayedSeconds, 0);
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith(_keyGamePrefix)) {
        await prefs.setInt(key, 0);
      }
    }
    
    // Restore daily limit back to base limit on reset
    final baseLimit = await getBaseDailyLimit();
    await saveDailyLimit(baseLimit);

    await prefs.setString(_keyLastResetDate, _getCurrentDateString());
  }

  // ─── HELPER METHODS ──────────────────────────────────────────────────────
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
    return '${now.year}-${now.month}-${now.day}';
  }

  /// Clear all data (for logout/reset). Secure storage is cleared separately.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _secure.deleteAll();
  }
}
