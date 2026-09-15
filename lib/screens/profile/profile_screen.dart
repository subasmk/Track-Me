import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
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
    final supabase = context.watch<SupabaseService>();
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
    final totalTasks = goals.length + quests.length;
    final totalFriends = supabase.friendsList.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('@${settings.userName.toLowerCase().replaceAll(' ', '')}'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            tooltip: 'Edit Profile',
            onPressed: () => _showEditProfileDialog(context, settings),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instagram-style Profile Header Row
              Row(
                children: [
                  // Profile Photo Avatar
                  GestureDetector(
                    onTap: () => _pickProfileImage(context, settings),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: AppColors.purpleMid,
                          backgroundImage: settings.photoPath != null
                              ? FileImage(File(settings.photoPath!))
                              : null,
                          child: settings.photoPath == null
                              ? Text(
                                  settings.userName.isNotEmpty
                                      ? settings.userName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.purpleLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 14, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // Stats Row (Tasks, Friends, Streaks, XP)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _InstaStatItem(count: '$totalTasks', label: 'Tasks'),
                        _InstaStatItem(count: '$totalFriends', label: 'Friends'),
                        _InstaStatItem(count: '🔥 $overallStreak', label: 'Streak'),
                        _InstaStatItem(count: 'Lvl $level', label: '$totalXp XP'),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              // Name, Handle & Bio Block
              Text(
                settings.fullName,
                style: AppTextStyles.title.copyWith(fontSize: 18),
              ),
              Text(
                '@${settings.userName.toLowerCase().replaceAll(' ', '')}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                settings.bio,
                style: AppTextStyles.body.copyWith(fontSize: 14),
              ),

              const SizedBox(height: AppSpacing.md),

              // Level Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: levelProgress,
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceBorder,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.flameYellow),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('Level $level',
                      style: AppTextStyles.caption
                          .copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('$totalXp XP', style: AppTextStyles.caption),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Action Buttons Row (Edit Profile + Share Profile)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.surfaceBorder),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit Profile'),
                      onPressed: () => _showEditProfileDialog(context, settings),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Badges Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Badges & Trophies',
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

              // Active Tasks Grid / List Overview
              Text('My Active Tasks ($totalTasks)',
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

  static Future<void> _pickProfileImage(
      BuildContext context, SettingsService settings) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      await settings.updateProfile(
        fullName: settings.fullName,
        bio: settings.bio,
        photoPath: picked.path,
      );
    }
  }

  static void _showEditProfileDialog(
      BuildContext context, SettingsService settings) {
    final nameCtrl = TextEditingController(text: settings.fullName);
    final usernameCtrl = TextEditingController(text: settings.userName);
    final bioCtrl = TextEditingController(text: settings.bio);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: AppTextStyles.body,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: usernameCtrl,
                style: AppTextStyles.body,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bioCtrl,
                style: AppTextStyles.body,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Bio'),
              ),
            ],
          ),
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
              final newUsername = usernameCtrl.text.trim();
              if (newUsername.isNotEmpty) {
                await settings.setUserName(newUsername);
                await settings.updateProfile(
                  fullName: nameCtrl.text.trim(),
                  bio: bioCtrl.text.trim(),
                );
                if (context.mounted) {
                  context.read<GoalService>().setUserName(newUsername);
                  context.read<SupabaseService>().updateUsername(newUsername);
                  Navigator.pop(ctx);
                }
              }
            },
            child: const Text('Save Profile'),
          ),
        ],
      ),
    );
  }
}

class _InstaStatItem extends StatelessWidget {
  final String count;
  final String label;
  const _InstaStatItem({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
