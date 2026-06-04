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
  final TimeLimitService _service = TimeLimitService();
  bool _loading = false;

  Future<void> _save() async {
    setState(() => _loading = true);
    final tl = TimeLimitModel(childId: _childId.text.trim(), dailySeconds: (int.tryParse(_minutes.text) ?? 0) * 60);
    await _service.setDailyLimit(tl);
    if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Time limit saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Time Limits')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _childId, decoration: const InputDecoration(labelText: 'Child ID')),
            const SizedBox(height: 8),
            TextField(controller: _minutes, decoration: const InputDecoration(labelText: 'Minutes per day'), keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loading ? null : _save, child: _loading ? const CircularProgressIndicator() : const Text('Save')),
          ],
        ),
      ),
    );
  }
}
