import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:gamesbox_common/gamesbox_common.dart';

/// BUG-04 FIX: Periodically syncs kids play time to Firebase so the parent
/// app always has up-to-date data, even if the kids app is force-closed.
class KidSyncService {
  static Timer? _syncTimer;
  static String? _currentKidId;

  /// Start syncing every 30 seconds for the given [kidId].
  /// Safe to call multiple times — cancels any previous timer.
  static void startPeriodicSync(String kidId) {
    _currentKidId = kidId;
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _pushPlayedSeconds(kidId);
    });
    // Push immediately on start
    _pushPlayedSeconds(kidId);
  }

  /// Stop syncing (call when session ends or app pauses).
  static void stopSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Force a one-time sync now (e.g. at session end).
  static Future<void> syncNow() async {
    if (_currentKidId != null) {
      await _pushPlayedSeconds(_currentKidId!);
    }
  }

  static Future<void> _pushPlayedSeconds(String kidId) async {
    try {
      final seconds = await StorageService.getTotalPlayed();
      await FirebaseDatabase.instance
          .ref('kids/$kidId/playedTodaySeconds')
          .set(seconds);
      await FirebaseDatabase.instance
          .ref('kids/$kidId/lastSeen')
          .set(DateTime.now().toIso8601String());
    } catch (_) {
      // Ignore sync errors — local data is source of truth for kids
    }
  }
}
