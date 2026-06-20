import 'package:flutter/material.dart';
import 'package:gamesbox_common/gamesbox_common.dart';

class AddAllowedGameScreen extends StatefulWidget {
  final ChildModel child;

  const AddAllowedGameScreen({super.key, required this.child});

  @override
  State<AddAllowedGameScreen> createState() => _AddAllowedGameScreenState();
}

class _AddAllowedGameScreenState extends State<AddAllowedGameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _packageController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _packageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final game = AllowedGame(
        name: _nameController.text.trim(),
        packageName: _packageController.text.trim(),
        addedBy: 'parent',
        addedAt: DateTime.now().toUtc().toIso8601String(),
      );
      await AllowedGamesService.addGame(widget.child.id, game);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${game.name} ditambahkan untuk ${widget.child.name}'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menambahkan game: $e'),
          backgroundColor: const Color(0xFFFF5252),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _validatePackageName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Package name wajib diisi';
    final valid = RegExp(r'^[a-zA-Z][\w]*(\.[a-zA-Z][\w]*)+$').hasMatch(text);
    if (!valid) return 'Contoh: com.mojang.minecraftpe';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      appBar: AppBar(
        title: Text('Tambah Game ${widget.child.name}'),
        backgroundColor: const Color(0xFF0F0E17),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2A2A3E)),
              ),
              child: const Text(
                'Masukkan game yang boleh dimainkan anak. Package name harus sesuai dengan aplikasi di perangkat anak agar bisa dibuka.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                label: 'Nama game',
                hint: 'Minecraft',
                icon: Icons.sports_esports_rounded,
              ),
              validator: (value) {
                if ((value?.trim() ?? '').isEmpty) {
                  return 'Nama game wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _packageController,
              style: const TextStyle(color: Colors.white),
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              decoration: _inputDecoration(
                label: 'Package name',
                hint: 'com.mojang.minecraftpe',
                icon: Icons.android_rounded,
              ),
              validator: _validatePackageName,
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(_isSaving ? 'Menyimpan...' : 'Tambahkan Game'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF6C63FF)),
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white30),
      filled: true,
      fillColor: const Color(0xFF1A1A2E),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2A2A3E)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF6C63FF)),
      ),
    );
  }
}
