import 'package:firebase_database/firebase_database.dart';

class PairingServiceKid {
  final DatabaseReference _ref = FirebaseDatabase.instance.ref();

  /// Attempt to pair using otp. Returns kidId if successful, otherwise throws.
  Future<String> pairWithOtp(String otp, {String? displayName}) async {
    final snap = await _ref.child('pairing').child(otp).get();
    if (!snap.exists) throw Exception('Invalid pairing code');
    final data = snap.value as Map<dynamic, dynamic>;
    if (data.containsKey('kidId')) throw Exception('Pairing code already used');

    // Create kid entry
    final kidsRef = _ref.child('kids');
    final newKidRef = kidsRef.push();
    final kidData = {
      'name': displayName ?? 'Kid Device',
      'pairedAt': DateTime.now().toIso8601String(),
    };
    await newKidRef.set(kidData);
    final kidId = newKidRef.key!;

    // Mark OTP as used and link to kidId
    await _ref.child('pairing').child(otp).update({'kidId': kidId, 'usedAt': DateTime.now().toIso8601String()});

    return kidId;
  }
}
