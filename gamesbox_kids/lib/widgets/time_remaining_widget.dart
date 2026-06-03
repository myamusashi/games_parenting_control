import 'package:flutter/material.dart';

class TimeRemainingWidget extends StatelessWidget {
  final int seconds;
  const TimeRemainingWidget({super.key, required this.seconds});

  @override
  Widget build(BuildContext context) {
    final minutes = (seconds / 60).floor();
    final hrs = (minutes / 60).floor();
    final mins = minutes % 60;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.yellow[100]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Time Remaining', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${hrs}h ${mins}m remaining'),
        ],
      ),
    );
  }
}
