import 'package:flutter/material.dart';

class TimerCard extends StatelessWidget {
  final int remainingMinutes;
  final int dailyLimit;
  final double usageRatio;
  final int totalPlayed;

  const TimerCard({
    super.key,
    required this.remainingMinutes,
    required this.dailyLimit,
    required this.usageRatio,
    required this.totalPlayed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Icon
              const Icon(
                Icons.timer_outlined,
                color: Color(0xFFFFD54F),
                size: 32,
              ),
              const SizedBox(width: 16),
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$remainingMinutes menit',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Sisa waktu bermain hari ini (batas: ${dailyLimit >= 60 ? "${dailyLimit ~/ 60} jam" : "$dailyLimit menit"})',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: usageRatio,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD54F)),
            ),
          ),
        ],
      ),
    );
  }
}
