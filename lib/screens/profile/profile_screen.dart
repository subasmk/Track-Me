import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/edit_profile_sheet.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/quest.dart';
import '../../services/goal_service.dart';
import '../../services/progression_service.dart';
import '../../services/quest_service.dart';
import '../../services/settings_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/system_ui.dart';
import '../achievements/achievements_screen.dart';
import '../quests/quest_detail_screen.dart';
import '../settings/settings_screen.dart';

// Instagram-style profile: avatar ring + counts, name/title/bio, action
// buttons, highlight circles, then reading-site style stat blocks and a
// grid of quests. Plain dark look on purpose (not the System windows).
const _bg = Color(0xFF000000);
const _card = Color(0xFF121212);
const _line = Color(0xFF262626);
const _muted = Color(0xFFA8A8A8);
const _blue = Color(0xFF0095F6);
const _fire = Color(0xFFFF6A00);
const _typeColors = <Color>[
  Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCAF45), Color(0xFF0095F6),
  Color(0xFF2ECC71), Color(0xFFE1306C),
];

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final goals = context.watch<GoalService>().goals;
    final quests = context.watch<QuestService>().quests;
    final progression = context.watch<ProgressionService>();
    final supabase = context.watch<SupabaseService>();

    final streaks = [...goals.map((g) => g.streak), ...quests.map((q) => q.streak)];
    final bests = [...goals.map((g) => g.longestStreak), ...quests.map((q) => q.longestStreak)];
    final streak = streaks.isEmpty ? 0 : streaks.reduce((a, b) => a > b ? a : b);
    final best = bests.isEmpty ? 0 : bests.reduce((a, b) => a > b ? a : b);
    final cleared = quests.fold<int>(0, (s, q) => s + q.completionHistory.length);
    final focusMin = quests.fold<int>(0, (s, q) => s + q.focusMinutes);
    final activeDays = {
      for (final q in quests)
        for (final d in q.completionHistory) DateTime(d.year, d.month, d.day)
    }.length;

    // Focus split by quest type (like a genre split on a reader profile).
    final split = <String, int>{};
    for (final q in quests) {
      split[q.type] = (split[q.type] ?? 0) + 1;
    }
    final splitList = split.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = split.values.fold<int>(0, (a, b) => a + b);
    final specialist = splitList.isEmpty ? 'Rookie' : '${splitList.first.key} Specialist';

    final level = progression.level;
    final handle = settings.userName.toLowerCase().replaceAll(' ', '');

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(handle,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Medals',
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const AchievementsScreen())),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.menu),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => _pickProfileImage(context, settings),
                child: _RingAvatar(settings: settings, radius: 42),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _Count('${quests.length + goals.length}', 'quests'),
                  _Count('${supabase.friendsList.length}', 'friends'),
                  _Count('$streak', 'day streak'),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(settings.fullName.isNotEmpty ? settings.fullName : settings.userName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _Chip('Lv $level', const Color(0xFFFCAF45)),
                _Chip('Rank ${SysRank.rank(level)}', _blue),
                _Chip(specialist, const Color(0xFFE1306C)),
              ]),
              if (settings.bio.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(settings.bio, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3)),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              Expanded(
                  child: _Button('Edit profile',
                      onTap: () => showEditProfileSheet(context))),
              const SizedBox(width: 6),
              Expanded(
                child: _Button('Share profile', onTap: () {
                  SharePlus.instance.share(ShareParams(
                      text: 'Add me on TrackMe: @$handle - Level $level, $streak day streak.',
                      subject: 'TrackMe profile'));
                }),
              ),
            ]),
          ),
          if (quests.isNotEmpty || goals.isNotEmpty)
            SizedBox(
              height: 104,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(10, 16, 10, 0),
                children: [
                  for (final q in quests)
                    _Highlight(
                        emoji: q.emoji,
                        label: q.title,
                        streak: q.streak,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => QuestDetailScreen(questId: q.id)))),
                  for (final g in goals) _Highlight(emoji: g.emoji, label: g.title, streak: g.streak),
                ],
              ),
            ),
          const SizedBox(height: 8),
          if (total > 0)
            _Section(
              title: 'Focus split',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 10,
                    child: Row(children: [
                      for (var i = 0; i < splitList.length; i++)
                        Expanded(
                            flex: splitList[i].value,
                            child: Container(color: _typeColors[i % _typeColors.length])),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 14, runSpacing: 6, children: [
                  for (var i = 0; i < splitList.length; i++)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: _typeColors[i % _typeColors.length], shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('${splitList[i].key} ${(splitList[i].value * 100 / total).round()}%',
                          style: const TextStyle(color: _muted, fontSize: 12)),
                    ]),
                ]),
              ]),
            ),
          _Section(
            title: 'Activity',
            child: _StatGrid(items: [
              ('Quests cleared', '$cleared'),
              ('Focus minutes', '$focusMin'),
              ('Days active', '$activeDays'),
              ('Current streak', '$streak'),
              ('Best streak', '$best'),
              ('Gold', '${progression.gold}'),
            ]),
          ),
          _Section(
            title: 'Reputation',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('${progression.totalXp} XP',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text(SysRank.title(level),
                    style: const TextStyle(color: _muted, fontSize: 12, letterSpacing: 1)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progression.levelProgress.clamp(0, 1).toDouble(),
                  minHeight: 6,
                  backgroundColor: _line,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFFCAF45)),
                ),
              ),
              const SizedBox(height: 6),
              Text('${progression.xpIntoLevel} / ${progression.xpForNextLevel} XP to level ${level + 1}',
                  style: const TextStyle(color: _muted, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 8),
          _QuestGrid(quests: quests),
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
        photoPath: await keepPhoto(picked.path),
      );
    }
  }
}

