import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/parent_dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.init();
  runApp(const ParentApp());
}

class ParentApp extends StatelessWidget {
  const ParentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GamesBox Parent',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginScreen(),
      routes: {
        '/dashboard': (context) => const ParentDashboardScreen(),
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}
