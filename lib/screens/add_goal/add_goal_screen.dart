import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/goal_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/widget_themes.dart';

const List<String> _emojiOptions = [
  '☁️', '🧮', '📐', '💙', '🔷', '🌊', '⚡', '🧠',
  '📚', '💻', '🎯', '🚀', '🔥', '🧩', '🛠️', '📊',
  '🐍', '☕', '🎨', '🗣️', '🏋️', '📝', '🔬', '🎵',
];

class AddGoalScreen extends StatefulWidget {
  /// Pre-fill values (e.g. from the AI assistant). Nothing is saved until
  /// the user taps Create.
  final String? initialTitle;
  final String? initialEmoji;
  final int? initialMinutes;
  const AddGoalScreen({super.key, this.initialTitle, this.initialEmoji, this.initialMinutes});

  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  final _titleController = TextEditingController();
  String _selectedEmoji = _emojiOptions.first;
  WidgetTheme _selectedTheme = WidgetThemes.purple;
  double _dailyMinutes = 30;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle != null) _titleController.text = widget.initialTitle!;
    if (widget.initialEmoji != null) _selectedEmoji = widget.initialEmoji!;
    if (widget.initialMinutes != null) _dailyMinutes = widget.initialMinutes!.toDouble();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please give your goal a name')),
      );
      return;
    }

    setState(() => _saving = true);
    await context.read<GoalService>().addGoal(
          title: title,
          emoji: _selectedEmoji,
          dailyMinutes: _dailyMinutes.round(),
          themeId: _selectedTheme.id,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('New Goal'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Live preview matching the goal-card style used everywhere else.
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: _selectedTheme.gradient,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(_selectedEmoji,
                        style: const TextStyle(fontSize: 30)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _titleController.text.isEmpty
                              ? 'Goal name'
                              : _titleController.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_dailyMinutes.round()} min / day',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            Text('Goal name', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _titleController,
              style: AppTextStyles.body,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. AWS, DSA, Flutter, Maths',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.xl),

            Text('Choose an icon', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (!_emojiOptions.contains(_selectedEmoji)) _selectedEmoji,
                ..._emojiOptions,
              ].map((emoji) {
                final selected = emoji == _selectedEmoji;
                return InkWell(
                  onTap: () => setState(() => _selectedEmoji = emoji),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.purpleMid.withOpacity(0.25)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: selected
                            ? AppColors.purpleLight
                            : AppColors.surfaceBorder,
                        width: selected ? 1.6 : 1,
                      ),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),

            Text('Choose a color', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Used for this goal\'s card and its home-screen widget',
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: WidgetThemes.all.map((theme) {
                final selected = theme.id == _selectedTheme.id;
                return InkWell(
                  onTap: () => setState(() => _selectedTheme = theme),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: theme.gradient,
                          border: selected
                              ? Border.all(color: Colors.white, width: 2.5)
                              : null,
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: theme.mid.withOpacity(0.5),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: selected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 20)
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        theme.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),

            Text('Daily target', style: AppTextStyles.title),
            const SizedBox(height: 4),
            Text(
              '${_dailyMinutes.round()} minutes per day',
              style: AppTextStyles.bodyMuted,
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.purpleMid,
                inactiveTrackColor: AppColors.surfaceLight,
                thumbColor: AppColors.purpleLight,
                overlayColor: AppColors.purpleMid.withOpacity(0.2),
              ),
              child: Slider(
                value: _dailyMinutes,
                min: 5,
                max: 180,
                divisions: 35,
                label: '${_dailyMinutes.round()} min',
                onChanged: (v) => setState(() => _dailyMinutes = v),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create Goal'),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
