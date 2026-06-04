import 'package:firebase_database/firebase_database.dart';
import 'package:gamesbox_common/gamesbox_common.dart';

/// Service to manage paired children under the parent's family.
class ChildService {
  static final DatabaseReference _kidsRef =
      FirebaseDatabase.instance.ref().child('kids');

  // ─── Streams ─────────────────────────────────────────────────────────────

  /// Stream the list of all children that belong to the given familyId (parentId).
  static Stream<List<ChildModel>> streamChildren(String parentUid) {
    return _kidsRef.orderByChild('parentId').equalTo(parentUid).onValue.map(
      (event) {
        if (!event.snapshot.exists || event.snapshot.value == null) return [];
        final raw = event.snapshot.value as Map<dynamic, dynamic>;
        return raw.entries
            .map((e) =>
                ChildModel.fromMap(e.key as String, e.value as Map<dynamic, dynamic>))
            .toList()
          ..sort((a, b) => (a.pairedAt ?? '').compareTo(b.pairedAt ?? ''));
      },
    );
  }

  // ─── Write ──────────────────────────────────────────────────────────────

  /// Manually register a child under a parent.
  /// Used when the parent has the kid's device ID and wants to link it manually.
  static Future<void> addChildManual({
    required String childId,
    required String name,
    required String parentUid,
  }) async {
    await _kidsRef.child(childId).set({
      'name': name,
      'parentId': parentUid,
      'pairedAt': DateTime.now().toIso8601String(),
      'playedTodaySeconds': 0,
    });
  }

  /// Rename an existing child.
  static Future<void> renameChild(String childId, String newName) async {
    await _kidsRef.child(childId).update({'name': newName});
  }

  /// Unlink / remove a child from this parent's list.
  static Future<void> removeChild(String childId) async {
    await _kidsRef.child(childId).remove();
  }

  // ─── Read ────────────────────────────────────────────────────────────────

  /// One-time fetch of a single child.
  static Future<ChildModel?> getChild(String childId) async {
    final snap = await _kidsRef.child(childId).get();
    if (!snap.exists || snap.value == null) return null;
    return ChildModel.fromMap(childId, snap.value as Map<dynamic, dynamic>);
  }
}