class _RingAvatar extends StatelessWidget {
  final SettingsService settings;
  final double radius;
  const _RingAvatar({required this.settings, required this.radius});

  @override
  Widget build(BuildContext context) {
    final photo = settings.photoPath;
    final hasPhoto = photo != null && File(photo).existsSync();
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [
          Color(0xFFFCAF45), Color(0xFFFD1D1D), Color(0xFFE1306C), Color(0xFF833AB4), Color(0xFFFCAF45),
        ]),
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(color: _bg, shape: BoxShape.circle),
        child: Stack(children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: _card,
            backgroundImage: hasPhoto ? FileImage(File(photo)) : null,
            child: hasPhoto
                ? null
                : Text(settings.userName.isNotEmpty ? settings.userName[0].toUpperCase() : 'U',
                    style: TextStyle(
                        fontSize: radius * 0.8, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                  color: _blue, shape: BoxShape.circle, border: Border.all(color: _bg, width: 2)),
              child: const Icon(Icons.add, size: 14, color: Colors.white),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  final String value;
  final String label;
  const _Count(this.value, this.label);
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ]);
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class _Button extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _Button(this.text, {required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            height: 34,
            child: Center(
                child: Text(text,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14))),
          ),
        ),
      );
}

class _Highlight extends StatelessWidget {
  final String emoji;
  final String label;
  final int streak;
  final VoidCallback? onTap;
  const _Highlight({required this.emoji, required this.label, required this.streak, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 76,
          child: Column(children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _card,
                  border: Border.all(color: const Color(0xFF3A3A3A), width: 1.5),
                ),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
              ),
              if (streak > 0)
                Positioned(
                  bottom: -4,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: _fire, borderRadius: BorderRadius.circular(8)),
                      child: Text('🔥$streak',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 6),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ]),
        ),
      );
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

class _StatGrid extends StatelessWidget {
  final List<(String, String)> items;
  const _StatGrid({required this.items});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - 16) / 3;
        return Wrap(spacing: 8, runSpacing: 14, children: [
          for (final (label, value) in items)
            SizedBox(
              width: w,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
              ]),
            ),
        ]);
      });
}

class _QuestGrid extends StatelessWidget {
  final List<Quest> quests;
  const _QuestGrid({required this.quests});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
        child: Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white, width: 1.5))),
              child: const Icon(Icons.grid_on, color: Colors.white, size: 24),
            ),
          ),
        ]),
      ),
      if (quests.isEmpty)
        const Padding(
          padding: EdgeInsets.all(32),
          child: Text('No quests yet', style: TextStyle(color: _muted)),
        )
      else
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          padding: const EdgeInsets.only(top: 2),
          children: [
            for (var i = 0; i < quests.length; i++)
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => QuestDetailScreen(questId: quests[i].id))),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _typeColors[i % _typeColors.length].withValues(alpha: 0.55),
                        const Color(0xFF111111),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Stack(children: [
                    Center(child: Text(quests[i].emoji, style: const TextStyle(fontSize: 34))),
                    Positioned(
                      left: 0,
                      bottom: 0,
                      right: 0,
                      child: Text(quests[i].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    if (quests[i].isCompletedToday)
                      const Positioned(
                          right: 0, top: 0, child: Icon(Icons.check_circle, color: Colors.white, size: 16)),
                  ]),
                ),
              ),
          ],
        ),
    ]);
  }
}
