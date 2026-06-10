import 'dart:math';
import 'package:crypto/crypto.dart';

/// TOTP (Time-based One-Time Password) implementation.
/// Generates 6-digit codes that change every 30 seconds.
class OtpService {
  static const int _codeLength = 6;
  static const int _timeStep = 30;
  static const int _digits = 1000000; // 10^6

  /// Generate a 6-digit TOTP code based on the secret.
  static String generateCode(String secret) {
    try {
      final secretBytes = _base32Decode(secret);
      final counter = _getCurrentCounter();
      final hmac = _generateHmac(secretBytes, counter);
      final code = _dynamicTruncate(hmac);
      return code.toString().padLeft(_codeLength, '0');
    } catch (e) {
      return '000000';
    }
  }

  /// Verify if the input code matches the current valid code (±1 window).
  static bool verifyCode(String secret, String inputCode) {
    try {
      if (generateCode(secret) == inputCode) return true;
      final secretBytes = _base32Decode(secret);

      for (final offset in [-1, 1]) {
        final counter = _getCurrentCounter() + offset;
        final hmac = _generateHmac(secretBytes, counter);
        final code = _dynamicTruncate(
          hmac,
        ).toString().padLeft(_codeLength, '0');
        if (code == inputCode) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Returns remaining seconds before the current code expires (0–30).
  static int secondsRemaining() {
    final elapsed = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return _timeStep - (elapsed % _timeStep);
  }

  static int _getCurrentCounter() {
    return (DateTime.now().millisecondsSinceEpoch ~/ 1000) ~/ _timeStep;
  }

  static List<int> _generateHmac(List<int> secretBytes, int counter) {
    final counterBytes = _intToBytes(counter);
    return Hmac(sha1, secretBytes).convert(counterBytes).bytes;
  }

  static int _dynamicTruncate(List<int> hmac) {
    final offset = hmac[hmac.length - 1] & 0x0f;
    final code =
        ((hmac[offset] & 0x7f) << 24) |
        ((hmac[offset + 1] & 0xff) << 16) |
        ((hmac[offset + 2] & 0xff) << 8) |
        (hmac[offset + 3] & 0xff);
    return code % _digits;
  }

  static List<int> _intToBytes(int value) => [
    (value >> 56) & 0xff,
    (value >> 48) & 0xff,
    (value >> 40) & 0xff,
    (value >> 32) & 0xff,
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff,
  ];

  static List<int> _base32Decode(String input) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final output = <int>[];
    int bits = 0;
    int value = 0;
    for (final char in input.toUpperCase().split('')) {
      if (char == '=') break;
      final index = alphabet.indexOf(char);
      if (index < 0) throw FormatException('Invalid base32 character: $char');
      value = (value << 5) | index;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        output.add((value >> bits) & 0xff);
      }
    }
    return output;
  }

  /// BUG-05 FIX: Generate a cryptographically secure 16-byte base32 secret.
  /// Uses [Random.secure()] instead of DateTime seed.
  static String generateSecret() {
    final rng = Random.secure();
    final buffer = List<int>.generate(16, (_) => rng.nextInt(256));
    return _base32Encode(buffer);
  }

  static String _base32Encode(List<int> bytes) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final output = StringBuffer();
    int bits = 0;
    int value = 0;
    for (final byte in bytes) {
      value = (value << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        output.write(alphabet[(value >> bits) & 31]);
      }
    }
    if (bits > 0) output.write(alphabet[(value << (5 - bits)) & 31]);
    while (output.length % 8 != 0) output.write('=');
    return output.toString();
  }
}
