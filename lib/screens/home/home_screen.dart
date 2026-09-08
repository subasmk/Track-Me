import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/goal_service.dart';
import '../../services/settings_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_utils_x.dart';
import '../../widgets/streak_card.dart';
import '../../widgets/goal_list_card.dart';
import '../../widgets/sloth_mascot.dart';
import '../add_goal/add_goal_screen.dart';
import '../goal_detail/goal_detail_screen.dart';
import '../notes/notes_screen.dart';
import '../quests/quests_screen.dart';
import '../achievements/achievements_screen.dart';
import '../stats/stats_screen.dart';
import '../settings/settings_screen.dart';
import '../social/social_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final goalService = context.watch<GoalService>();
    final settings = context.watch<SettingsService>();
    final goals = goalService.goals;

    // Overall streak shown on the hero card = the longest *current* streak
    // across all goals, so the headline number reflects whichever goal the
    // user is most consistent with right now.
    final overallStreak =
        goals.isEmpty ? 0 : goals.map((g) => g.streak).reduce((a, b) => a > b ? a : b);

    // Which weekdays (Sun=0..Sat=6) this week had at least one goal
    // completed, for the streak card's checkmark strip.
    final week = DateUtilsX.weekDates(DateTime.now());
    final completedIndices = <int>{};
    for (var i = 0; i < 7; i++) {
      final day = week[i];
      final hasCompletion = goals.any(
        (g) => g.notes.any((n) => DateUtilsX.isSameDay(n.date, day)),
      );
      if (hasCompletion) completedIndices.add(i);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                child: _TopBar(userName: settings.userName),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                child: StreakCard(
                  streakDays: overallStreak,
                  userName: settings.userName,
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddGoalScreen()),
        ),
        backgroundColor: AppColors.purpleMid,
        child: const Icon(Icons.add, color: AppColors.textPrimary),
      ),
      bottomNavigationBar: _BottomNav(context),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal widgets
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  final String userName;
  const _TopBar({required this.userName});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hello, $userName 👋', style: AppTextStyles.title),
              Text('Keep the streak alive!',
                  style: AppTextStyles.caption),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.people_outline,
              color: AppColors.textSecondary),
          tooltip: 'Community & Teams',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SocialScreen()),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.emoji_events_outlined,
              color: AppColors.textSecondary),
          tooltip: 'Achievements',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AchievementsScreen()),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined,
              color: AppColors.textSecondary),
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
        const SlothMascot(mood: SlothMood.idle, size: 120),
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
              icon: Icons.groups_rounded,
              label: 'Teams',
              selected: false,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SocialScreen()),
              ),
            ),
            _NavItem(
              icon: Icons.emoji_events_rounded,
              label: 'Badges',
              selected: false,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AchievementsScreen()),
              ),
            ),
            _NavItem(
              icon: Icons.bar_chart_rounded,
              label: 'Stats',
              selected: false,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatsScreen()),
              ),
            ),
          ],
        ),
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
