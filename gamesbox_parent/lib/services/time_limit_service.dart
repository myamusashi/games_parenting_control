import 'package:firebase_database/firebase_database.dart';
import '../models/time_limit_model.dart';

class TimeLimitService {
  final DatabaseReference _ref = FirebaseDatabase.instance.ref().child('time_limits');

  Future<void> setDailyLimit(TimeLimitModel tl) async {
    await _ref.child(tl.childId).set(tl.toMap());
  }

  Future<DatabaseEvent> getDailyLimit(String childId) async {
    return await _ref.child(childId).once();
  }
}
