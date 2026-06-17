import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:gamesbox_common/gamesbox_common.dart';
import '../services/auth_service.dart';
import '../services/child_service.dart';
import '../services/time_limit_service.dart';
import 'child_detail_screen.dart';
import 'child_management_screen.dart';
import 'pairing_screen.dart';

/// UX-P-03 — ParentHomeScreen.
///
/// Replaces the old home_screen.dart that incorrectly showed a kids-style
/// TimerCard. This screen is designed for parents:
///
///   • AppBar with parent email + logout
///   • Summary strip  : total active children, total play time today
///   • Children list  : StreamBuilder from ChildService.streamChildren
///       └─ ChildQuickCard per child (avatar, name, online dot, mini progress)
///   • Empty state    : prompt to add first child / generate pairing QR
///   • FAB            : navigate to ChildrenManagementScreen
///
/// Tap a child card → ChildDetailScreen (Phase 3 feature).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _parentUid;
  String? _parentEmail;

  @override
  void initState() {
    super.initState();
    final user = AuthService.currentUser;
    _parentUid = user?.uid;
    _parentEmail = user?.email;
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Keluar?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Anda akan keluar dari akun parent.',
          style: TextStyle(color: Color(0xFFAAAAAA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await AuthService.signOut();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_parentUid == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0E17),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      body: StreamBuilder<List<ChildModel>>(
        stream: ChildService.streamChildren(_parentUid!),
        builder: (context, snapshot) {
          final children = snapshot.data ?? [];
          final isLoading =
              snapshot.connectionState == ConnectionState.waiting &&
              children.isEmpty;

          return CustomScrollView(
            slivers: [
              _buildAppBar(children),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: isLoading
                    ? const SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF6C63FF),
                          ),
                        ),
                      )
                    : children.isEmpty
                        ? SliverFillRemaining(
                            child: _buildEmptyState(),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _ChildQuickCard(
                                  child: children[i],
                                  onTap: () => _openDetail(children[i]),
                                ),
                              ),
                              childCount: children.length,
                            ),
                          ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ChildrenManagementScreen(),
          ),
        ),
        backgroundColor: const Color(0xFF6C63FF),
        icon: const Icon(Icons.people_rounded),
        label: const Text(
          'Kelola Anak',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _openDetail(ChildModel child) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChildDetailScreen(child: child)),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar(List<ChildModel> children) {
    final onlineCount = children.where((c) => c.isOnline).length;

    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF0F0E17),
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        // Pairing button
        IconButton(
          icon: const Icon(Icons.qr_code_rounded),
          tooltip: 'Pairing device anak',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PairingGuideScreen()),
          ),
        ),
        // Logout
        IconButton(
          icon: const Icon(Icons.logout_rounded),
          tooltip: 'Keluar',
          onPressed: _logout,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3F4E96), Color(0xFF6C63FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.shield_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selamat datang,',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              _parentEmail?.split('@').first ?? 'Parent',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Summary strip
                  Row(
                    children: [
                      _SummaryChip(
                        icon: Icons.people_rounded,
                        label: '${children.length} anak',
                        sublabel: 'terdaftar',
                      ),
                      const SizedBox(width: 12),
                      _SummaryChip(
                        icon: Icons.circle,
                        iconColor: onlineCount > 0
                            ? const Color(0xFF4CAF50)
                            : Colors.white38,
                        label: '$onlineCount online',
                        sublabel: 'sekarang',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      title: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            const Icon(Icons.sports_esports_rounded,
                color: Color(0xFF6C63FF), size: 20),
            const SizedBox(width: 8),
            const Text(
              'GameBox Parent',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.people_outline_rounded,
            size: 48,
            color: Color(0xFF6C63FF),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Belum Ada Anak Terdaftar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Pair device anak menggunakan QR code atau kode teks,\nlalu kelola waktu bermain mereka dari sini.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PairingGuideScreen()),
            ),
            icon: const Icon(Icons.qr_code_rounded, size: 20),
            label: const Text(
              'Pair Device Anak',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              padding: const EdgeInsets.symmetric(horizontal: 28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── ChildQuickCard ────────────────────────────────────────────────────────────

/// Compact card shown in the parent home list.
/// Streams the child's played time and limit from Firebase for a live mini bar.
class _ChildQuickCard extends StatelessWidget {
  final ChildModel child;
  final VoidCallback onTap;

  const _ChildQuickCard({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: TimeLimitService.streamTodayPlayed(child.id),
      builder: (ctx, playedSnap) {
        final playedSec = playedSnap.data ?? 0;
        final playedMin = playedSec ~/ 60;

        return StreamBuilder<TimeLimitModel?>(
          stream: TimeLimitService.streamLimit(child.id),
          builder: (ctx2, limitSnap) {
            final tl = limitSnap.data;
            final limitMin =
                (tl == null || tl.isUnlimited) ? null : tl.dailyMinutes;
            final progress = limitMin == null || limitMin == 0
                ? 0.0
                : (playedMin / limitMin).clamp(0.0, 1.0);
            final isOverLimit =
                limitMin != null && playedMin >= limitMin;

            return GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isOverLimit
                        ? const Color(0xFFFF5252).withValues(alpha: 0.4)
                        : const Color(0xFF2A2A3E),
                  ),
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _avatarColors(child.id),
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          child.initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Name + progress
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name row
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  child.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Online dot
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: child.isOnline
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFF444466),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                child.isOnline ? 'Online' : 'Offline',
                                style: TextStyle(
                                  color: child.isOnline
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFF666688),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Mini progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: limitMin == null ? 0 : progress,
                              minHeight: 6,
                              backgroundColor: const Color(0xFF2A2A3E),
                              valueColor: AlwaysStoppedAnimation(
                                isOverLimit
                                    ? const Color(0xFFFF5252)
                                    : Color.lerp(
                                        const Color(0xFF43A047),
                                        const Color(0xFFFF9800),
                                        progress,
                                      )!,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Play time text
                          Row(
                            children: [
                              Text(
                                '${_fmt(playedMin)} dimainkan',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              if (limitMin != null) ...[
                                Text(
                                  ' · batas ${_fmt(limitMin)}',
                                  style: TextStyle(
                                    color: isOverLimit
                                        ? const Color(0xFFFF5252)
                                        : const Color(0xFF6C63FF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ] else ...[
                                const Text(
                                  ' · tanpa batas',
                                  style: TextStyle(
                                    color: Color(0xFF666688),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white24,
                      size: 22,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _fmt(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}j' : '${h}j ${m}m';
  }

  List<Color> _avatarColors(String id) {
    final palette = [
      [const Color(0xFF6C63FF), const Color(0xFF9C89FF)],
      [const Color(0xFFFF6584), const Color(0xFFFF8FA0)],
      [const Color(0xFF43A047), const Color(0xFF66BB6A)],
      [const Color(0xFFFF9800), const Color(0xFFFFB74D)],
      [const Color(0xFF00BCD4), const Color(0xFF4DD0E1)],
    ];
    return palette[id.hashCode.abs() % palette.length];
  }
}

// ── SummaryChip ───────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String sublabel;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.sublabel,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor ?? Colors.white70, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
