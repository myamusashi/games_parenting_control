import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_database/firebase_database.dart';
import 'storage_service.dart';
import '../models/game_entry.dart';

/// Canonical path in Firebase RTDB where allowed games are stored.
///
/// Schema per node:
/// ```
/// /allowed_games/<packageName>
///   name:        String
///   packageName: String
///   enabled:     bool
///   addedBy:     String   (parentUid or 'local')
///   addedAt:     String   (ISO-8601)
/// ```
///
/// Why a separate path from /games?
///   /games  — the existing "game catalogue" written by the parent's
///             GamesService (AddGameScreen / StoreShareHandler).  It stores
///             GameModel objects and is shown in GamesListScreen.
///   /allowed_games — the per-family allowlist written by AppSelectionScreen
///             from either app.  HomeScreen (kids) reads from here.
///
/// Keeping them separate lets us evolve both independently without breaking
/// existing Firebase rules or data.
class GameSyncService {
  static final DatabaseReference _remoteRef = FirebaseDatabase.instance.ref(
    'allowed_games',
  );

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Add a game to BOTH local SharedPreferences AND Firebase.
  ///
  /// Call this from [AppSelectionScreen.addGame()] instead of
  /// [StorageService.saveGames()] directly.
  ///
  /// [iconBytes] is stored locally only (RTDB can't hold binary blobs).
  static Future<void> addGame({
    required String name,
    required String packageName,
    Uint8List? iconBytes,
    String addedBy = 'local',
  }) async {
    // 1. Local cache (keeps icon bytes)
    final games = await StorageService.getGames();
    if (!games.any((g) => g.packageName == packageName)) {
      games.add(
        GameEntry(name: name, packageName: packageName, iconBytes: iconBytes),
      );
      await StorageService.saveGames(games);
    }

    // 2. Firebase (package name as key — safe chars, unique per app)
    final safeKey = _safeKey(packageName);
    await _remoteRef.child(safeKey).set({
      'name': name,
      'packageName': packageName,
      'enabled': true,
      'addedBy': addedBy,
      'addedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Remove a game from BOTH local SharedPreferences AND Firebase.
  static Future<void> removeGame({required String packageName}) async {
    // Local
    final games = await StorageService.getGames();
    games.removeWhere((g) => g.packageName == packageName);
    await StorageService.saveGames(games);

    // Firebase
    final safeKey = _safeKey(packageName);
    await _remoteRef.child(safeKey).remove();
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  /// One-time fetch of the allowed game list from Firebase.
  /// Falls back to local cache if Firebase is unavailable.
  static Future<List<GameEntry>> fetchGames() async {
    try {
      final snap = await _remoteRef.get();
      if (snap.exists && snap.value != null) {
        final raw = snap.value as Map<dynamic, dynamic>;
        final remote = raw.entries
            .where((e) {
              final map = e.value as Map<dynamic, dynamic>;
              return (map['enabled'] as bool?) ?? true;
            })
            .map((e) {
              final map = e.value as Map<dynamic, dynamic>;
              return GameEntry(
                name: map['name'] as String? ?? '',
                packageName: map['packageName'] as String? ?? '',
              );
            })
            .where((g) => g.packageName.isNotEmpty)
            .toList();

        // Merge remote list into local cache (add missing entries, keep icons)
        await _mergeIntoLocal(remote);
        return await _withLocalIcons(remote);
      }
    } catch (_) {
      // Firebase unreachable — fall through to local
    }
    return StorageService.getGames();
  }

  /// Real-time stream of the allowed game list from Firebase.
  ///
  /// Each emission merges remote data with locally cached icon bytes so the
  /// kids HomeScreen stays live without a manual refresh.
  static Stream<List<GameEntry>> streamGames() {
    return _remoteRef.onValue.asyncMap((event) async {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return StorageService.getGames(); // local fallback
      }

      final raw = event.snapshot.value as Map<dynamic, dynamic>;
      final remote = raw.entries
          .where((e) {
            final map = e.value as Map<dynamic, dynamic>;
            return (map['enabled'] as bool?) ?? true;
          })
          .map((e) {
            final map = e.value as Map<dynamic, dynamic>;
            return GameEntry(
              name: map['name'] as String? ?? '',
              packageName: map['packageName'] as String? ?? '',
            );
          })
          .where((g) => g.packageName.isNotEmpty)
          .toList();

      await _mergeIntoLocal(remote);
      return _withLocalIcons(remote);
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Firebase keys cannot contain . / $ # [ ]
  /// Replace dots with underscores (com.example.app → com_example_app).
  static String _safeKey(String packageName) =>
      packageName.replaceAll('.', '_');

  /// Merge [remote] entries into local SharedPreferences so that:
  ///   • new remote entries are added locally (without icons — filled later)
  ///   • local entries not in remote are NOT removed (could be offline additions)
  static Future<void> _mergeIntoLocal(List<GameEntry> remote) async {
    final local = await StorageService.getGames();
    bool changed = false;
    for (final r in remote) {
      if (!local.any((l) => l.packageName == r.packageName)) {
        local.add(r);
        changed = true;
      }
    }
    if (changed) await StorageService.saveGames(local);
  }

  /// Return [entries] enriched with icon bytes from local cache where available.
  static Future<List<GameEntry>> _withLocalIcons(
    List<GameEntry> entries,
  ) async {
    final local = await StorageService.getGames();
    final iconMap = {for (final g in local) g.packageName: g.iconBytes};
    return entries.map((e) {
      return GameEntry(
        name: e.name,
        packageName: e.packageName,
        iconBytes: iconMap[e.packageName],
        isLocked: e.isLocked,
        totalPlayedSecondsToday: e.totalPlayedSecondsToday,
      );
    }).toList();
  }
}
