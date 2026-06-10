import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:gamesbox_common/gamesbox_common.dart';

/// BUG-04 FIX (Phase 4 extended) — Periodic Firebase sync for the kids app.
///
/// Writes to:
///   kids/<kidId>/playedTodaySeconds   — live played seconds (every 30 s)
///   kids/<kidId>/lastSeen             — ISO-8601 timestamp (every 30 s)
///   kids/<kidId>/history/<YYYY-MM-DD> — daily snapshot written once at
///                                        session end / midnight rollover
///
/// Usage:
///   KidSyncService.startPeriodicSync(kidId);   // on session start
///   await KidSyncService.syncNow();            // before navigating away
///   KidSyncService.stopSync();                 // on session end
class KidSyncService {
  static Timer? _syncTimer;
  static String? _currentKidId;
  static String? _lastHistoryDate; // prevents duplicate history writes

  // ── Session control ───────────────────────────────────────────────────────

  /// Start syncing every 30 seconds for [kidId].
  /// Cancels any previous timer before starting — safe to call multiple times.
  static void startPeriodicSync(String kidId) {
    _currentKidId = kidId;
    _syncTimer?.cancel();

    // Immediate first push
    _push(kidId);

    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _push(kidId);
    });
  }

  /// Stop periodic sync (call when the game session ends).
  static void stopSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Force a one-time sync right now (call before Navigator.pop).
  static Future<void> syncNow() async {
    if (_currentKidId != null) {
      await _push(_currentKidId!, forceDailySnapshot: true);
    }
  }

  // ── Internal push ─────────────────────────────────────────────────────────

  static Future<void> _push(
    String kidId, {
    bool forceDailySnapshot = false,
  }) async {
    try {
      final seconds = await StorageService.getTotalPlayed();
      final now = DateTime.now();
      final dateKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Always update live fields
      await FirebaseDatabase.instance
          .ref('kids/$kidId/playedTodaySeconds')
          .set(seconds);
      await FirebaseDatabase.instance
          .ref('kids/$kidId/lastSeen')
          .set(now.toIso8601String());

      // Write daily history snapshot once per calendar day (or on force)
      if (forceDailySnapshot || _lastHistoryDate != dateKey) {
        _lastHistoryDate = dateKey;
        await FirebaseDatabase.instance
            .ref('kids/$kidId/history/$dateKey')
            .set(seconds);
      }
    } catch (_) {
      // Ignore sync errors — local storage is the source of truth for the
      // kids app. The next periodic push will retry automatically.
    }
  }
}
