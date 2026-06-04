import 'package:firebase_database/firebase_database.dart';
import 'package:gamesbox_common/gamesbox_common.dart';

class TimeLimitService {
  static final DatabaseReference _ref =
      FirebaseDatabase.instance.ref().child('time_limits');

  // ─── Write ──────────────────────────────────────────────────────────────

  /// Save (or overwrite) the daily limit for a child.
  static Future<void> setDailyLimit(TimeLimitModel tl) async {
    await _ref.child(tl.childId).set(tl.toMap());
  }

  /// Convenience: set limit in minutes for a child ID.
  static Future<void> setLimitMinutes(String childId, int minutes) async {
    final tl = TimeLimitModel(
      childId: childId,
      dailySeconds: minutes * 60,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _ref.child(childId).set(tl.toMap());
  }

  // ─── Read ────────────────────────────────────────────────────────────────

  /// One-time fetch of the daily limit for a child.
  static Future<TimeLimitModel?> getLimit(String childId) async {
    final snap = await _ref.child(childId).get();
    if (!snap.exists || snap.value == null) return null;
    return TimeLimitModel.fromMap(snap.value as Map<dynamic, dynamic>);
  }

  // ─── Streams ─────────────────────────────────────────────────────────────

  /// Real-time stream of the limit for a single child.
  static Stream<TimeLimitModel?> streamLimit(String childId) {
    return _ref.child(childId).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return null;
      return TimeLimitModel.fromMap(
          event.snapshot.value as Map<dynamic, dynamic>);
    });
  }

  // ─── Played time ─────────────────────────────────────────────────────────

  /// Read how many seconds the child has played today (written by kids app).
  static Future<int> getTodayPlayedSeconds(String childId) async {
    final snap =
        await FirebaseDatabase.instance.ref('kids/$childId/playedTodaySeconds').get();
    if (!snap.exists || snap.value == null) return 0;
    return (snap.value as int?) ?? 0;
  }

  /// Real-time stream of playedTodaySeconds for a child.
  static Stream<int> streamTodayPlayed(String childId) {
    return FirebaseDatabase.instance
        .ref('kids/$childId/playedTodaySeconds')
        .onValue
        .map((e) => (e.snapshot.value as int?) ?? 0);
  }
}
