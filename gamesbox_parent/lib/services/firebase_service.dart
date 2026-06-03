import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseDatabase _database = FirebaseDatabase.instance;

  static const String _familyIdKey = 'family_id';
  static const String _otpSecretKey = 'otp_secret';

  // ──── INITIALIZATION ────
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _database.setPersistenceEnabled(true);
    } catch (e) {
      print('Firebase initialization error: $e');
    }
  }

  // ──── AUTHENTICATION ────
  static Future<UserCredential?> registerParent({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      print('Registration error: ${e.message}');
      rethrow;
    }
  }

  static Future<UserCredential?> loginParent({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      print('Login error: ${e.message}');
      rethrow;
    }
  }

  static Future<void> logoutParent() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Logout error: $e');
    }
  }

  static User? getCurrentUser() => _auth.currentUser;

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  // ──── FAMILY ID & SETUP ────
  /// Create family node and return family_id (which is the user's UID)
  static Future<String> createFamily({
    required String otpSecret,
    required int dailyLimitMinutes,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final familyId = user.uid;
      final now = DateTime.now();
      final dateKey = '${now.year}-${now.month}-${now.day}';

      await _database.ref('families/$familyId/config').set({
        'dailyLimitMinutes': dailyLimitMinutes,
        'otpSecret': otpSecret,
        'parentEmail': user.email,
        'createdAt': ServerValue.timestamp,
      });

      // Initialize usage for today
      await _database.ref('families/$familyId/usage/$dateKey').set({
        'totalSeconds': 0,
        'games': {},
      });

      return familyId;
    } catch (e) {
      print('Create family error: $e');
      rethrow;
    }
  }

  static Future<String?> getFamilyIdFromFirebase() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      return user.uid; // Family ID is the user's UID
    } catch (e) {
      print('Get family ID error: $e');
      return null;
    }
  }

  // ──── DAILY LIMIT ────
  static Stream<int> watchDailyLimit(String familyId) {
    return _database
        .ref('families/$familyId/config/dailyLimitMinutes')
        .onValue
        .map((event) {
          final value = event.snapshot.value;
          return value is int ? value : 60;
        });
  }

  static Future<void> updateDailyLimit(String familyId, int minutes) async {
    try {
      await _database
          .ref('families/$familyId/config/dailyLimitMinutes')
          .set(minutes);
    } catch (e) {
      print('Update daily limit error: $e');
      rethrow;
    }
  }

  // ──── USAGE TRACKING ────
  static Future<int> getTodayTotalSeconds(String familyId) async {
    try {
      final now = DateTime.now();
      final dateKey = _getDateKey(now);

      final snapshot = await _database
          .ref('families/$familyId/usage/$dateKey/totalSeconds')
          .get();

      return snapshot.value is int ? snapshot.value as int : 0;
    } catch (e) {
      print('Get total seconds error: $e');
      return 0;
    }
  }

  static Stream<int> watchTodayTotalSeconds(String familyId) {
    final dateKey = _getDateKey(DateTime.now());
    return _database
        .ref('families/$familyId/usage/$dateKey/totalSeconds')
        .onValue
        .map((event) {
          final value = event.snapshot.value;
          return value is int ? value : 0;
        });
  }

  static Future<void> updateTotalSeconds(String familyId, int seconds) async {
    try {
      final dateKey = _getDateKey(DateTime.now());
      await _database
          .ref('families/$familyId/usage/$dateKey/totalSeconds')
          .set(seconds);
    } catch (e) {
      print('Update total seconds error: $e');
      rethrow;
    }
  }

  // ──── GAME USAGE ────
  static Future<int> getGameTodaySeconds(
    String familyId,
    String gameName,
  ) async {
    try {
      final dateKey = _getDateKey(DateTime.now());
      final snapshot = await _database
          .ref('families/$familyId/usage/$dateKey/games/$gameName')
          .get();

      return snapshot.value is int ? snapshot.value as int : 0;
    } catch (e) {
      print('Get game seconds error: $e');
      return 0;
    }
  }

  static Stream<int> watchGameTodaySeconds(String familyId, String gameName) {
    final dateKey = _getDateKey(DateTime.now());
    return _database
        .ref('families/$familyId/usage/$dateKey/games/$gameName')
        .onValue
        .map((event) {
          final value = event.snapshot.value;
          return value is int ? value : 0;
        });
  }

  static Future<void> updateGameSeconds(
    String familyId,
    String gameName,
    int seconds,
  ) async {
    try {
      final dateKey = _getDateKey(DateTime.now());
      await _database
          .ref('families/$familyId/usage/$dateKey/games/$gameName')
          .set(seconds);
    } catch (e) {
      print('Update game seconds error: $e');
      rethrow;
    }
  }

  // ──── ALLOWED GAMES ────
  static Future<List<Map<String, dynamic>>> getAllowedGames(
    String familyId,
  ) async {
    try {
      final snapshot = await _database
          .ref('families/$familyId/config/allowedGames')
          .get();

      if (!snapshot.exists) return [];

      final List<Map<String, dynamic>> games = [];
      for (var child in snapshot.children) {
        games.add(Map<String, dynamic>.from(child.value as Map));
      }
      return games;
    } catch (e) {
      print('Get allowed games error: $e');
      return [];
    }
  }

  static Stream<List<Map<String, dynamic>>> watchAllowedGames(String familyId) {
    return _database.ref('families/$familyId/config/allowedGames').onValue.map((
      event,
    ) {
      if (!event.snapshot.exists) return [];

      final List<Map<String, dynamic>> games = [];
      for (var child in event.snapshot.children) {
        games.add(Map<String, dynamic>.from(child.value as Map));
      }
      return games;
    });
  }

  static Future<void> addAllowedGame(
    String familyId,
    String packageName,
    String gameName,
  ) async {
    try {
      await _database
          .ref('families/$familyId/config/allowedGames/$packageName')
          .set({
            'name': gameName,
            'packageName': packageName,
            'isLocked': false,
          });
    } catch (e) {
      print('Add game error: $e');
      rethrow;
    }
  }

  static Future<void> removeAllowedGame(
    String familyId,
    String packageName,
  ) async {
    try {
      await _database
          .ref('families/$familyId/config/allowedGames/$packageName')
          .remove();
    } catch (e) {
      print('Remove game error: $e');
      rethrow;
    }
  }

  // ──── RESET DAILY ────
  static Future<void> resetDailyData(String familyId) async {
    try {
      final now = DateTime.now();
      final dateKey = _getDateKey(now);

      await _database.ref('families/$familyId/usage/$dateKey').set({
        'totalSeconds': 0,
        'games': {},
      });
    } catch (e) {
      print('Reset daily data error: $e');
      rethrow;
    }
  }

  // ──── UNLOCK REQUEST ────
  /// Parent sends unlock request (usually automatic when showing OTP)
  static Future<void> sendUnlockRequest(
    String familyId,
    String requestId,
  ) async {
    try {
      final now = DateTime.now();
      await _database.ref('families/$familyId/requests/$requestId').set({
        'type': 'unlock',
        'timestamp': ServerValue.timestamp,
        'status': 'pending',
      });

      // Auto-expire after 2 minutes
      Future.delayed(Duration(minutes: 2), () {
        _database
            .ref('families/$familyId/requests/$requestId')
            .remove()
            .catchError((e) => print('Error removing request: $e'));
      });
    } catch (e) {
      print('Send unlock request error: $e');
      rethrow;
    }
  }

  // ──── HELPER ────
  static String _getDateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  /// Get OTP secret from local storage to sync
  static Future<String?> getOtpSecretFromFirebase(String familyId) async {
    try {
      final snapshot = await _database
          .ref('families/$familyId/config/otpSecret')
          .get();
      return snapshot.value is String ? snapshot.value as String : null;
    } catch (e) {
      print('Get OTP secret error: $e');
      return null;
    }
  }
}
