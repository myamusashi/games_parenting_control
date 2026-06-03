import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  String _pin = "";
  String _confirmPin = "";
  bool _isConfirming = false;
  bool _isError = false;
  String _errorMessage = "";

  void _onKeyPress(String val) {
    setState(() {
      _isError = false;
    });

    if (!_isConfirming) {
      if (_pin.length < 4) {
        setState(() => _pin += val);
        if (_pin.length == 4) {
          Future.delayed(const Duration(milliseconds: 300), () {
            setState(() => _isConfirming = true);
          });
        }
      }
    } else {
      if (_confirmPin.length < 4) {
        setState(() => _confirmPin += val);
        if (_confirmPin.length == 4) {
          _verifyAndSave();
        }
      }
    }
  }

  void _onBackspace() {
    setState(() {
      _isError = false;
    });
    if (!_isConfirming) {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
    } else {
      if (_confirmPin.isNotEmpty) {
        setState(
          () => _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1),
        );
      } else {
        // Kembali ke input PIN pertama jika menghapus di awal konfirmasi
        setState(() => _isConfirming = false);
      }
    }
  }

  void _verifyAndSave() async {
    if (_pin == _confirmPin) {
      await StorageService.saveParentPin(_pin);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      setState(() {
        _isError = true;
        _errorMessage = "PIN tidak cocok! Silakan coba lagi.";
        _confirmPin = "";
        _pin = "";
        _isConfirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String currentDisplay = _isConfirming ? _confirmPin : _pin;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // Header text
            Icon(
              Icons.security_rounded,
              size: 64,
              color: const Color(0xFF6C63FF),
            ),
            const SizedBox(height: 16),
            Text(
              _isConfirming ? 'Konfirmasi PIN Anda' : 'Atur PIN Orang Tua',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _isConfirming
                    ? 'Masukkan kembali 4 digit PIN yang telah Anda buat.'
                    : 'PIN ini digunakan untuk masuk ke Parent Dashboard dan membatasi akses anak.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ),
            const SizedBox(height: 24),

            // Indikator Dots PIN
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                bool isFilled = index < currentDisplay.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isError
                        ? Colors.red
                        : (isFilled ? const Color(0xFF6C63FF) : Colors.white54),
                  ),
                );
              }),
            ),

            if (_isError) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            const Spacer(),

            // Custom Numeric Keyboard
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['1', '2', '3'].map(_buildKey).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['4', '5', '6'].map(_buildKey).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['7', '8', '9'].map(_buildKey).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(
                        width: 90,
                        height: 65,
                      ), // Placeholder kosong kiri
                      _buildKey('0'),
                      _buildBackspaceKey(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(String label) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeyPress(label),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 90,
          height: 65,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _onBackspace,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 90,
          height: 65,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.backspace_outlined,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}
