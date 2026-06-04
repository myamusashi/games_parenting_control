import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gamesbox_common/gamesbox_common.dart';
import '../services/otp_service.dart';
import 'pairing_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _showPassword = false;
  String? _errorMessage;
  int _currentStep = 0; // 0: email/password, 1: setup confirmation

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    // Validate inputs
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Email dan password tidak boleh kosong');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Password tidak cocok');
      return;
    }

    if (_passwordController.text.length < 6) {
      setState(() => _errorMessage = 'Password minimal 6 karakter');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Register with Firebase
      final credential = await FirebaseService.registerParent(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (credential != null && mounted) {
        // Generate OTP secret
        final otpSecret = OtpService.generateSecret();
        
        // Save OTP secret locally
        await StorageService.saveOtpSecret(otpSecret);

        // Create family in Firebase with OTP secret
        final familyId = await FirebaseService.createFamily(
          otpSecret: otpSecret,
          dailyLimitMinutes: 60,
        );

        // Save family ID locally
        await StorageService.saveFamilyId(familyId);
        await StorageService.setUseFirebase(true);

        // Move to confirmation step
        setState(() => _currentStep = 1);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
      });
    } catch (e) {
      setState(() => _errorMessage = 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Password terlalu lemah';
      case 'email-already-in-use':
        return 'Email sudah terdaftar';
      case 'invalid-email':
        return 'Email tidak valid';
      default:
        return 'Pendaftaran gagal: $code';
    }
  }

  void _proceedToSetup() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PairingGuideScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      body: SafeArea(
        child: _currentStep == 0
            ? _buildRegistrationForm()
            : _buildConfirmationStep(),
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFFFF6584)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.sports_esports_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'GameBox Parent',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Daftar Akun Parent',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF9191A4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Email field
          const Text(
            'Email',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            enabled: !_isLoading,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'parent@example.com',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF1E1E2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF6C63FF)),
            ),
          ),
          const SizedBox(height: 24),

          // Password field
          const Text(
            'Password',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            enabled: !_isLoading,
            obscureText: !_showPassword,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Minimal 6 karakter',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF1E1E2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.lock_outlined, color: Color(0xFF6C63FF)),
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility : Icons.visibility_off,
                  color: Color(0xFF6C63FF),
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Confirm password field
          const Text(
            'Konfirmasi Password',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmPasswordController,
            enabled: !_isLoading,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ulangi password Anda',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF1E1E2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.lock_outlined, color: Color(0xFF6C63FF)),
            ),
          ),

          // Error message
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Register button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _isLoading ? null : _register,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                disabledBackgroundColor: Colors.grey[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text(
                      'Daftar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Login link
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Sudah punya akun? ',
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Masuk',
                    style: TextStyle(
                      color: Color(0xFF6C63FF),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(60),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 2),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 60,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Pendaftaran Berhasil!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Akun Anda telah dibuat. Sekarang siapkan device anak untuk pairing.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: 280,
            height: 56,
            child: FilledButton.icon(
              onPressed: _proceedToSetup,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Lanjut ke Setup'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
