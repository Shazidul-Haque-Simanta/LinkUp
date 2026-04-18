import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:project_v2/services/firebase_service.dart';
import 'package:project_v2/shared/widgets/user_avatar.dart';

class TopContributorsScreen extends StatefulWidget {
  const TopContributorsScreen({super.key});

  @override
  State<TopContributorsScreen> createState() => _TopContributorsScreenState();
}

class _TopContributorsScreenState extends State<TopContributorsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  late Future<List<ContributorModel>> _future;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _future = _firebaseService.getTopContributors(limit: 50);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  // ── Level colours & gradients ──────────────────────────────────────────────

  static const Map<ContributorLevel, List<Color>> _levelGradients = {
    ContributorLevel.legend:   [Color(0xFFFF6B6B), Color(0xFFFFD700)],
    ContributorLevel.diamond:  [Color(0xFF00D2FF), Color(0xFF7B2FBE)],
    ContributorLevel.platinum: [Color(0xFFB8C6DB), Color(0xFFF5F7FA)],
    ContributorLevel.gold:     [Color(0xFFFFD700), Color(0xFFFF8C00)],
    ContributorLevel.silver:   [Color(0xFF9E9E9E), Color(0xFFBDBDBD)],
    ContributorLevel.bronze:   [Color(0xFFCD7F32), Color(0xFFA0522D)],
  };

  static const Map<ContributorLevel, String> _levelEmoji = {
    ContributorLevel.legend:   '🏆',
    ContributorLevel.diamond:  '💎',
    ContributorLevel.platinum: '🔷',
    ContributorLevel.gold:     '🥇',
    ContributorLevel.silver:   '🥈',
    ContributorLevel.bronze:   '🥉',
  };

  Color _levelPrimary(ContributorLevel level) =>
      _levelGradients[level]!.first;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D1A) : const Color(0xFFF4F6FF),
      body: FutureBuilder<List<ContributorModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoading();
          }
          if (snapshot.hasError) {
            return _buildError(snapshot.error.toString());
          }
          final contributors = snapshot.data ?? [];
          if (contributors.isEmpty) {
            return _buildEmpty();
          }
          return _buildContent(contributors, isDark);
        },
      ),
    );
  }

  Widget _buildContent(List<ContributorModel> contributors, bool isDark) {
    final top3 = contributors.take(3).toList();
    final rest = contributors.skip(3).toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── App Bar ─────────────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          stretch: true,
          backgroundColor: isDark ? const Color(0xFF0D0D1A) : const Color(0xFF1A1A2E),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          flexibleSpace: FlexibleSpaceBar(
            stretchModes: const [StretchMode.zoomBackground],
            background: _buildHeroHeader(isDark),
          ),
        ),

        // ── Podium (top 3) ───────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: _buildPodium(top3),
          ).animate().fade(duration: 600.ms).slideY(begin: 0.2, curve: Curves.easeOutQuad),
        ),

        // ── Section label ────────────────────────────────────────────────────
        if (rest.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF00D2FF)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Other Contributors',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Ranked list ──────────────────────────────────────────────────────
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final c = rest[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _buildListTile(c, index + 4, isDark),
              )
                  .animate(delay: (50 * index).ms)
                  .fade(duration: 400.ms)
                  .slideX(begin: 0.15, curve: Curves.easeOut);
            },
            childCount: rest.length,
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  // ── Hero header ─────────────────────────────────────────────────────────────

  Widget _buildHeroHeader(bool isDark) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6C63FF).withOpacity(0.12),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Text('🏆', style: TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Top Contributors',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ranked by uploads • followers • rating',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Level legend row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ContributorLevel.values.map((lvl) {
                        final colors = _levelGradients[lvl]!;
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: colors),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: colors.first.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '${_levelEmoji[lvl]} ${_levelNameStr(lvl)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _levelNameStr(ContributorLevel lvl) {
    switch (lvl) {
      case ContributorLevel.legend:   return 'Legend';
      case ContributorLevel.diamond:  return 'Diamond';
      case ContributorLevel.platinum: return 'Platinum';
      case ContributorLevel.gold:     return 'Gold';
      case ContributorLevel.silver:   return 'Silver';
      case ContributorLevel.bronze:   return 'Bronze';
    }
  }

  // ── Podium ──────────────────────────────────────────────────────────────────

  Widget _buildPodium(List<ContributorModel> top3) {
    // Arrange: 2nd | 1st | 3rd
    final arrangement = <int>[]; // indices into top3
    final heights = <double>[];

    if (top3.length == 1) {
      arrangement.addAll([0]);
      heights.addAll([140.0]);
    } else if (top3.length == 2) {
      arrangement.addAll([1, 0]);
      heights.addAll([100.0, 140.0]);
    } else {
      arrangement.addAll([1, 0, 2]);
      heights.addAll([100.0, 140.0, 80.0]);
    }

    final rankLabels = [2, 1, 3];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(arrangement.length, (i) {
        final idx = arrangement[i];
        final c = top3[idx];
        final rank = rankLabels[i];
        final h = heights[i];
        return Expanded(
          child: _buildPodiumColumn(c, rank, h),
        );
      }),
    );
  }

  Widget _buildPodiumColumn(ContributorModel c, int rank, double podiumHeight) {
    final colors = _levelGradients[c.level]!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFirst = rank == 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown / rank badge
        if (isFirst)
          const Text('👑', style: TextStyle(fontSize: 26))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .then(delay: 200.ms)
              .scaleXY(begin: 1.0, end: 1.15, duration: 800.ms, curve: Curves.easeInOut),
        const SizedBox(height: 4),
        // Avatar with glow
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colors.first.withOpacity(0.5),
                blurRadius: isFirst ? 20 : 12,
                spreadRadius: isFirst ? 2 : 0,
              ),
            ],
            gradient: LinearGradient(colors: colors),
          ),
          padding: const EdgeInsets.all(2.5),
          child: CircleAvatar(
            radius: isFirst ? 36 : 28,
            backgroundColor: isDark ? const Color(0xFF0D0D1A) : Colors.white,
            child: UserAvatar(
              imageUrl: c.user.profileImage,
              initial: c.user.name.isNotEmpty ? c.user.name[0].toUpperCase() : '?',
              radius: isFirst ? 34 : 26,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Name
        Text(
          c.user.name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isFirst ? 14 : 12,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 4),
        // Level badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_levelEmoji[c.level]} ${c.levelName}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Score
        Text(
          '${c.score.toStringAsFixed(0)} pts',
          style: TextStyle(
            fontSize: 11,
            color: _levelPrimary(c.level),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        // Podium block
        Container(
          height: podiumHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.first.withOpacity(0.85),
                colors.last.withOpacity(0.6),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w900,
                fontSize: isFirst ? 28 : 22,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── List tile (rank 4+) ──────────────────────────────────────────────────────

  Widget _buildListTile(ContributorModel c, int rank, bool isDark) {
    // Standard Bench Color (Slate/Grey) for non-podium contributors
    final Color benchColor = isDark ? Colors.blueGrey.shade400 : Colors.blueGrey.shade700;
    final Color benchBorderColor = benchColor.withOpacity(0.2);
    final Color benchShadowColor = benchColor.withOpacity(isDark ? 0.05 : 0.03);

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1A2E).withOpacity(0.8)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: benchBorderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: benchShadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Rank number
            SizedBox(
              width: 30,
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark
                      ? Colors.white.withOpacity(0.5)
                      : Colors.black.withOpacity(0.35),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Avatar
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: benchColor.withOpacity(0.1),
                border: Border.all(color: benchBorderColor, width: 1),
              ),
              padding: const EdgeInsets.all(2),
              child: UserAvatar(
                imageUrl: c.user.profileImage,
                initial: c.user.name.isNotEmpty ? c.user.name[0].toUpperCase() : '?',
                radius: 22,
              ),
            ),
            const SizedBox(width: 12),
            // Name + dept
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.user.department,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white.withOpacity(0.45)
                          : Colors.black.withOpacity(0.45),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Level badge + score
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Still show the tier emoji and name, but in a neutral badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: benchColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: benchBorderColor, width: 0.5),
                  ),
                  child: Text(
                    '${_levelEmoji[c.level]} ${c.levelName}',
                    style: TextStyle(
                      color: benchColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${c.score.toStringAsFixed(0)} pts',
                  style: TextStyle(
                    fontSize: 11,
                    color: benchColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── States ─────────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Top Contributors',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFFFFD700),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Calculating scores…',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text('Oops! Something went wrong.',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(error,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4), fontSize: 12)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => setState(() {
                  _future = _firebaseService.getTopContributors(limit: 50);
                }),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Top Contributors',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text('No contributors yet.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6), fontSize: 16)),
            const SizedBox(height: 8),
            Text('Upload resources to appear here!',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.35), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
