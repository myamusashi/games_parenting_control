import 'package:firebase_database/firebase_database.dart';

import '../models/allowed_game.dart';

class AllowedGamesService {
  static DatabaseReference _ref(String kidId) {
    return FirebaseDatabase.instance.ref('kids/$kidId/allowedGames');
  }

  static String _key(String packageName) {
    return packageName.replaceAll('.', '_');
  }

  static Future<void> addGame(String kidId, AllowedGame game) async {
    await _ref(kidId).child(_key(game.packageName)).set(game.toMap());
  }

  static Future<void> removeGame(String kidId, String packageName) async {
    await _ref(kidId).child(_key(packageName)).remove();
  }

  static Stream<List<AllowedGame>> streamGames(String kidId) {
    return _ref(kidId).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return [];

      final raw = event.snapshot.value;
      if (raw is! Map<dynamic, dynamic>) return [];

      return raw.values
          .whereType<Map<dynamic, dynamic>>()
          .map(AllowedGame.fromMap)
          .where((game) => game.packageName.isNotEmpty)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    });
  }

  static Future<List<AllowedGame>> getGamesOnce(String kidId) async {
    final snap = await _ref(kidId).get();
    if (!snap.exists || snap.value == null) return [];

    final raw = snap.value;
    if (raw is! Map<dynamic, dynamic>) return [];

    return raw.values
        .whereType<Map<dynamic, dynamic>>()
        .map(AllowedGame.fromMap)
        .where((game) => game.packageName.isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }
}
