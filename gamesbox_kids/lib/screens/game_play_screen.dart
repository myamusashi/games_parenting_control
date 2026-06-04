import 'package:flutter/material.dart';
import 'package:gamesbox_common/gamesbox_common.dart';
import 'package:firebase_database/firebase_database.dart';

class GamePlayScreen extends StatefulWidget {
  final GameModel game;
  final String? kidId;

  const GamePlayScreen({super.key, required this.game, this.kidId});

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  int remainingSeconds = 0;

  Future<void> _fetchTimeLimit() async {
    if (widget.kidId == null) return;
    final snap = await FirebaseDatabase.instance.ref().child('time_limits').child(widget.kidId!).get();
    if (!snap.exists) return;
    final map = snap.value as Map<dynamic, dynamic>;
    final secs = map['dailySeconds'] ?? 0;
    setState(() => remainingSeconds = secs);
  }

  @override
  void initState() {
    super.initState();
    _fetchTimeLimit();
  }

  void _startFakePlay() {
    // In a real app, here you'd launch the game package via platform channel.
    // For starter, we'll just decrement remainingSeconds every second to simulate usage.
    if (remainingSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No remaining time')));
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: Text('Playing ${widget.game.name}'),
          content: const Text('Simulating gameplay for 10 seconds...'),
        );
      },
    );
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        Navigator.pop(context);
        setState(() => remainingSeconds = (remainingSeconds - 10).clamp(0, remainingSeconds));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Finished simulated play (-10s)')));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.game.name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Package: ${widget.game.packageId}'),
            const SizedBox(height: 8),
            Text('Remaining seconds today: $remainingSeconds'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _startFakePlay, child: const Text('Play (simulate)')),
          ],
        ),
      ),
    );
  }
}
