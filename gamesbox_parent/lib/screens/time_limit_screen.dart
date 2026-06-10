import 'package:flutter/material.dart';
import '../services/time_limit_service.dart';
import 'package:gamesbox_common/gamesbox_common.dart';

class TimeLimitScreen extends StatefulWidget {
  const TimeLimitScreen({super.key});

  @override
  State<TimeLimitScreen> createState() => _TimeLimitScreenState();
}

class _TimeLimitScreenState extends State<TimeLimitScreen> {
  final _childId = TextEditingController();
  final _minutes = TextEditingController();
  // BUG-02 FIX: Removed `final TimeLimitService _service = TimeLimitService();`
  // TimeLimitService methods are all static; no instantiation needed.
  bool _loading = false;

  Future<void> _save() async {
    setState(() => _loading = true);
    // BUG-02 FIX: Call static method directly instead of via instance
    final tl = TimeLimitModel(
      childId: _childId.text.trim(),
      dailySeconds: (int.tryParse(_minutes.text) ?? 0) * 60,
    );
    await TimeLimitService.setDailyLimit(tl);
    if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Batas waktu disimpan')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batas Waktu Harian')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _childId,
              decoration: const InputDecoration(labelText: 'Child ID'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _minutes,
              decoration: const InputDecoration(labelText: 'Menit per hari'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
