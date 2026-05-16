import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const GameBoxApp());
}

class GameBoxApp extends StatelessWidget {
  const GameBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GameBox Parent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}
