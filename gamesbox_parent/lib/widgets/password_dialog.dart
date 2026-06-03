import 'package:flutter/material.dart';
import 'package:games_parenting_control/services/storage_service.dart';

class PasswordDialog extends StatefulWidget {
  final VoidCallback onSuccess;

  const PasswordDialog({super.key, required this.onSuccess});

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  String _input = "";
  bool _isError = false;

  void _onKeyPress(String val) {
    if (_input.length < 4) {
      setState(() {
        _input += val;
        _isError = false;
      });

      if (_input.length == 4) {
        _check();
      }
    }
  }

  void _onBackspace() {
    if (_input.isNotEmpty) {
      setState(() {
        _input = _input.substring(0, _input.length - 1);
        _isError = false;
      });
    }
  }

  void _check() async {
    String correctPin = await StorageService.getParentPin();

    if (_input == correctPin) {
      widget.onSuccess();
    } else {
      setState(() => _isError = true);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _input = "";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3F4E96), Color(0xFF7E60AF), Color(0xFF9F59B1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const Spacer(flex: 1),

                // Logo
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.sports_esports_outlined,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                const Text(
                  'GameBox Parent',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Masukkan PIN untuk masuk sebagai Orang Tua',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // PIN Indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    bool isFilled = index < _input.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isError
                            ? Colors.redAccent.withOpacity(0.8)
                            : (isFilled ? Colors.white : Colors.transparent),
                        border: Border.all(
                          color: _isError
                              ? Colors.redAccent
                              : Colors.white.withOpacity(0.5),
                          width: 2.5,
                        ),
                        boxShadow: isFilled && !_isError
                            ? [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ]
                            : [],
                      ),
                    );
                  }),
                ),

                const Spacer(flex: 2),

                // Numeric Keypad
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    children: [
                      _buildRow(['1', '2', '3']),
                      const SizedBox(height: 16),
                      _buildRow(['4', '5', '6']),
                      const SizedBox(height: 16),
                      _buildRow(['7', '8', '9']),
                      const SizedBox(height: 16),
                      _buildLastRow(),
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // Footer
                Text(
                  'Lupa PIN? Hubungi admin perangkat',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((k) => _buildKey(k)).toList(),
    );
  }

  Widget _buildLastRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        const SizedBox(width: 90), // Empty space for alignment
        _buildKey('0'),
        _buildBackspaceKey(),
      ],
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
            color: Colors.white.withOpacity(0.12),
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
            color: Colors.white.withOpacity(0.08),
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
