import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/games_service.dart';
import '../widgets/game_card.dart';
import 'package:gamesbox_common/gamesbox_common.dart';
import 'add_game_screen.dart';

class GamesListScreen extends StatefulWidget {
  const GamesListScreen({super.key});

  @override
  State<GamesListScreen> createState() => _GamesListScreenState();
}

class _GamesListScreenState extends State<GamesListScreen> {
  final GamesService _service = GamesService();
  List<GameModel> _games = [];
  late final DatabaseReference _ref;
  late final Stream<DatabaseEvent> _stream;

  @override
  void initState() {
    super.initState();
    _ref = FirebaseDatabase.instance.ref().child('games');
    _stream = _ref.onValue;
    _stream.listen((event) {
      final list = <GameModel>[];
      final val = event.snapshot.value as Map<dynamic, dynamic>?;
      if (val != null) {
        val.forEach((k, v) {
          list.add(GameModel.fromMap(k, v));
        });
      }
      setState(() => _games = list);
    });
  }

  void _onAdd() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddGameScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Games')),
      body: ListView(
        children: _games.map((g) => GameCard(name: g.name, enabled: g.enabled, onEdit: () {}, onDelete: () => _service.removeGame(g.id))).toList(),
      ),
      floatingActionButton: FloatingActionButton(onPressed: _onAdd, child: const Icon(Icons.add)),
    );
  }
}
