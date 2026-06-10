import 'package:flutter/material.dart';

/// UX-K-05: Shimmer skeleton card shown while game list is loading.
class SkeletonGameCard extends StatefulWidget {
  const SkeletonGameCard({super.key});

  @override
  State<SkeletonGameCard> createState() => _SkeletonGameCardState();
}

class _SkeletonGameCardState extends State<SkeletonGameCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon placeholder
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: _anim.value),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 12),
            // Name placeholder
            Container(
              width: 80,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: _anim.value),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            const SizedBox(height: 8),
            // Sub-text placeholder
            Container(
              width: 60,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: _anim.value * 0.7),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(height: 10),
            // Badge placeholder
            Container(
              width: 56,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: _anim.value * 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
