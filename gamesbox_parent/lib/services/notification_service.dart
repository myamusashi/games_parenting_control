import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gamesbox_common/gamesbox_common.dart';
import 'package:gamesbox_parent/services/child_service.dart';

// ── Top-level FCM background handler ─────────────────────────────────────────
// Must be top-level (not a class method) per firebase_messaging requirements.

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final localNotifs = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  final settings = InitializationSettings(android: androidInit);
  await localNotifs.initialize(settings: settings);
  _showLocal(
    localNotifs,
    title: message.notification?.title ?? '',
    body: message.notification?.body ?? '',
    type: message.data['type'] ?? 'info',
  );
}

void _showLocal(
  FlutterLocalNotificationsPlugin plugin, {
  required String title,
  required String body,
  required String type,
}) {
  plugin.show(id: DateTime.now().millisecondsSinceEpoch ~/ 1000);
}

// ── NotificationService ───────────────────────────────────────────────────────

/// Phase 4 — Full notification service.
///
/// Call order:
///   1. [NotificationService.init()]      — once after Firebase.initializeApp()
///   2. [NotificationService.startWatching(parentUid)] — after login
///   3. [NotificationService.stopWatching()]           — on logout
///
/// Notifications fired:
///   • 80% of daily limit  → warning push
///   • 100% (locked)       → locked push
///   • QR unlock scanned   → confirmation via [recordUnlockNotification]
///
/// Every fired notification is also logged under
/// notifications/<parentUid>/<pushKey> in RTDB for the in-app inbox.
class NotificationService {
  static final _localNotifs = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static final Map<String, _ChildWatcher> _watchers = {};

  // ── Initialisation ─────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (_initialized) return;

    // Local notification plugin
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _localNotifs.initialize(settings: settings);

    // Android notification channel (required for Android 8+)
    const channel = AndroidNotificationChannel(
      'gamesbox_parent_channel',
      'GamesBox Parent',
      description: 'Notifikasi waktu bermain anak',
      importance: Importance.high,
    );
    await _localNotifs
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // FCM
    final messaging = FirebaseMessaging.instance;

    // Request OS permission (iOS / Android 13+)
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // Background handler (must be registered before any other FCM calls)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Foreground message → show local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      if (msg.notification != null) {
        _showLocal(
          _localNotifs,
          title: msg.notification!.title ?? '',
          body: msg.notification!.body ?? '',
          type: msg.data['type'] ?? 'info',
        );
      }
    });

    // Persist FCM token for Cloud Functions targeting
    await _saveFcmToken(messaging);
    messaging.onTokenRefresh.listen((_) => _saveFcmToken(messaging));

    _initialized = true;
  }

  // ── FCM token storage ──────────────────────────────────────────────────────

  static Future<void> _saveFcmToken(FirebaseMessaging messaging) async {
    try {
      final token = await messaging.getToken();
      if (token == null) return;
      final familyId = await StorageService.getFamilyId();
      if (familyId == null || familyId.isEmpty) return;
      await FirebaseDatabase.instance
          .ref('families/$familyId/fcmToken')
          .set(token);
    } catch (_) {}
  }

  // ── Watcher management ─────────────────────────────────────────────────────

  /// Start watching every child of [parentUid] for threshold crossings.
  /// Safe to call multiple times — idempotent per child ID.
  static void startWatching(String parentUid) {
    ChildService.streamChildren(parentUid).listen((children) {
      final liveIds = children.map((c) => c.id).toSet();

      // Dispose removed children
      _watchers.keys.where((id) => !liveIds.contains(id)).toList().forEach((
        id,
      ) {
        _watchers[id]?.dispose();
        _watchers.remove(id);
      });

      // Start watchers for new children
      for (final child in children) {
        _watchers.putIfAbsent(
          child.id,
          () => _ChildWatcher(child: child, parentUid: parentUid),
        );
      }
    });
  }

  /// Stop all watchers and clear state (call on logout).
  static void stopWatching() {
    for (final w in _watchers.values) {
      w.dispose();
    }
    _watchers.clear();
  }

  // ── Internal dispatch (local push + RTDB log) ──────────────────────────────

  static Future<void> dispatch({
    required String parentUid,
    required String title,
    required String body,
    required String type,
  }) async {
    // Show local notification
    _showLocal(_localNotifs, title: title, body: body, type: type);

    // Log to RTDB in-app inbox
    try {
      await FirebaseDatabase.instance
          .ref('notifications/$parentUid')
          .push()
          .set({
            'title': title,
            'body': body,
            'type': type,
            'timestamp': DateTime.now().toIso8601String(),
            'read': false,
          });
    } catch (_) {}
  }
}

