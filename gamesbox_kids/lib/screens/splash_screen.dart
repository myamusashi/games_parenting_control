import 'package:flutter/material.dart';
import 'package:gamesbox_common/gamesbox_common.dart';
import 'locked_screen.dart';

/// KidsSplashScreen — shown on every app launch.
///
/// BUG-03 FIX: Instead of always going to PairingScreen, it:
///  1. Signs in anonymously so Firebase rules apply (kids app requirement).
///  2. Triggers the daily-reset check.
///  3. Routes to HomeScreen if already paired, or PairingScreen if not.
class KidsSplashScreen extends StatefulWidget {
  const KidsSplashScreen({super.key});

  @override
  State<KidsSplashScreen> createState() => _KidsSplashScreenState();
}

class _KidsSplashScreenState extends State<KidsSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();

    Future.delayed(const Duration(seconds: 2), _checkAndNavigate);
  }

  Future<void> _checkAndNavigate() async {
    if (!mounted) return;

    // Sign in anonymously so Firebase security rules apply (kids app)
    await FirebaseService.signInAnonymously();

    // Trigger the daily-reset check (BUG-03 note from PLANNING.md)
    await StorageService.getTotalPlayed();

    final kidId = await StorageService.getKidId();
    if (!mounted) return;

    if (kidId != null && kidId.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LockedScreen(requireParentUnlockOnly: true),
        ),
      );
      return;
    }

    Navigator.pushReplacementNamed(context, '/pairing');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF43A047).withValues(alpha: 0.5),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.sports_esports_rounded,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'GameBox',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                const Text(
                  'Kids',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    color: Color(0xFF43A047),
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 48),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF43A047),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
