import 'dart:math';
import 'package:firebase_database/firebase_database.dart';

/// BUG-06 FIX: Pairing code now uses a cryptographically random 8-character
/// alphanumeric string (instead of 6-digit numeric which had only 900k combos).
class PairingService {
  final DatabaseReference _ref = FirebaseDatabase.instance.ref();

  static const String _chars =
      'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous I/O/0/1

  /// Generate a secure 8-character alphanumeric pairing code and store it
  /// under /pairing/<code>. Returns the generated code.
  Future<String> generateOtp(String parentId) async {
    final code = _generateCode();
    final data = {
      'parentId': parentId,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _ref.child('pairing').child(code).set(data);
    return code;
  }

  /// Mark pairing code as used after kid device has paired.
  Future<void> markOtpUsed(String otp, String kidId) async {
    await _ref.child('pairing').child(otp).update({
      'kidId': kidId,
      'usedAt': DateTime.now().toIso8601String(),
    });
  }

  static String _generateCode() {
    final rng = Random.secure();
    return List.generate(8, (_) => _chars[rng.nextInt(_chars.length)]).join();
  }
}
