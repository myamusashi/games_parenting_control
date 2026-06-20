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

  static const _suggestions = [
    _GameSuggestion('Minecraft', 'com.mojang.minecraftpe'),
    _GameSuggestion('Roblox', 'com.roblox.client'),
    _GameSuggestion('YouTube Kids', 'com.google.android.apps.youtube.kids'),
    _GameSuggestion('Subway Surfers', 'com.kiloo.subwaysurf'),
    _GameSuggestion('Duolingo', 'com.duolingo'),
  ];

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
      final packageName = _extractPackageName(_packageController.text.trim());
      final game = AllowedGame(
        name: _nameController.text.trim(),
        packageName: packageName,
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
    final text = _extractPackageName(value?.trim() ?? '');
    if (text.isEmpty) return 'Package name wajib diisi';
    final valid = RegExp(r'^[a-zA-Z][\w]*(\.[a-zA-Z][\w]*)+$').hasMatch(text);
    if (!valid) return 'Tempel link Play Store atau package name';
    return null;
  }

  String _extractPackageName(String input) {
    if (input.isEmpty) return '';

    final uri = Uri.tryParse(input);
    final id = uri?.queryParameters['id'];
    if (id != null && id.isNotEmpty) return id.trim();

    final match = RegExp(r'id=([^&\s]+)').firstMatch(input);
    if (match != null) return Uri.decodeComponent(match.group(1)!);

    return input.trim();
  }

  String _guessNameFromPackage(String packageName) {
    final last = packageName.split('.').last;
    return last
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  void _useSuggestion(_GameSuggestion suggestion) {
    setState(() {
      _nameController.text = suggestion.name;
      _packageController.text = suggestion.packageName;
    });
  }

  void _normalizePackageInput(String value) {
    final packageName = _extractPackageName(value);
    if (packageName != value && packageName.isNotEmpty) {
      _packageController.value = TextEditingValue(
        text: packageName,
        selection: TextSelection.collapsed(offset: packageName.length),
      );
    }

    if (_nameController.text.trim().isEmpty && packageName.contains('.')) {
      _nameController.text = _guessNameFromPackage(packageName);
    }
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
                'Cara termudah: buka Play Store, pilih game, Share, lalu salin link dan tempel di sini. Package ID akan diambil otomatis.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Pilihan cepat',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestions.map((suggestion) {
                return ActionChip(
                  label: Text(suggestion.name),
                  avatar: const Icon(Icons.add_rounded, size: 16),
                  onPressed: () => _useSuggestion(suggestion),
                  backgroundColor: const Color(0xFF1A1A2E),
                  labelStyle: const TextStyle(color: Colors.white),
                  side: const BorderSide(color: Color(0xFF2A2A3E)),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
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
                label: 'Play Store link atau package name',
                hint: 'https://play.google.com/store/apps/details?id=com...',
                icon: Icons.android_rounded,
              ),
              onChanged: _normalizePackageInput,
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

class _GameSuggestion {
  final String name;
  final String packageName;

  const _GameSuggestion(this.name, this.packageName);
}
