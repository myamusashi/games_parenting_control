import 'package:flutter/material.dart';
import 'package:gamesbox_common/gamesbox_common.dart';
import '../services/time_limit_service.dart';

/// A card showing a paired child with their daily time-limit controls.
/// It streams both the current limit and the played-today seconds from Firebase.
class ChildTimeLimitCard extends StatefulWidget {
  final ChildModel child;
  final VoidCallback onOpenDetails;
  final VoidCallback onRemove;
  final VoidCallback onRename;

  const ChildTimeLimitCard({
    super.key,
    required this.child,
    required this.onOpenDetails,
    required this.onRemove,
    required this.onRename,
  });

  @override
  State<ChildTimeLimitCard> createState() => _ChildTimeLimitCardState();
}

class _ChildTimeLimitCardState extends State<ChildTimeLimitCard> {
  // Slider value in minutes; 0 = unlimited
  double _limitMinutes = 60;
  bool _isUnlimited = false;
  bool _isSaving = false;

  // Quick preset buttons
  static const List<_Preset> _presets = [
    _Preset('30m', 30),
    _Preset('1j', 60),
    _Preset('2j', 120),
    _Preset('∞', 0),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TimeLimitModel?>(
      stream: TimeLimitService.streamLimit(widget.child.id),
      builder: (context, limitSnap) {
        // Sync external limit into local slider only on first load
        if (limitSnap.hasData && limitSnap.data != null && !_isSaving) {
          final fetched = limitSnap.data!;
          _limitMinutes = fetched.isUnlimited ? 60 : fetched.dailyMinutes.toDouble();
          _isUnlimited = fetched.isUnlimited;
        }

        return StreamBuilder<int>(
          stream: TimeLimitService.streamTodayPlayed(widget.child.id),
          builder: (context, playedSnap) {
            final playedSeconds = playedSnap.data ?? 0;
            final playedMinutes = playedSeconds ~/ 60;
            final limitSec = _isUnlimited ? null : (_limitMinutes * 60).toInt();
            final progress = (limitSec == null || limitSec == 0)
                ? 0.0
                : (playedSeconds / limitSec).clamp(0.0, 1.0);
            final isOverLimit = !_isUnlimited && playedSeconds >= (limitSec ?? 0);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isOverLimit
                      ? const Color(0xFFFF5252).withValues(alpha: 0.5)
                      : const Color(0xFF2A2A3E),
                ),
              ),
              child: Column(
                children: [
                  // ── Header ──────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _avatarColors(widget.child.id),
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              widget.child.initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Name + status
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: widget.onOpenDetails,
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 2, horizontal: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.child.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.chevron_right_rounded,
                                          color: Colors.white54, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: widget.child.isOnline
                                          ? const Color(0xFF4CAF50)
                                          : const Color(0xFF666666),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    widget.child.isOnline ? 'Online' : 'Offline',
                                    style: TextStyle(
                                      color: widget.child.isOnline
                                          ? const Color(0xFF4CAF50)
                                          : const Color(0xFF666666),
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (isOverLimit) ...[
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF5252)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Batas tercapai',
                                        style: TextStyle(
                                          color: Color(0xFFFF5252),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        // More menu
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white54),
                          color: const Color(0xFF1E1E2E),
                          onSelected: (val) {
                            if (val == 'rename') widget.onRename();
                            if (val == 'remove') widget.onRemove();
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_rounded,
                                      color: Colors.white70, size: 18),
                                  SizedBox(width: 10),
                                  Text('Ubah Nama',
                                      style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Row(
                                children: [
                                  Icon(Icons.person_remove_rounded,
                                      color: Color(0xFFFF5252), size: 18),
                                  SizedBox(width: 10),
                                  Text('Hapus Anak',
                                      style: TextStyle(color: Color(0xFFFF5252))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Progress bar ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Hari ini: ${_formatMinutes(playedMinutes)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _isUnlimited
                                  ? 'Tanpa batas'
                                  : 'Batas: ${_formatMinutes(_limitMinutes.toInt())}',
                              style: TextStyle(
                                color: isOverLimit
                                    ? const Color(0xFFFF5252)
                                    : const Color(0xFF6C63FF),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _isUnlimited ? 0 : progress,
                            minHeight: 6,
                            backgroundColor: const Color(0xFF2A2A3E),
                            valueColor: AlwaysStoppedAnimation(
                              isOverLimit
                                  ? const Color(0xFFFF5252)
                                  : Color.lerp(
                                      const Color(0xFF4CAF50),
                                      const Color(0xFFFF5252),
                                      progress,
                                    )!,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Quick presets ────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: _presets.map((p) {
                        final isActive = p.minutes == 0
                            ? _isUnlimited
                            : (!_isUnlimited &&
                                _limitMinutes == p.minutes.toDouble());
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () => _applyPreset(p.minutes),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? const Color(0xFF6C63FF)
                                      : const Color(0xFF2A2A3E),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  p.label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : Colors.white54,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Slider ───────────────────────────────────────────────
                  if (!_isUnlimited) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          const Text('15m',
                              style: TextStyle(
                                  color: Color(0xFF666666), fontSize: 10)),
                          Expanded(
                            child: Slider(
                              value: _limitMinutes.clamp(15, 240),
                              min: 15,
                              max: 240,
                              divisions: 15,
                              activeColor: const Color(0xFF6C63FF),
                              inactiveColor: const Color(0xFF2A2A3E),
                              label: '${_limitMinutes.toInt()}m',
                              onChanged: (v) =>
                                  setState(() => _limitMinutes = v),
                              onChangeEnd: (v) =>
                                  _saveLimit(v.round()),
                            ),
                          ),
                          const Text('4j',
                              style: TextStyle(
                                  color: Color(0xFF666666), fontSize: 10)),
                        ],
                      ),
                    ),
                  ] else ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Tidak ada batasan waktu',
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _applyPreset(int minutes) {
    setState(() {
      _isUnlimited = minutes == 0;
      if (minutes > 0) _limitMinutes = minutes.toDouble();
    });
    _saveLimit(minutes);
  }

  Future<void> _saveLimit(int minutes) async {
    setState(() => _isSaving = true);
    await TimeLimitService.setLimitMinutes(widget.child.id, minutes);
    if (mounted) setState(() => _isSaving = false);
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}j' : '${h}j ${m}m';
  }

  List<Color> _avatarColors(String id) {
    // Deterministic colour from child ID hash
    final colors = [
      [const Color(0xFF6C63FF), const Color(0xFF9C89FF)],
      [const Color(0xFFFF6584), const Color(0xFFFF8FA0)],
      [const Color(0xFF43A047), const Color(0xFF66BB6A)],
      [const Color(0xFFFF9800), const Color(0xFFFFB74D)],
      [const Color(0xFF00BCD4), const Color(0xFF4DD0E1)],
    ];
    final index = id.hashCode.abs() % colors.length;
    return colors[index];
  }
}

class _Preset {
  final String label;
  final int minutes;
  const _Preset(this.label, this.minutes);
}
