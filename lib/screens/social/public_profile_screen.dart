import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/public_profile.dart';
import '../../services/supabase_service.dart';
import '../../services/goal_service.dart';
import '../../services/quest_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class PublicProfileScreen extends StatelessWidget {
  final PublicProfile profile;

  const PublicProfileScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final supabase = context.watch<SupabaseService>();
    final isFriend = supabase.friendsList.contains(profile.username);
    final isSelf = supabase.currentUsername.toLowerCase() == profile.username.toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: Text('@${profile.username}'),
        centerTitle: true,
        actions: [
          if (!isSelf)
            IconButton(
              icon: Icon(isFriend ? Icons.person_remove : Icons.person_add),
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
                    SnackBar(content: Text('Added ${profile.username} as friend!')),
                  );
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card Header
            Card(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.purpleMid,
                      child: Text(
                        profile.username.isNotEmpty ? profile.username[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      profile.username,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Level ${profile.level} • ${profile.xp} XP',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatTile(context, '🔥 Streak', '${profile.currentStreak} days'),
                        _buildStatTile(context, '🏆 Best Streak', '${profile.longestStreak} days'),
                        _buildStatTile(context, '🎖️ Badges', '${profile.badges.length}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Badges Section
            Text('Badges & Achievements', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.xs),
            if (profile.badges.isEmpty)
              const Text('No badges earned yet.', style: TextStyle(color: AppColors.textSecondary))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: profile.badges.map((b) => Chip(
                  avatar: const Text('🏅'),
                  label: Text(b.replaceAll('_', ' ').toUpperCase()),
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.surfaceBorder),
                )).toList(),
              ),
            const SizedBox(height: AppSpacing.lg),

            // Main Tasks & Quests Section
            Text('Main Tasks & Quests', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.xs),
            if (profile.mainTasks.isEmpty)
              const Text('No public tasks shared.', style: TextStyle(color: AppColors.textSecondary))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: profile.mainTasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final task = profile.mainTasks[index];
                  return Card(
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: Text(task.emoji, style: const TextStyle(fontSize: 28)),
                      title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        task.type == 'quest'
                            ? 'Quest • ${task.items.length} sub-tasks • 🔥 ${task.streak}d'
                            : 'Goal • ${task.dailyMinutes} mins/day • 🔥 ${task.streak}d',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      trailing: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.purpleMid,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy'),
                        onPressed: () {
                          final goalService = context.read<GoalService>();
                          final questService = context.read<QuestService>();
                          supabase.copyTaskToLocal(
                            task: task,
                            goalService: goalService,
                            questService: questService,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Copied "${task.title}" to your tasks!')),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}
