import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/pin_quest_widget.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/goal.dart';
import '../../services/goal_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/widget_themes.dart';
import '../../widgets/sloth_mascot.dart';
import '../../widgets/goal_heatmap_calendar.dart';
import '../../widgets/note_card.dart';
import 'celebration_screen.dart';

class GoalDetailScreen extends StatefulWidget {
  final String goalId;
  const GoalDetailScreen({super.key, required this.goalId});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  final _noteController = TextEditingController();
  final _linkController = TextEditingController();
  bool _writingNote = false;
  bool _showLinkInput = false;
  bool _saving = false;
  XFile? _pickedImage;

  @override
  void dispose() {
    _noteController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (image != null) setState(() => _pickedImage = image);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the photo picker')),
        );
      }
    }
  }

  Future<void> _changeTheme(Goal goal) async {
    final current = WidgetThemes.byId(goal.themeId);
    final picked = await showModalBottomSheet<WidgetTheme>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose a color', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: WidgetThemes.all.map((theme) {
                final selected = theme.id == current.id;
                return InkWell(
                  onTap: () => Navigator.pop(context, theme),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: theme.gradient,
                          border: selected
                              ? Border.all(color: Colors.white, width: 2.5)
                              : null,
                        ),
                        child: selected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 22)
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(theme.label, style: AppTextStyles.caption),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (picked != null && picked.id != current.id && mounted) {
      await context.read<GoalService>().updateGoal(goal, themeId: picked.id);
    }
  }

  Future<void> _editDailyMinutes(Goal goal) async {
    final controller =
        TextEditingController(text: goal.dailyMinutes.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("Today's Goal", style: AppTextStyles.title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: AppTextStyles.body,
          decoration: const InputDecoration(
              suffixText: 'minutes', hintText: 'Daily target'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              Navigator.pop(context, v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result > 0 && mounted) {
      await context.read<GoalService>().updateGoal(goal, dailyMinutes: result);
    }
  }

  Future<void> _submitCompletion(Goal goal) async {
    final text = _noteController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write a short note about what you learned')),
      );
      return;
    }

    setState(() => _saving = true);
    final outcome = await context.read<GoalService>().completeToday(
          goal,
          text,
          pickedImagePath: _pickedImage?.path,
          linkUrl: _linkController.text,
        );
    setState(() => _saving = false);

    if (!outcome.result.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(outcome.result.errorMessage ?? 'Already done today')),
        );
      }
      return;
    }

    _noteController.clear();
    _linkController.clear();
    setState(() {
      _writingNote = false;
      _showLinkInput = false;
      _pickedImage = null;
    });

    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CelebrationScreen(
            newStreak: outcome.result.newStreak,
            isNewLongest: outcome.result.isNewLongest,
            leveledUp: outcome.result.leveledUp,
            newLevel: outcome.result.newLevel,
            noteText: text,
            newBadges: outcome.newBadges,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final goal = context.watch<GoalService>().goalById(widget.goalId);

    if (goal == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('Goal not found', style: AppTextStyles.body)),
      );
    }

    final doneToday = goal.isCompletedToday;
    final theme = WidgetThemes.byId(goal.themeId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(goal.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_to_home_screen),
            tooltip: 'Add to home screen',
            onPressed: () => pinGoalWidgetWithFeedback(context, goal.id, goal.title),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: AppColors.surfaceLight,
            onSelected: (value) async {
              if (value == 'change_color') {
                await _changeTheme(goal);
              } else if (value == 'delete') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    title: const Text('Delete goal?', style: AppTextStyles.title),
                    content: const Text(
                      'This will permanently remove this goal and all of its notes.',
                      style: AppTextStyles.bodyMuted,
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete',
                            style: TextStyle(color: AppColors.danger)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await context.read<GoalService>().deleteGoal(goal);
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'change_color', child: Text('Change color')),
              const PopupMenuItem(value: 'delete', child: Text('Delete goal')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Center(
              child: Column(
                children: [
                  SlothMascot(
                    size: 110,
                    mood: doneToday ? SlothMood.happy : SlothMood.idle,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 26)),
                      const SizedBox(width: 6),
                      Text(
                        '${goal.streak} ${goal.streak == 1 ? 'day' : 'days'}',
                        style: AppTextStyles.display.copyWith(fontSize: 28),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('Keep it up!', style: AppTextStyles.bodyMuted),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Row(
              children: [
                Expanded(
                  child: _StatChip(
                    label: 'Longest Streak',
                    value: '${goal.longestStreak}',
                    icon: Icons.emoji_events,
                    color: AppColors.flameOrange,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatChip(
                    label: 'Level',
                    value: '${goal.level}',
                    icon: Icons.star,
                    color: theme.mid,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatChip(
                    label: 'XP',
                    value: '${goal.xp}',
                    icon: Icons.bolt,
                    color: AppColors.flameYellow,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Today's Goal row (tap Edit to change target minutes).
            InkWell(
              onTap: () => _editDailyMinutes(goal),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Today's Goal", style: AppTextStyles.caption),
                          const SizedBox(height: 4),
                          Text('${goal.dailyMinutes} minutes',
                              style: AppTextStyles.title),
                        ],
                      ),
                    ),
                    Text('Edit',
                        style: TextStyle(
                            color: theme.mid,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            if (doneToday) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.success.withOpacity(0.4)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle, color: AppColors.success),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "You've completed this goal today. Come back tomorrow!",
                        style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (!_writingNote) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _writingNote = true),
                  icon: const Icon(Icons.check),
                  label: const Text('Complete Today'),
                  style: ElevatedButton.styleFrom(backgroundColor: theme.mid),
                ),
              ),
            ] else ...[
              Text('What did you learn today?', style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _noteController,
                maxLines: 6,
                minLines: 4,
                style: AppTextStyles.body,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '- Learned about EC2\n- Created an instance\n- Understood Security Groups',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              if (_pickedImage != null) ...[
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Image.file(
                        File(_pickedImage!.path),
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: InkWell(
                        onTap: () => setState(() => _pickedImage = null),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              if (_showLinkInput) ...[
                TextField(
                  controller: _linkController,
                  style: AppTextStyles.body,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: 'Paste a link (article, docs, video...)',
                    prefixIcon:
                        const Icon(Icons.link, color: AppColors.textMuted, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close,
                          color: AppColors.textMuted, size: 18),
                      onPressed: () => setState(() {
                        _linkController.clear();
                        _showLinkInput = false;
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              Row(
                children: [
                  TextButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_outlined, size: 18),
                    label: Text(_pickedImage == null ? 'Add Photo' : 'Change Photo'),
                    style: TextButton.styleFrom(foregroundColor: theme.mid),
                  ),
                  if (!_showLinkInput)
                    TextButton.icon(
                      onPressed: () => setState(() => _showLinkInput = true),
                      icon: const Icon(Icons.link, size: 18),
                      label: const Text('Add Link'),
                      style: TextButton.styleFrom(foregroundColor: theme.mid),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : () => _submitCompletion(goal),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: Colors.white),
                        )
                      : const Icon(Icons.check),
                  label: Text(_saving ? 'Saving...' : 'Mark as Done'),
                  style: ElevatedButton.styleFrom(backgroundColor: theme.mid),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),
            Text('Activity', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.sm),
            GoalHeatmapCalendar(notes: goal.notes),

            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Text('Learning Notes', style: AppTextStyles.title),
                const Spacer(),
                Text('${goal.notes.length} entries', style: AppTextStyles.caption),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (goal.notes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(
                  child: Text(
                    'No notes yet. Complete today to add your first one!',
                    style: AppTextStyles.bodyMuted,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...(() {
                final sorted = [...goal.notes]
                  ..sort((a, b) => b.date.compareTo(a.date));
                return sorted.map((note) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: NoteCard(goal: goal, note: note),
                    ));
              })(),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: AppTextStyles.title.copyWith(fontSize: 17)),
          const SizedBox(height: 2),
          Text(label,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
