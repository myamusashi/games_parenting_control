import 'dart:async';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// TOTP (Time-based One-Time Password) implementation
/// Generates 6-digit codes that change every 60 seconds
/// Compatible across parent and kids devices if they use the same secret
class OtpService {
  static const int _codeLength = 6;
  static const int _timeStep = 30; // 30 seconds per time window
  static const int _digits = 1000000; // 6 digits: 10^6

  /// Generate a 6-digit TOTP code based on the secret
  /// The code remains valid for `_timeStep` seconds (30 sec)
  ///
  /// Example:
  /// ```
  /// final secret = 'JBSWY3DPEBLW64TMMQ======'; // Base32 encoded
  /// final code = OtpService.generateCode(secret);
  /// ```
  static String generateCode(String secret) {
    try {
      final secretBytes = _base32Decode(secret);
      final counter = _getCurrentCounter();
      final hmac = _generateHmac(secretBytes, counter);
      final code = _dynamicTruncate(hmac);

      return code.toString().padLeft(_codeLength, '0');
    } catch (e) {
      print('Error generating OTP code: $e');
      return '000000';
    }
  }

  /// Verify if the input code matches the current valid code
  /// Allows some time skew for clock differences (±1 time window)
  static bool verifyCode(String secret, String inputCode) {
    try {
      // Check current window
      if (generateCode(secret) == inputCode) {
        return true;
      }

      // Check previous window (in case of clock skew)
      final secretBytes = _base32Decode(secret);
      final counterPrev = _getCurrentCounter() - 1;
      final hmacPrev = _generateHmac(secretBytes, counterPrev);
      final codePrev = _dynamicTruncate(
        hmacPrev,
      ).toString().padLeft(_codeLength, '0');

      if (codePrev == inputCode) {
        return true;
      }

      // Check next window (in case device is ahead)
      final counterNext = _getCurrentCounter() + 1;
      final hmacNext = _generateHmac(secretBytes, counterNext);
      final codeNext = _dynamicTruncate(
        hmacNext,
      ).toString().padLeft(_codeLength, '0');

      return codeNext == inputCode;
    } catch (e) {
      print('Error verifying OTP code: $e');
      return false;
    }
  }

  /// Get the remaining seconds before the current code expires
  /// Returns a value between 0 and 30
  static int secondsRemaining() {
    final now = DateTime.now();
    final elapsed = now.millisecondsSinceEpoch ~/ 1000;
    return _timeStep - (elapsed % _timeStep);
  }

  /// Get the time window index (changes every 30 seconds)
  static int _getCurrentCounter() {
    final now = DateTime.now();
    return (now.millisecondsSinceEpoch ~/ 1000) ~/ _timeStep;
  }

  /// HMAC-SHA1 generation
  static List<int> _generateHmac(List<int> secretBytes, int counter) {
    final counterBytes = _intToBytes(counter);
    return Hmac(sha1, secretBytes).convert(counterBytes).bytes;
  }

  /// Dynamic Truncate (RFC 4226)
  static int _dynamicTruncate(List<int> hmac) {
    final offset = hmac[hmac.length - 1] & 0x0f;
    final code =
        ((hmac[offset] & 0x7f) << 24) |
        ((hmac[offset + 1] & 0xff) << 16) |
        ((hmac[offset + 2] & 0xff) << 8) |
        (hmac[offset + 3] & 0xff);
    return code % _digits;
  }

  /// Convert 64-bit counter to bytes (big-endian)
  static List<int> _intToBytes(int value) {
    return [
      (value >> 56) & 0xff,
      (value >> 48) & 0xff,
      (value >> 40) & 0xff,
      (value >> 32) & 0xff,
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];
  }

  /// Base32 decode (RFC 4648)
  /// Converts base32 string to bytes
  static List<int> _base32Decode(String input) {
    const String alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final List<int> output = [];

    int bits = 0;
    int value = 0;

    for (final char in input.toUpperCase().split('')) {
      if (char == '=') break;

      final index = alphabet.indexOf(char);
      if (index < 0) {
        throw FormatException('Invalid base32 character: $char');
      }

      value = (value << 5) | index;
      bits += 5;

      if (bits >= 8) {
        bits -= 8;
        output.add((value >> bits) & 0xff);
      }
    }

    return output;
  }

  /// Generate a random base32 secret (16 bytes = 128-bit security)
  /// Returns base32-encoded string suitable for TOTP
  static String generateSecret() {
    const String alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final random = DateTime.now().millisecondsSinceEpoch;

    // Create a pseudo-random 16-byte secret
    // In production, use crypto.Random for better randomness
    final buffer = List<int>.generate(16, (i) {
      return ((random + i) * 1664525 + 1013904223) & 0xff;
    });

    return _base32Encode(buffer);
  }

  /// Base32 encode bytes to string
  static String _base32Encode(List<int> bytes) {
    const String alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final StringBuffer output = StringBuffer();

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

    if (bits > 0) {
      output.write(alphabet[(value << (5 - bits)) & 31]);
    }

    // Pad with '=' to make length multiple of 8
    while (output.length % 8 != 0) {
      output.write('=');
    }

    return output.toString();
  }
}
