import 'dart:math';
import 'package:firebase_database/firebase_database.dart';

class PairingService {
  final DatabaseReference _ref = FirebaseDatabase.instance.ref();

  /// Generate a 6-digit OTP and store under /pairing/<otp>
  Future<String> generateOtp(String parentId) async {
    final otp = (Random().nextInt(900000) + 100000).toString();
    final data = {
      'parentId': parentId,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _ref.child('pairing').child(otp).set(data);
    return otp;
  }

  /// Register pairing from kid side should delete or mark otp used
  Future<void> markOtpUsed(String otp, String kidId) async {
    await _ref.child('pairing').child(otp).update({'kidId': kidId, 'usedAt': DateTime.now().toIso8601String()});
  }
}