// ── Per-child watcher ─────────────────────────────────────────────────────────

class _ChildWatcher {
  final ChildModel child;
  final String parentUid;

  int _lastPlayedSeconds = 0;
  int _limitSeconds = 3600;
  bool _warned80 = false;
  bool _warnedLocked = false;

  StreamSubscription<int>? _playedSub;
  StreamSubscription<TimeLimitModel?>? _limitSub;

  _ChildWatcher({required this.child, required this.parentUid}) {
    _subscribe();
  }

  void _subscribe() {
    _playedSub = TimeLimitService.streamTodayPlayed(child.id).listen((
      secs,
    ) async {
      final prev = _lastPlayedSeconds;
      _lastPlayedSeconds = secs;

      if (_limitSeconds <= 0) return; // unlimited — no threshold to fire

      final ratio = secs / _limitSeconds;
      final prevRatio = prev / _limitSeconds;

      // 80 % warning — once per day
      if (!_warned80 && ratio >= 0.8 && prevRatio < 0.8) {
        _warned80 = true;
        await NotificationService.dispatch(
          parentUid: parentUid,
          title: '⚠️ ${child.name} hampir mencapai batas',
          body:
              '${child.name} sudah bermain ${secs ~/ 60} menit dari ${_limitSeconds ~/ 60} menit.',
          type: 'warning',
        );
      }

      // 100 % locked — once per day
      if (!_warnedLocked && secs >= _limitSeconds && prev < _limitSeconds) {
        _warnedLocked = true;
        await NotificationService.dispatch(
          parentUid: parentUid,
          title: '🔒 ${child.name} kehabisan waktu main',
          body: '${child.name} sudah mencapai batas waktu bermain hari ini.',
          type: 'locked',
        );
      }

      // Daily reset detected (seconds jumped back near zero)
      if (secs < 60 && prev > 300) {
        _warned80 = false;
        _warnedLocked = false;
      }
    });

    _limitSub = TimeLimitService.streamLimit(child.id).listen((tl) {
      if (tl == null || tl.isUnlimited) {
        _limitSeconds = 0;
      } else {
        // Re-arm warnings if limit was increased
        if (tl.dailySeconds > _limitSeconds) {
          _warned80 = false;
          _warnedLocked = false;
        }
        _limitSeconds = tl.dailySeconds;
      }
    });
  }

  void dispose() {
    _playedSub?.cancel();
    _limitSub?.cancel();
  }
}

// ── Unlock notification helper ────────────────────────────────────────────────

/// Called from the **kids app** (LockedScreen) after a successful QR unlock.
/// Writes a confirmation notification to the parent's RTDB inbox.
/// Does NOT need the parent UID — reads it from kids/<kidId>/parentId.
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

    await FirebaseDatabase.instance.ref('notifications/$parentUid').push().set({
      'title': '✅ $kidName mendapat waktu tambahan',
      'body': '$kidName menggunakan QR unlock untuk +$extraMinutes menit.',
      'type': 'unlocked',
      'timestamp': DateTime.now().toIso8601String(),
      'read': false,
    });
  } catch (_) {}
}
