import 'package:flutter/material.dart';
import '../models/game_entry.dart';

class GameCard extends StatelessWidget {
  final GameEntry game;
  final VoidCallback onTap;
  final bool isAllLocked;

  const GameCard({
    super.key,
    required this.game,
    required this.onTap,
    required this.isAllLocked,
  });

  @override
  Widget build(BuildContext context) {
    final locked = game.isLocked || isAllLocked;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Game Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: locked ? Colors.grey[200] : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: locked
                  ? Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.grey[400],
                      size: 32,
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: game.iconBytes != null
                          ? Image.memory(game.iconBytes!, fit: BoxFit.cover)
                          : const Icon(Icons.gamepad_rounded, size: 32),
                    ),
            ),
            const SizedBox(height: 12),
            // Game Name
            Text(
              game.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
            ),
            const SizedBox(height: 4),
            // Played Time
            Text(
              locked
                  ? 'Batas habis'
                  : 'Dimainkan ${game.totalPlayedSecondsToday < 60 ? '${game.totalPlayedSecondsToday} dtk' : '${game.totalPlayedSecondsToday ~/ 60} mnt'}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: locked
                    ? const Color(0xFFFFEBEE)
                    : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                locked ? 'Terkunci' : 'Tersedia',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: locked
                      ? const Color(0xFFE53935)
                      : const Color(0xFF43A047),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
