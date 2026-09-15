import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/public_profile.dart';
import '../../services/supabase_service.dart';
import '../../services/goal_service.dart';
import '../../services/quest_service.dart';

class PublicProfileScreen extends StatelessWidget {
  final PublicProfile profile;

  const PublicProfileScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final supabase = context.watch<SupabaseService>();
    final isFriend = supabase.friendsList.contains(profile.username);
    final isSelf = supabase.currentUsername.toLowerCase() == profile.username.toLowerCase();

    const bgDark = Color(0xFF070D18);
    const cardColor = Color(0xFF101B2E);
    const borderColor = Color(0xFF1A2A44);
    const accentBlue = Color(0xFF2E86DE);
    const fireOrange = Color(0xFFFF6A00);
    const textMuted = Color(0xFF8B9CB3);

    final levelProgress = (profile.xp % 100) / 100.0;

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '@${profile.username.toLowerCase().replaceAll(' ', '')}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (!isSelf)
            IconButton(
              icon: Icon(isFriend ? Icons.person_remove : Icons.person_add, color: Colors.white),
              tooltip: isFriend ? 'Remove Friend' : 'Add Friend',
              onPressed: () {
                if (isFriend) {
                  supabase.removeFriend(profile.username);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Removed ${profile.username} from friends.')),
                  );
                } else {
                  supabase.addFriend(profile.username);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added ${profile.username} as friend! 🎉')),
                  );
                }
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar + Stats
            Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: cardColor,
                  child: Text(
                    profile.username.isNotEmpty ? profile.username[0].toUpperCase() : 'U',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHeaderStat('${profile.mainTasks.length}', 'Tasks'),
                      _buildHeaderStat(isFriend ? '1' : '0', 'Following'),
                      _buildHeaderStat(isFriend ? '1' : '0', 'Followers'),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Bio & Level
            Text(profile.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text('@${profile.username.toLowerCase().replaceAll(' ', '')}', style: const TextStyle(color: textMuted, fontSize: 13)),
            const SizedBox(height: 4),
            const Text('Building consistency day by day 🔥', style: TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 12),

            // Level Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: levelProgress > 0 ? levelProgress : 0.15,
                backgroundColor: cardColor,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFB020)),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Level ${profile.level}', style: const TextStyle(color: textMuted, fontSize: 12)),
                Text('${profile.xp} XP', style: const TextStyle(color: textMuted, fontSize: 12)),
              ],
            ),

            const SizedBox(height: 16),

            // Highest Streak Highlight Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Highest Streak', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  Row(
                    children: [
                      Text('${profile.longestStreak} Days', style: const TextStyle(color: fireOrange, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 4),
                      const Icon(Icons.local_fire_department, color: fireOrange, size: 20),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Tasks Section
            const Text('TASKS', style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
            const SizedBox(height: 12),
            if (profile.mainTasks.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: const Center(
                  child: Text('No public tasks shared.', style: TextStyle(color: textMuted)),
                ),
              )
            else
              Row(
                children: [
                  for (var i = 0; i < profile.mainTasks.length && i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          final goalService = context.read<GoalService>();
                          final questService = context.read<QuestService>();
                          supabase.copyTaskToLocal(
                            task: profile.mainTasks[i],
                            goalService: goalService,
                            questService: questService,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Copied "${profile.mainTasks[i].title}" to your tasks! 🎉')),
                          );
                        },
                        child: _buildTaskCard(
                          profile.mainTasks[i].title,
                          '${profile.mainTasks[i].streak}',
                          cardColor,
                          borderColor,
                          fireOrange,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            Center(
              child: TextButton(
                onPressed: () {},
                child: const Text('View more', style: TextStyle(color: accentBlue, fontSize: 13)),
              ),
            ),

            const SizedBox(height: 16),

            // Medals Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('MEDALS', style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                const Text('View All', style: TextStyle(color: accentBlue, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final unlockedList = <Widget>[];
                if (profile.level >= 1) {
                  unlockedList.add(const _MedalPill(icon: Icons.star_rounded, color: Color(0xFFFFB703), unlocked: true));
                }
                if (profile.mainTasks.isNotEmpty) {
                  unlockedList.add(const _MedalPill(icon: Icons.shield, color: Color(0xFF38B6FF), unlocked: true));
                }
                if (profile.currentStreak >= 3) {
                  unlockedList.add(const _MedalPill(icon: Icons.emoji_events, color: Color(0xFFFFB703), unlocked: true));
                }
                if (profile.currentStreak >= 7) {
                  unlockedList.add(const _MedalPill(icon: Icons.local_fire_department, color: Color(0xFFFF6A00), unlocked: true));
                }
                if (profile.currentStreak >= 14) {
                  unlockedList.add(const _MedalPill(icon: Icons.whatshot, color: Color(0xFFFF7043), unlocked: true));
                }
                if (profile.currentStreak >= 30) {
                  unlockedList.add(const _MedalPill(icon: Icons.military_tech, color: Color(0xFFFFD54F), unlocked: true));
                }

                if (unlockedList.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: const Center(
                      child: Text('No medals unlocked yet.', style: TextStyle(color: textMuted)),
                    ),
                  );
                }

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    children: unlockedList,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static Widget _buildHeaderStat(String count, String label) {
    return Column(
      children: [
        Text(count, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Color(0xFF8B9CB3), fontSize: 12)),
      ],
    );
  }

  static Widget _buildTaskCard(String title, String count, Color cardColor, Color borderColor, Color fireOrange) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const Icon(Icons.copy_rounded, color: Color(0xFF8B9CB3), size: 14),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(count, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 4),
              Icon(Icons.local_fire_department, color: fireOrange, size: 16),
            ],
          ),
        ],
      ),
    );
  }
}

class _MedalPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool unlocked;

  const _MedalPill({required this.icon, required this.color, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: unlocked ? color.withValues(alpha: 0.12) : const Color(0xFF0A111E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked ? color.withValues(alpha: 0.4) : const Color(0xFF1A2A44),
        ),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}
