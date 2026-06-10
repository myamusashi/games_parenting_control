import 'package:firebase_database/firebase_database.dart';
import 'package:gamesbox_common/gamesbox_common.dart';

class PairingServiceKid {
  final DatabaseReference _ref = FirebaseDatabase.instance.ref();

  /// Attempt to pair using otp / familyId.
  /// Returns kidId if successful, otherwise throws.
  Future<String> pairWithOtp(String otp, {String? displayName}) async {
    final snap = await _ref.child('pairing').child(otp).get();
    if (!snap.exists) throw Exception('Kode pairing tidak valid');

    final data = snap.value as Map<dynamic, dynamic>;
    if (data.containsKey('kidId')) {
      throw Exception('Kode pairing sudah digunakan');
    }

    final parentId = data['parentId'] as String?;

    // Create kid entry under /kids/<newId>
    final kidsRef = _ref.child('kids');
    final newKidRef = kidsRef.push();
    final kidData = {
      'name': displayName ?? 'Anak',
      'parentId': parentId ?? '',
      'pairedAt': DateTime.now().toIso8601String(),
      'playedTodaySeconds': 0,
      'lastSeen': DateTime.now().toIso8601String(),
    };
    await newKidRef.set(kidData);
    final kidId = newKidRef.key!;

    // Mark OTP as used
    await _ref.child('pairing').child(otp).update({
      'kidId': kidId,
      'usedAt': DateTime.now().toIso8601String(),
    });

    // Save kidId locally
    await StorageService.saveKidId(kidId);

    return kidId;
  }

  /// Update the kid's display name in Firebase after name is entered.
  Future<void> updateKidName(String kidId, String name) async {
    await _ref.child('kids').child(kidId).update({'name': name});
  }
}
