import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../services/goal_service.dart';
import '../../services/progression_service.dart';
import '../../services/quest_service.dart';
import '../../utils/app_clock.dart';
import '../../widgets/system_ui.dart';
import '../../services/settings_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_utils_x.dart';
import '../../widgets/streak_card.dart';
import '../../widgets/goal_list_card.dart';
import '../../widgets/sloth_sticker.dart';
import '../add_goal/add_goal_screen.dart';
import '../goal_detail/goal_detail_screen.dart';
import '../notes/notes_screen.dart';
import '../quests/quests_screen.dart';
import '../achievements/achievements_screen.dart';
import '../settings/settings_screen.dart';
import '../social/search_friends_screen.dart';
import '../profile/profile_screen.dart';
import '../quests/add_quest_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final goalService = context.watch<GoalService>();
    final settings = context.watch<SettingsService>();
    final goals = goalService.goals;

    final quests = context.watch<QuestService>().quests;
    final progression = context.watch<ProgressionService>();
    final now = AppClock.now();

    // Headline streak = the best *current* streak across goals and quests.
    final current = [...goals.map((g) => g.streak), ...quests.map((q) => q.streak)];
    final bests = [...goals.map((g) => g.longestStreak), ...quests.map((q) => q.longestStreak)];
    final overallStreak = current.isEmpty ? 0 : current.reduce((a, b) => a > b ? a : b);
    final bestStreak = bests.isEmpty ? 0 : bests.reduce((a, b) => a > b ? a : b);
    final doneToday = goals.any((g) => g.isCompletedToday) || quests.any((q) => q.isCompletedToday);
    final hadHistory = bestStreak > 0;

    // Days this week (Sun=0..Sat=6) with at least one goal or quest done.
    final week = DateUtilsX.weekDates(now);
    final completedIndices = <int>{};
    for (var i = 0; i < 7; i++) {
      final day = week[i];
      final hit = goals.any((g) => g.notes.any((n) => DateUtilsX.isSameDay(n.date, day))) ||
          quests.any((q) => q.completionHistory.any((d) => DateUtilsX.isSameDay(d, day)));
      if (hit) completedIndices.add(i);
    }

    return Scaffold(
      backgroundColor: SysColors.bg,
      body: SysBackground(child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                child: _TopBar(settings: settings, level: progression.level),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                child: StreakCard(
                  streakDays: overallStreak,
                  bestStreak: bestStreak,
                  doneToday: doneToday,
                  hadHistory: hadHistory,
                  completedWeekdayIndices: completedIndices,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
                child: _TodaySummary(
                  completed: goalService.completedTodayCount,
                  total: goalService.totalGoalsCount,
                ),
              ),
            ),
            if (goals.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  onCreateGoal: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddGoalScreen()),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final goal = goals[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: GoalListCard(
                          goal: goal,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  GoalDetailScreen(goalId: goal.id),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: goals.length,
                  ),
                ),
              ),
            // Bottom nav spacer
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      )),
      bottomNavigationBar: _BottomNav(context),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal widgets
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  final SettingsService settings;
  final int level;
  const _TopBar({required this.settings, required this.level});

  String get _greeting {
    final h = AppClock.now().hour;
    return h < 12 ? 'GOOD MORNING' : h < 17 ? 'GOOD AFTERNOON' : 'GOOD EVENING';
  }

  @override
  Widget build(BuildContext context) {
    final photo = settings.photoPath;
    final hasPhoto = photo != null && File(photo).existsSync();
    final name = settings.fullName.isNotEmpty && settings.fullName != 'Daily Tracker'
        ? settings.fullName
        : settings.userName;
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: SysColors.cyan, width: 1.5),
              boxShadow: [BoxShadow(color: SysColors.cyan.withValues(alpha: 0.35), blurRadius: 10)],
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: SysColors.panelTop,
              backgroundImage: hasPhoto ? FileImage(File(photo)) : null,
              child: hasPhoto
                  ? null
                  : Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: SysText.header.copyWith(fontSize: 18, letterSpacing: 0)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting, style: SysText.label.copyWith(fontSize: 10)),
              const SizedBox(height: 2),
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SysText.body.copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
              Text('LV $level  ·  RANK ${SysRank.rank(level)}',
                  style: SysText.label.copyWith(color: SysColors.cyan, fontSize: 10)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.search_rounded,
              color: SysColors.cyanSoft),
          tooltip: 'Search & Friends',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SearchFriendsScreen()),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.emoji_events_outlined,
              color: SysColors.cyanSoft),
          tooltip: 'Badges',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AchievementsScreen()),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined,
              color: SysColors.cyanSoft),
          tooltip: 'Settings',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }
}

class _TodaySummary extends StatelessWidget {
  final int completed;
  final int total;
  const _TodaySummary({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text("Today's Goals", style: AppTextStyles.headline),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '$completed / $total done',
            style: AppTextStyles.caption.copyWith(
              color: completed == total && total > 0
                  ? AppColors.success
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateGoal;
  const _EmptyState({required this.onCreateGoal});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SlothStickerView(sticker: SlothSticker.sleepy, size: 130, glow: false),
        const SizedBox(height: AppSpacing.md),
        Text('No goals yet', style: AppTextStyles.title),
        const SizedBox(height: 6),
        Text(
          'Add your first goal to start building\na daily habit streak.',
          style: AppTextStyles.bodyMuted,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        ElevatedButton.icon(
          onPressed: onCreateGoal,
          icon: const Icon(Icons.add),
          label: const Text('Add First Goal'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.purpleMid,
            foregroundColor: AppColors.textPrimary,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom nav
// ---------------------------------------------------------------------------

Widget _BottomNav(BuildContext context) {
  return Container(
    decoration: BoxDecoration(
      color: AppColors.backgroundElevated,
      border: const Border(
        top: BorderSide(color: AppColors.surfaceBorder, width: 1),
      ),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              selected: true,
              onTap: () {},
            ),
            _NavItem(
              icon: Icons.menu_book_rounded,
              label: 'Notes',
              selected: false,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotesScreen()),
              ),
            ),
            // Center + Create Button
            GestureDetector(
              onTap: () => _showCreateModal(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.purpleMid,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
              ),
            ),
            _NavItem(
              icon: Icons.shield_rounded,
              label: 'Quests',
              selected: false,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QuestsScreen()),
              ),
            ),
            _NavItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              selected: false,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showCreateModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Create New Task', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.purpleMid,
              child: Icon(Icons.track_changes_rounded, color: Colors.white),
            ),
            title: const Text('Add Single Goal', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Create a daily habit with minutes target'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddGoalScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.orangeAccent,
              child: Icon(Icons.shield_rounded, color: Colors.white),
            ),
            title: const Text('Add Structured Quest', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Create a quest with multiple sub-goals'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddQuestScreen()),
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.purpleLight : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
