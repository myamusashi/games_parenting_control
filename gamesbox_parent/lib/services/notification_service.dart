import 'package:firebase_database/firebase_database.dart';
import 'package:gamesbox_common/gamesbox_common.dart';
import 'package:gamesbox_parent/services/child_service.dart';
import 'package:gamesbox_parent/services/time_limit_service.dart';

/// Phase 3/4 — NotificationService.
///
/// Watches each child's playedTodaySeconds and time_limits in Firebase and
/// fires notifications at key thresholds:
///   • 80% of daily limit   → warning
///   • 100% (locked)        → locked alert
///   • Unlock QR scanned    → extra time granted confirmation
///
/// NOTE: Full FCM setup (firebase_messaging + platform manifests) is a Phase 4
/// task. This service currently uses Firebase Realtime Database listeners
/// to detect threshold crossings and records them under
/// notifications/<parentUid>/<timestamp> so they can be shown in-app.
/// Drop-in FCM integration replaces _recordNotification() in Phase 4.
class NotificationService {
  static final Map<String, _ChildWatcher> _watchers = {};

  /// Start watching all children for the given parent.
  static void startWatching(String parentUid) {
    // Stream children
    ChildService.streamChildren(parentUid).listen((children) {
      // Remove watchers for children no longer in the list
      final currentIds = children.map((c) => c.id).toSet();
      _watchers.keys.where((id) => !currentIds.contains(id)).toList().forEach((
        id,
      ) {
        _watchers[id]?.dispose();
        _watchers.remove(id);
      });
      // Add watchers for new children
      for (final child in children) {
        _watchers.putIfAbsent(
          child.id,
          () => _ChildWatcher(child: child, parentUid: parentUid),
        );
      }
    });
  }

  /// Stop all watchers (call on logout).
  static void stopWatching() {
    for (final w in _watchers.values) {
      w.dispose();
    }
    _watchers.clear();
  }

  /// Record a notification event to Firebase (in-app notification log).
  /// In Phase 4 this will also send an FCM message via Cloud Functions.
  static Future<void> _recordNotification({
    required String parentUid,
    required String title,
    required String body,
    required String type, // 'warning' | 'locked' | 'unlocked'
  }) async {
    try {
      final ref = FirebaseDatabase.instance
          .ref('notifications/$parentUid')
          .push();
      await ref.set({
        'title': title,
        'body': body,
        'type': type,
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
      });
    } catch (_) {
      // Non-critical — don't crash the app if notification logging fails
    }
  }
}

// ── Per-child watcher ────────────────────────────────────────────────────────

class _ChildWatcher {
  final ChildModel child;
  final String parentUid;

  int _lastPlayedSeconds = 0;
  int _limitSeconds = 3600; // 1 hour default
  bool _warned80 = false;
  bool _warnedLocked = false;

  dynamic _playedSub;
  dynamic _limitSub;

  _ChildWatcher({required this.child, required this.parentUid}) {
    _startListening();
  }

  void _startListening() {
    // Watch played seconds
    _playedSub = TimeLimitService.streamTodayPlayed(child.id).listen((secs) {
      final prev = _lastPlayedSeconds;
      _lastPlayedSeconds = secs;

      if (_limitSeconds <= 0) return; // unlimited

      final ratio = secs / _limitSeconds;

      // 80% warning — fire once per day per child
      if (!_warned80 && ratio >= 0.8 && prev / _limitSeconds < 0.8) {
        _warned80 = true;
        final playedMin = secs ~/ 60;
        final limitMin = _limitSeconds ~/ 60;
        NotificationService._recordNotification(
          parentUid: parentUid,
          title: '⚠️ ${child.name} hampir mencapai batas',
          body:
              '${child.name} sudah bermain $playedMin menit dari $limitMin menit.',
          type: 'warning',
        );
      }

      // 100% locked
      if (!_warnedLocked && secs >= _limitSeconds) {
        _warnedLocked = true;
        NotificationService._recordNotification(
          parentUid: parentUid,
          title: '🔒 ${child.name} kehabisan waktu main',
          body: '${child.name} sudah mencapai batas waktu hari ini.',
          type: 'locked',
        );
      }

      // Reset flags if daily data was reset (played went back to near 0)
      if (secs < 60 && prev > 60) {
        _warned80 = false;
        _warnedLocked = false;
      }
    });

    // Watch limit changes
    _limitSub = TimeLimitService.streamLimit(child.id).listen((tl) {
      if (tl == null || tl.isUnlimited) {
        _limitSeconds = 0;
      } else {
        _limitSeconds = tl.dailySeconds;
        // Reset warning flags when limit is raised
        if (tl.dailySeconds > _limitSeconds) {
          _warned80 = false;
          _warnedLocked = false;
        }
      }
    });
  }

  void dispose() {
    (_playedSub as dynamic)?.cancel();
    (_limitSub as dynamic)?.cancel();
  }
}

// ── Unlock notification helper (call from LockedScreen after scan) ───────────

/// Call this from the kids app after a successful QR unlock, passing the
/// parent's UID so they get a confirmation notification.
///
/// In practice the kids app doesn't know the parent UID at call-time but
/// it can read it from Firebase: kids/<kidId>/parentId.
Future<void> recordUnlockNotification({
  required String kidId,
  required String kidName,
  required int extraMinutes,
}) async {
  try {
    final snap = await FirebaseDatabase.instance
        .ref('kids/$kidId/parentId')
        .get();
    final parentUid = snap.value as String?;
    if (parentUid == null || parentUid.isEmpty) return;

    await NotificationService._recordNotification(
      parentUid: parentUid,
      title: '✅ ${kidName} mendapat waktu tambahan',
      body: '${kidName} menggunakan QR unlock untuk +$extraMinutes menit.',
      type: 'unlocked',
    );
  } catch (_) {
    // ignore
  }
}
