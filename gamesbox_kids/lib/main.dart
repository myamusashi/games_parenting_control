import 'package:flutter/material.dart';
import 'services/firebase_service.dart';
import 'screens/pairing_screen.dart';
import 'screens/games_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.init();
  runApp(const KidsApp());
}

class KidsApp extends StatelessWidget {
  const KidsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GamesBox Kids',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const PairingScreen(),
      routes: {
        '/pairing': (context) => const PairingScreen(),
        '/games': (context) => const GamesListScreen(),
      },
    );
  }
}
