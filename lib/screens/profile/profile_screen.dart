import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/goal_service.dart';
import '../../services/quest_service.dart';
import '../../services/settings_service.dart';
import '../../services/supabase_service.dart';
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

    const bgDark = Color(0xFF070D18);
    const cardColor = Color(0xFF101B2E);
    const borderColor = Color(0xFF1A2A44);
    const accentBlue = Color(0xFF2E86DE);
    const fireOrange = Color(0xFFFF6A00);
    const textMuted = Color(0xFF8B9CB3);

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
          '@${settings.userName.toLowerCase().replaceAll(' ', '')}',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note, color: Colors.white),
            tooltip: 'Edit Profile',
            onPressed: () => _showEditProfileDialog(context, settings),
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
                GestureDetector(
                  onTap: () => _pickProfileImage(context, settings),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: cardColor,
                        backgroundImage: settings.photoPath != null
                            ? FileImage(File(settings.photoPath!))
                            : null,
                        child: settings.photoPath == null
                            ? Text(
                                settings.userName.isNotEmpty
                                    ? settings.userName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: accentBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHeaderStat('$totalTasks', 'Tasks'),
                      _buildHeaderStat('$totalFriends', 'Friends'),
                      _buildHeaderStat('🔥 $overallStreak', 'Streak'),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Bio & Level
            Text(settings.fullName,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            Text('@${settings.userName.toLowerCase().replaceAll(' ', '')}',
                style: const TextStyle(color: textMuted, fontSize: 13)),
            const SizedBox(height: 4),
            Text(settings.bio,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 12),

            // Level Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: levelProgress,
                backgroundColor: cardColor,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFFFB020)),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Level $level',
                    style: const TextStyle(color: textMuted, fontSize: 12)),
                Text('$totalXp XP',
                    style: const TextStyle(color: textMuted, fontSize: 12)),
              ],
            ),

            const SizedBox(height: 16),

            // Highest Streak Highlight Card
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Highest Streak',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  Row(
                    children: [
                      Text('$longestStreak Days',
                          style: const TextStyle(
                              color: fireOrange,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(width: 4),
                      const Icon(Icons.local_fire_department,
                          color: fireOrange, size: 20),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Tasks Section
            const Text('TASKS',
                style: TextStyle(
                    color: textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1)),
            const SizedBox(height: 12),
            if (goals.isEmpty && quests.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: const Center(
                  child: Text('No active tasks added yet.',
                      style: TextStyle(color: textMuted)),
                ),
              )
            else
              Row(
                children: [
                  if (goals.isNotEmpty)
                    Expanded(
                        child: _buildTaskCard(
                            goals[0].title,
                            '${goals[0].streak}',
                            cardColor,
                            borderColor,
                            fireOrange)),
                  if (goals.length > 1) ...[
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildTaskCard(
                            goals[1].title,
                            '${goals[1].streak}',
                            cardColor,
                            borderColor,
                            fireOrange)),
                  ],
                  if (quests.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildTaskCard(
                            quests[0].title,
                            '${quests[0].streak}',
                            cardColor,
                            borderColor,
                            fireOrange)),
                  ],
                ],
              ),
            Center(
              child: TextButton(
                onPressed: () {},
                child: const Text('View more',
                    style: TextStyle(color: accentBlue, fontSize: 13)),
              ),
            ),

            const SizedBox(height: 16),

            // Medals Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('MEDALS',
                    style: TextStyle(
                        color: textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1)),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AchievementsScreen()),
                  ),
                  child: const Text('View All',
                      style: TextStyle(color: accentBlue, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
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
                children: [
                  _MedalPill(
                      icon: Icons.star_rounded,
                      color: const Color(0xFFFFB703),
                      unlocked: level >= 1),
                  _MedalPill(
                      icon: Icons.shield,
                      color: const Color(0xFF38B6FF),
                      unlocked: totalTasks >= 1),
                  _MedalPill(
                      icon: Icons.emoji_events,
                      color: const Color(0xFFFFB703),
                      unlocked: overallStreak >= 3),
                  _MedalPill(
                      icon: Icons.local_fire_department,
                      color: const Color(0xFFFF6A00),
                      unlocked: overallStreak >= 7),
                  _MedalPill(
                      icon: Icons.lock,
                      color: textMuted,
                      unlocked: overallStreak >= 14),
                  _MedalPill(
                      icon: Icons.lock,
                      color: textMuted,
                      unlocked: overallStreak >= 30),
                  _MedalPill(
                      icon: Icons.lock,
                      color: textMuted,
                      unlocked: level >= 5),
                  _MedalPill(
                      icon: Icons.lock,
                      color: textMuted,
                      unlocked: level >= 10),
                ],
              ),
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
        Text(count,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Color(0xFF8B9CB3), fontSize: 12)),
      ],
    );
  }

  static Widget _buildTaskCard(String title, String count, Color cardColor,
      Color borderColor, Color fireOrange) {
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
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
              const Icon(Icons.copy_rounded,
                  color: Color(0xFF8B9CB3), size: 14),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(count,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const SizedBox(width: 4),
              Icon(Icons.local_fire_department, color: fireOrange, size: 16),
            ],
          ),
        ],
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
        backgroundColor: const Color(0xFF101B2E),
        title:
            const Text('Edit Profile', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: TextStyle(color: Color(0xFF8B9CB3))),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: usernameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Username',
                  labelStyle: TextStyle(color: Color(0xFF8B9CB3)),
                  prefixIcon:
                      Icon(Icons.alternate_email, color: Color(0xFF8B9CB3)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bioCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Bio',
                    labelStyle: TextStyle(color: Color(0xFF8B9CB3))),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF8B9CB3))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E86DE),
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

class _MedalPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool unlocked;

  const _MedalPill(
      {required this.icon, required this.color, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: unlocked
            ? color.withValues(alpha: 0.12)
            : const Color(0xFF0A111E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked
              ? color.withValues(alpha: 0.4)
              : const Color(0xFF1A2A44),
        ),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}
