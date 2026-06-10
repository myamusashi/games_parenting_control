import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  static FirebaseApp? _app;
  static FirebaseDatabase? database;

  static Future<void> init() async {
    _app ??= await Firebase.initializeApp();
    database = FirebaseDatabase.instance;
  }

  // ─── BUG-01 FIX: Add getCurrentUser() ────────────────────────────────────
  /// Returns the currently signed-in Firebase user, or null if not signed in.
  static User? getCurrentUser() => FirebaseAuth.instance.currentUser;

  /// Sign in anonymously (used by kids app so Firebase rules can apply).
  /// If already signed in (anonymous or otherwise), returns current user.
  static Future<User?> signInAnonymously() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) return current;
    final credential = await FirebaseAuth.instance.signInAnonymously();
    return credential.user;
  }

  /// Register a new parent account with email/password.
  /// Returns [UserCredential] on success, or null if auth fails silently.
  static Future<UserCredential?> registerParent({
    required String email,
    required String password,
  }) async {
    final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential;
  }

  /// Sign in existing parent with email/password.
  static Future<UserCredential?> signInParent({
    required String email,
    required String password,
  }) async {
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential;
  }

  /// Create a family node in the Realtime Database for the currently signed-in parent.
  /// Stores the OTP secret and initial daily limit. Returns the generated family ID.
  static Future<String> createFamily({
    required String otpSecret,
    int dailyLimitMinutes = 60,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('No authenticated user found');

    final ref = FirebaseDatabase.instance.ref('families');
    final newRef = ref.push();
    await newRef.set({
      'parentId': uid,
      'otpSecret': otpSecret,
      'dailyLimitMinutes': dailyLimitMinutes,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return newRef.key!;
  }
}
