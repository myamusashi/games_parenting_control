import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  static FirebaseApp? _app;
  static FirebaseDatabase? database;

  static Future<void> init() async {
    _app ??= await Firebase.initializeApp();
    database = FirebaseDatabase.instance;
  }
}
