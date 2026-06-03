import 'package:firebase_database/firebase_database.dart';
import '../models/game_model.dart';

class GamesService {
  final DatabaseReference _ref = FirebaseDatabase.instance.ref().child('games');

  Future<void> addGame(GameModel game) async {
    final newRef = _ref.push();
    await newRef.set(game.toMap());
  }

  Future<void> updateGame(GameModel game) async {
    await _ref.child(game.id).update(game.toMap());
  }

  Future<void> removeGame(String id) async {
    await _ref.child(id).remove();
  }

  Query listQuery() => _ref.orderByKey();
}
