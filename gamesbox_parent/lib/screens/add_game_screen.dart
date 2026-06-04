import 'package:flutter/material.dart';
import 'package:gamesbox_common/gamesbox_common.dart';
import '../services/games_service.dart';

class AddGameScreen extends StatefulWidget {
  const AddGameScreen({super.key});

  @override
  State<AddGameScreen> createState() => _AddGameScreenState();
}

class _AddGameScreenState extends State<AddGameScreen> {
  final _name = TextEditingController();
  final _pkg = TextEditingController();
  final GamesService _service = GamesService();
  bool _loading = false;

  Future<void> _save() async {
    setState(() => _loading = true);
    final game = GameModel(id: '', name: _name.text.trim(), packageId: _pkg.text.trim());
    await _service.addGame(game);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Game')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Game name')),
            const SizedBox(height: 8),
            TextField(controller: _pkg, decoration: const InputDecoration(labelText: 'Package ID')),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loading ? null : _save, child: _loading ? const CircularProgressIndicator() : const Text('Save')),
          ],
        ),
      ),
    );
  }
}
