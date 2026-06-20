import 'package:flutter/material.dart';
import 'package:gamesbox_common/gamesbox_common.dart';
import 'screens/splash_screen.dart';
import 'screens/pairing_screen.dart';
import 'screens/home_screen.dart';

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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF43A047)),
      ),
      // BUG-03 FIX: home is now KidsSplashScreen which checks pairing status
      home: const KidsSplashScreen(),
      routes: {
        '/pairing': (context) => const PairingScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
