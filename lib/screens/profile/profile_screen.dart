import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/goal_service.dart';
import '../../services/quest_service.dart';
import '../../services/settings_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../achievements/achievements_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final goalService = context.watch<GoalService>();
    final questService = context.watch<QuestService>();
    final goals = goalService.goals;
    final quests = questService.quests;

    final overallStreak = goals.isEmpty
        ? 0
        : goals.map((g) => g.streak).reduce((a, b) => a > b ? a : b);
    final longestStreak = goals.isEmpty
        ? 0
        : goals.map((g) => g.longestStreak).reduce((a, b) => a > b ? a : b);
    final totalXp = goals.fold<int>(0, (prev, g) => prev + g.xp);
    final level = (totalXp / 100).floor() + 1;
    final levelProgress = (totalXp % 100) / 100.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Username',
            onPressed: () => _showLoginUsernameDialog(context, settings),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Profile Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.purpleMid.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white24,
                          child: Text(
                            settings.userName.isNotEmpty
                                ? settings.userName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Lvl $level',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      settings.userName,
                      style: AppTextStyles.title.copyWith(fontSize: 22),
                    ),
                    Text(
                      '@${settings.userName.toLowerCase().replaceAll(' ', '')}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Level XP Progress
                    Row(
                      children: [
                        Text('Level $level',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const Spacer(),
                        Text('$totalXp XP',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: levelProgress,
                        minHeight: 8,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.flameYellow),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Stats Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatBadge(
                            label: 'Current Streak', value: '🔥 $overallStreak d'),
                        _StatBadge(
                            label: 'Best Streak', value: '🏆 $longestStreak d'),
                        _StatBadge(
                            label: 'Active Tasks',
                            value: '🎯 ${goals.length + quests.length}'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Account & Username Setup Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.purpleLight,
                    side: const BorderSide(color: AppColors.surfaceBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.person_pin_rounded),
                  label: const Text('Change Username / Account'),
                  onPressed: () => _showLoginUsernameDialog(context, settings),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Badges Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Unlocked Badges',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AchievementsScreen()),
                    ),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              if (goalService.allUnlockedAchievements.isEmpty)
                const Card(
                  color: AppColors.surface,
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text(
                        'Complete daily goals and quests to unlock badges!',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: goalService.allUnlockedAchievements
                      .map((a) => Chip(
                            avatar: Icon(a.icon, color: a.color, size: 18),
                            label: Text(a.title),
                            backgroundColor: AppColors.surface,
                            side:
                                const BorderSide(color: AppColors.surfaceBorder),
                          ))
                      .toList(),
                ),

              const SizedBox(height: AppSpacing.lg),

              // My Tasks Overview
              Text('My Active Tasks',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.xs),
              if (goals.isEmpty && quests.isEmpty)
                const Card(
                  color: AppColors.surface,
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text('No active tasks added yet.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              else ...[
                ...goals.map((g) => Card(
                      color: AppColors.surface,
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        leading: Text(g.emoji,
                            style: const TextStyle(fontSize: 24)),
                        title: Text(g.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            'Goal • ${g.dailyMinutes} min/day • 🔥 ${g.streak}d streak'),
                        trailing: Icon(
                          g.isCompletedToday
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: g.isCompletedToday
                              ? AppColors.success
                              : AppColors.textMuted,
                        ),
                      ),
                    )),
                ...quests.map((q) => Card(
                      color: AppColors.surface,
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        leading: Text(q.emoji,
                            style: const TextStyle(fontSize: 24)),
                        title: Text(q.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            'Quest • ${q.type} • 🔥 ${q.streak}d streak'),
                        trailing: Icon(
                          q.isCompletedToday
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: q.isCompletedToday
                              ? AppColors.success
                              : AppColors.textMuted,
                        ),
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static void _showLoginUsernameDialog(
      BuildContext context, SettingsService settings) {
    final controller = TextEditingController(text: settings.userName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Set Your Username'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your username so friends can search your public profile, copy your tasks, and collaborate on team streaks!',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: AppTextStyles.body,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purpleMid,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await settings.setUserName(newName);
                if (context.mounted) {
                  context.read<GoalService>().setUserName(newName);
                  context.read<SupabaseService>().updateUsername(newName);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logged in as @$newName! 🎉')),
                  );
                }
              }
            },
            child: const Text('Save Username'),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  const _StatBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        const SizedBox(height: 2),
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}
