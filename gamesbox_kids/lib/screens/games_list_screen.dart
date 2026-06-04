import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:gamesbox_common/gamesbox_common.dart';
import 'game_play_screen.dart';

class GamesListScreen extends StatefulWidget {
  const GamesListScreen({super.key});

  @override
  State<GamesListScreen> createState() => _GamesListScreenState();
}

class _GamesListScreenState extends State<GamesListScreen> {
  List<GameModel> _games = [];
  late final DatabaseReference _ref;
  late final Stream<DatabaseEvent> _stream;
  String? kidId;

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
          final map = v as Map<dynamic, dynamic>;
          final enabled = map['enabled'] ?? true;
          if (enabled) list.add(GameModel.fromMap(k, v));
        });
      }
      setState(() => _games = list);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args.containsKey('kidId')) kidId = args['kidId'] as String;
  }

  void _openGame(GameModel g) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => GamePlayScreen(game: g, kidId: kidId)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Games')),
      body: ListView.builder(
        itemCount: _games.length,
        itemBuilder: (context, i) {
          final g = _games[i];
          return ListTile(
            title: Text(g.name),
            subtitle: Text(g.packageId),
            trailing: ElevatedButton(onPressed: () => _openGame(g), child: const Text('Play')),
          );
        },
      ),
    );
  }
}
