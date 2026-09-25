import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../services/quest_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../models/quest.dart';
import '../../models/quest_item.dart';
import '../../models/quest_templates.dart';

class AddQuestScreen extends StatefulWidget {
  final Quest? existingQuest;

  /// Pre-fills the form (e.g. from the AI assistant). Nothing is saved
  /// until the user taps Create.
  final QuestTemplate? draft;
  const AddQuestScreen({super.key, this.existingQuest, this.draft});

  @override
  State<AddQuestScreen> createState() => _AddQuestScreenState();
}

class _AddQuestScreenState extends State<AddQuestScreen> {
  static const _uuid = Uuid();

  final _titleController = TextEditingController();
  final _focusController = TextEditingController();

  String _emoji = '⚔️';
  String _type = 'Fitness';
  String _difficulty = 'Medium';
  String? _startTime;
  String? _endTime;
  List<int> _targetDays = [1, 2, 3, 4, 5, 6, 7];
  final List<QuestItem> _items = [];

  bool get _isEditing => widget.existingQuest != null;

  static const _types = ['Fitness', 'Study', 'Mindfulness', 'Skill', 'Custom'];
  static const _difficulties = ['Easy', 'Medium', 'Hard'];
  static const _emojis = [
    '⚔️', '🏋️', '🧠', '🧘', '🎯', '🏃', '💪', '📚', '🎮', '🚴',
    '🏊', '🤸', '🥊', '🧗', '🎵', '🎨', '💻', '🌟', '🔥', '⚡',
  ];

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    if (!_isEditing && draft != null) {
      _titleController.text = draft.title;
      _emoji = draft.emoji;
      _type = draft.type;
      _difficulty = draft.difficulty;
      _startTime = draft.startTime;
      _endTime = draft.endTime;
      _targetDays = List<int>.from(draft.days);
      _items.addAll(draft.buildItems(() => _uuid.v4()));
    }
    if (_isEditing) {
      final q = widget.existingQuest!;
      _titleController.text = q.title;
      _focusController.text = q.focusStats;
      _emoji = q.emoji;
      _type = q.type;
      _difficulty = q.difficulty;
      _startTime = q.startTime;
      _endTime = q.endTime;
      _targetDays = List<int>.from(q.days);
      _items.addAll(q.items.map((i) => QuestItem(
            id: i.id,
            name: i.name,
            target: i.target,
            sets: i.sets,
            unit: i.unit,
            isDone: i.isDone, // keep today's ticks when editing
          )));
    }
  }

  void _applyTemplate(QuestTemplate t) {
    setState(() {
      _titleController.text = t.title;
      _emoji = t.emoji;
      _type = t.type;
      _difficulty = t.difficulty;
      _startTime = t.startTime;
      _endTime = t.endTime;
      _targetDays = List<int>.from(t.days);
      _items
        ..clear()
        ..addAll(t.buildItems(() => _uuid.v4()));
    });
  }

  Widget _templateStrip() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('START FROM A TEMPLATE',
            style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary, letterSpacing: 1.2, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: questTemplates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final t = questTemplates[i];
              return ActionChip(
                avatar: Text(t.emoji),
                label: Text(t.title),
                onPressed: () => _applyTemplate(t),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.surfaceBorder),
              );
            },
          ),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _focusController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      final formatted = _formatTime(picked);
      setState(() {
        if (isStart) {
          _startTime = formatted;
        } else {
          _endTime = formatted;
        }
      });
    }
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _addItem() {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController(text: '10');
    final setsCtrl = TextEditingController(text: '3');
    final unitCtrl = TextEditingController(text: 'reps');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Add Goal Item', style: AppTextStyles.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name (e.g., Pushup)'),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: targetCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Target'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: setsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sets'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: unitCtrl,
              decoration: const InputDecoration(
                  labelText: 'Unit (reps/steps/m/etc.)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              setState(() {
                _items.add(QuestItem(
                  id: _uuid.v4(),
                  name: name,
                  target: int.tryParse(targetCtrl.text) ?? 10,
                  sets: int.tryParse(setsCtrl.text) ?? 1,
                  unit: unitCtrl.text.trim().isEmpty ? 'reps' : unitCtrl.text.trim(),
                ));
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.purpleMid),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _toggleDay(int day) {
    setState(() {
      if (_targetDays.contains(day)) {
        _targetDays.remove(day);
      } else {
        _targetDays.add(day);
      }
    });
  }

  void _toggleAllDays() {
    setState(() {
      if (_targetDays.length >= 7) {
        _targetDays = [];
      } else {
        _targetDays = [1, 2, 3, 4, 5, 6, 7];
      }
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a quest title')),
      );
      return;
    }

    final questService = context.read<QuestService>();

    final selectedDays = _targetDays.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : _targetDays;

    if (_isEditing) {
      final q = widget.existingQuest!;
      q.title = title;
      q.emoji = _emoji;
      q.type = _type;
      q.difficulty = _difficulty;
      q.startTime = _startTime;
      q.endTime = _endTime;
      q.targetDays = selectedDays;
      q.items = _items;
      q.xp = Quest.xpForDifficulty(_difficulty);
      q.gold = Quest.goldForDifficulty(_difficulty);
      q.focusStats = _focusController.text.trim().isEmpty
          ? _defaultFocusStats(_type)
          : _focusController.text.trim();
      await questService.updateQuest(q);
    } else {
      await questService.addQuest(
        title: title,
        emoji: _emoji,
        type: _type,
        difficulty: _difficulty,
        startTime: _startTime,
        endTime: _endTime,
        targetDays: selectedDays,
        items: _items,
        focusStats: _focusController.text.trim().isEmpty
            ? null
            : _focusController.text.trim(),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  String _defaultFocusStats(String type) {
    switch (type) {
      case 'Fitness':
        return 'STR/AGI';
      case 'Study':
        return 'INT';
      case 'Mindfulness':
        return 'WIS';
      case 'Skill':
        return 'DEX';
      default:
        return 'ALL';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const CloseButton(),
        title: Text(_isEditing ? 'Edit Quest' : 'New Quest'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              _isEditing ? 'Save' : 'Create',
              style: AppTextStyles.button
                  .copyWith(color: AppColors.purpleLight, fontSize: 15),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (!_isEditing && widget.draft == null) _templateStrip(),
            // Emoji picker
            Center(
              child: GestureDetector(
                onTap: _showEmojiPicker,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.purpleMid, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(_emoji, style: const TextStyle(fontSize: 36)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text('Tap to change emoji',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ),
            const SizedBox(height: AppSpacing.md),

            // Title
            TextField(
              controller: _titleController,
              style: AppTextStyles.body,
              decoration: const InputDecoration(
                labelText: 'Quest Title',
                hintText: 'e.g., Morning Workout',
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Type
            _SectionLabel('Type'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _types
                  .map((t) => _SelectChip(
                        label: t,
                        selected: _type == t,
                        onTap: () => setState(() => _type = t),
                        selectedColor: AppColors.purpleMid,
                      ))
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.md),

            // Difficulty
            _SectionLabel('Difficulty'),
            const SizedBox(height: 8),
            Row(
              children: _difficulties
                  .map((d) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _SelectChip(
                            label: d,
                            selected: _difficulty == d,
                            onTap: () => setState(() => _difficulty = d),
                            selectedColor: d == 'Easy'
                                ? AppColors.success
                                : d == 'Hard'
                                    ? AppColors.flameRed
                                    : AppColors.flameYellow,
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.md),

            // Time window
            _SectionLabel('Time Window (optional)'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TimeTile(
                    label: 'Start',
                    value: _startTime,
                    onTap: () => _pickTime(true),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward,
                    color: AppColors.textMuted, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: _TimeTile(
                    label: 'End',
                    value: _endTime,
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Visible Days
            _SectionLabel('Visible Days'),
            const SizedBox(height: 8),
            Row(
              children: [
                _SelectChip(
                  label: 'All Days',
                  selected: _targetDays.length >= 7,
                  onTap: _toggleAllDays,
                  selectedColor: AppColors.purpleMid,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _DayChip(dayName: 'Mon', dayNum: 1, selected: _targetDays.contains(1), onTap: () => _toggleDay(1)),
                _DayChip(dayName: 'Tue', dayNum: 2, selected: _targetDays.contains(2), onTap: () => _toggleDay(2)),
                _DayChip(dayName: 'Wed', dayNum: 3, selected: _targetDays.contains(3), onTap: () => _toggleDay(3)),
                _DayChip(dayName: 'Thu', dayNum: 4, selected: _targetDays.contains(4), onTap: () => _toggleDay(4)),
                _DayChip(dayName: 'Fri', dayNum: 5, selected: _targetDays.contains(5), onTap: () => _toggleDay(5)),
                _DayChip(dayName: 'Sat', dayNum: 6, selected: _targetDays.contains(6), onTap: () => _toggleDay(6)),
                _DayChip(dayName: 'Sun', dayNum: 7, selected: _targetDays.contains(7), onTap: () => _toggleDay(7)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Focus stats
            TextField(
              controller: _focusController,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                labelText: 'Focus Stats (optional)',
                hintText: _defaultFocusStats(_type),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Goal items
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionLabel('Goals'),
                TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Goal'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.purpleLight),
                ),
              ],
            ),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No goals yet — add sub-tasks for this quest',
                    style: AppTextStyles.bodyMuted),
              )
            else
              ..._items.asMap().entries.map((e) => _ItemRow(
                    item: e.value,
                    onDelete: () => setState(() => _items.removeAt(e.key)),
                  )),

            const SizedBox(height: AppSpacing.xl),

            // Save button
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purpleMid,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              child: Text(
                _isEditing ? 'Save Quest' : 'Create Quest',
                style: AppTextStyles.button,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choose Emoji', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _emojis
                  .map((e) => GestureDetector(
                        onTap: () {
                          setState(() => _emoji = e);
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _emoji == e
                                ? AppColors.purpleMid.withOpacity(0.2)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: _emoji == e
                                  ? AppColors.purpleMid
                                  : Colors.transparent,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(e,
                              style: const TextStyle(fontSize: 24)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: AppTextStyles.caption
            .copyWith(color: AppColors.textSecondary, fontSize: 12));
  }
}

class _SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;
  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withOpacity(0.2)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? selectedColor : AppColors.surfaceBorder,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(
            color: selected ? selectedColor : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;
  const _TimeTile({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppTextStyles.caption.copyWith(fontSize: 10)),
            const SizedBox(height: 2),
            Text(
              value ?? '--:--',
              style: AppTextStyles.body.copyWith(
                color: value != null
                    ? AppColors.textPrimary
                    : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final QuestItem item;
  final VoidCallback onDelete;
  const _ItemRow({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.drag_handle, color: AppColors.textMuted, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(item.name, style: AppTextStyles.body),
          ),
          Text(
            '[${item.target}/${item.target} ${item.sets}]',
            style: AppTextStyles.caption,
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close,
                color: AppColors.danger, size: 18),
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String dayName;
  final int dayNum;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({
    required this.dayName,
    required this.dayNum,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.purpleMid.withOpacity(0.2)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.purpleMid : AppColors.surfaceBorder,
            width: 1.5,
          ),
        ),
        child: Text(
          dayName,
          style: AppTextStyles.caption.copyWith(
            color: selected ? AppColors.purpleLight : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
