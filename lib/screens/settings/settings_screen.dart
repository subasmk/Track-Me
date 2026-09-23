import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/backup_service.dart';
import '../../services/goal_service.dart';
import '../../services/home_widget_service.dart';
import '../../services/quest_service.dart';
import '../../services/reminder_service.dart';
import '../../services/settings_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/widget_themes.dart';
import '../../widgets/duo_widget_preview.dart';
import '../../widgets/edit_profile_sheet.dart';
import '../../widgets/pin_quest_widget.dart';
import '../../widgets/system_ui.dart';

const appVersion = '1.0.0';
const _repoUrl = 'https://github.com/subasmk/Track-Me';

class SettingsScreen extends StatefulWidget {
  /// Skips the live cloud check (used by screenshot tests).
  final bool checkCloud;
  /// Screenshot tests only: the widget preview's time-of-day state.
  final DuoUrgency? previewUrgency;
  const SettingsScreen({super.key, this.checkCloud = true, this.previewUrgency});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _exporting = false;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    if (widget.checkCloud) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => context.read<SupabaseService>().checkCloudStatus());
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));

  // ---------- notifications ----------

  Future<void> _setReminders(bool on) async {
    final settings = context.read<SettingsService>();
    final quests = context.read<QuestService>().quests;
    if (on && !await ReminderService.requestPermission()) {
      if (mounted) _snack('Allow notifications for TrackMe in Android settings to get reminders.');
    }
    await settings.setRemindersEnabled(on);
    await ReminderService.rescheduleAll(quests);
  }

  Future<void> _setNudge(bool on) async {
    await context.read<SettingsService>().setStreakNudge(on);
    await ReminderService.scheduleStreakNudge();
  }

  Future<void> _pickNudgeTime() async {
    final settings = context.read<SettingsService>();
    final t = ReminderService.parseTime(settings.streakNudgeTime) ?? (hour: 20, minute: 0);
    final picked = await showTimePicker(
        context: context, initialTime: TimeOfDay(hour: t.hour, minute: t.minute));
    if (picked == null) return;
    final hhmm =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await settings.setStreakNudgeTime(hhmm);
    await ReminderService.scheduleStreakNudge();
  }

  // ---------- backup ----------

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await BackupService.exportData();
    } catch (_) {
      if (mounted) _snack('Could not create the backup file');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    bool restored = false;
    try {
      restored = await BackupService.importData(context);
    } catch (_) {
      if (mounted) _snack('Could not read that backup file');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
    if (restored && mounted) {
      context.read<GoalService>().notifyExternalChange();
      context.read<SettingsService>().reloadFromDisk();
      _snack('Backup restored');
    }
  }

  // ---------- account ----------

  Future<bool?> _confirm(String title, String body, String action) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF071427),
          shape: const RoundedRectangleBorder(side: BorderSide(color: SysColors.cyan)),
          title: Text(title, style: SysText.body.copyWith(fontSize: 17)),
          content: Text(body, style: SysText.body.copyWith(color: SysColors.muted)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(action, style: const TextStyle(color: SysColors.warn))),
          ],
        ),
      );

  Future<void> _logout() async {
    final ok = await _confirm('Log out?',
        'Your goals and quests stay on this phone. Sign in again to use profiles and friends.',
        'Log out');
    if (ok != true || !mounted) return;
    await context.read<SupabaseService>().signOut();
    if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
  }

  Future<void> _deleteAccount() async {
    final ok = await _confirm(
        'Delete account?',
        'This permanently deletes your TrackMe account, cloud profile, photo and friends. '
            'Goals and quests saved on this phone stay until you uninstall. This cannot be undone.',
        'Delete forever');
    if (ok != true || !mounted) return;
    final supabase = context.read<SupabaseService>();
    final done = await supabase.deleteAccount();
    if (!mounted) return;
    if (done) {
      Navigator.popUntil(context, (r) => r.isFirst);
    } else {
      _snack("Couldn't delete the account. Check your connection and that cloud sync is set up.");
    }
  }

  // ---------- widgets ----------

  Future<void> _pickWidgetBackground() async {
    final settings = context.read<SettingsService>();
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1080, maxHeight: 1080, imageQuality: 85);
    if (picked == null) return;
    final kept = await keepPhoto(picked.path);
    await settings.setWidgetBackground(kept);
    await HomeWidgetService.saveWidgetStyle(style: settings.widgetStyle, bgPath: kept);
  }

  Future<void> _refreshWidgets() async {
    context.read<GoalService>().notifyExternalChange();
    final ok = await context.read<QuestService>().syncWidget();
    if (mounted) _snack(ok ? 'Widgets refreshed' : "Couldn't refresh the widgets");
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final supabase = context.watch<SupabaseService>();

    return Scaffold(
      backgroundColor: SysColors.bg,
      appBar: AppBar(
        backgroundColor: SysColors.bg,
        scrolledUnderElevation: 0,
        leading: const BackButton(color: SysColors.text),
        title: const Text('SETTINGS', style: SysText.header),
        centerTitle: true,
      ),
      body: SysBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _ProfileCard(settings: settings, onEdit: () => showEditProfileSheet(context)),
            const SizedBox(height: 18),
            _SyncPanel(supabase: supabase, onRecheck: supabase.checkCloudStatus),
            const SizedBox(height: 18),
            SysPanel(
              tag: 'NOTIFICATIONS',
              child: Column(children: [
                _SwitchRow(
                  icon: Icons.notifications_active_outlined,
                  title: 'Quest reminders',
                  subtitle: 'Uses the reminder time set on each quest',
                  value: settings.remindersEnabled,
                  onChanged: _setReminders,
                ),
                _SwitchRow(
                  icon: Icons.local_fire_department_outlined,
                  title: 'Evening streak nudge',
                  subtitle: 'One daily nudge so the streak survives',
                  value: settings.remindersEnabled && settings.streakNudge,
                  onChanged: settings.remindersEnabled ? _setNudge : null,
                ),
                _TapRow(
                  icon: Icons.schedule,
                  title: 'Nudge time',
                  trailing: settings.streakNudgeTime,
                  onTap: settings.remindersEnabled && settings.streakNudge ? _pickNudgeTime : null,
                ),
              ]),
            ),
            const SizedBox(height: 18),
            SysPanel(
              tag: 'APPEARANCE',
              child: Column(children: [
                const _TapRow(
                  icon: Icons.dark_mode_outlined,
                  title: 'Theme',
                  trailing: 'System dark',
                ),
                _SwitchRow(
                  icon: Icons.motion_photos_off_outlined,
                  title: 'Reduce motion',
                  subtitle: 'Stops the sloth bobbing on Home',
                  value: settings.reduceMotion,
                  onChanged: settings.setReduceMotion,
                ),
              ]),
            ),
            const SizedBox(height: 18),
            SysPanel(
              tag: 'WIDGETS',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _WidgetPreviewStrip(settings: settings, preview: widget.previewUrgency),
                const SizedBox(height: 14),
                Text('COLOR', style: SysText.label),
                const SizedBox(height: 8),
                _StylePicker(
                  selected: settings.widgetStyle,
                  onPick: (id) async {
                    await settings.setWidgetStyle(id);
                    await HomeWidgetService.saveWidgetStyle(style: id, bgPath: settings.widgetBgPath);
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  settings.widgetStyle == 'auto'
                      ? 'Auto: purple in the day, orange when you might forget, red when it\'s late.'
                      : '${WidgetThemes.byId(settings.widgetStyle).label} gradient all day. The message still changes with the time.',
                  style: SysText.body.copyWith(color: SysColors.muted, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                _TapRow(
                  icon: Icons.wallpaper,
                  title: settings.widgetBgPath == null ? 'Custom background photo' : 'Change background photo',
                  onTap: _pickWidgetBackground,
                ),
                if (settings.widgetBgPath != null)
                  _TapRow(
                    icon: Icons.hide_image_outlined,
                    title: 'Remove background photo',
                    onTap: () async {
                      await settings.setWidgetBackground(null);
                      await HomeWidgetService.saveWidgetStyle(style: settings.widgetStyle);
                    },
                  ),
                const SizedBox(height: 8),
                _SysButton(
                  icon: Icons.add_to_home_screen,
                  label: 'ADD STREAK WIDGET',
                  onTap: () => pinGoalWidgetWithFeedback(context, null, null),
                ),
                const SizedBox(height: 10),
                _SysButton(
                  icon: Icons.add_to_home_screen,
                  label: 'ADD QUEST WIDGET',
                  onTap: () => pinQuestWidgetWithFeedback(context, null),
                ),
                _TapRow(
                  icon: Icons.refresh,
                  title: 'Refresh widgets now',
                  onTap: _refreshWidgets,
                ),
              ]),
            ),
            const SizedBox(height: 18),
            SysPanel(
              tag: 'PRIVACY',
              child: Column(children: [
                _SwitchRow(
                  icon: Icons.travel_explore,
                  title: 'Show me in Discover',
                  subtitle: 'Other players can find you and see you in suggestions',
                  value: settings.discoverable,
                  onChanged: settings.setDiscoverable,
                ),
                _SwitchRow(
                  icon: Icons.visibility_outlined,
                  title: 'Show my quests on my profile',
                  subtitle: 'Friends can see and copy your quest titles',
                  value: settings.shareQuests,
                  onChanged: settings.setShareQuests,
                ),
              ]),
            ),
            const SizedBox(height: 18),
            SysPanel(
              tag: 'BACKUP',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(
                  'Goals, quests, notes and photos are saved on this phone. Cloud sync only '
                  'covers your public profile and stats, so export a backup before you switch '
                  'phones or reinstall.',
                  style: SysText.body.copyWith(color: SysColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                _SysButton(
                  icon: Icons.ios_share,
                  label: _exporting ? 'PREPARING...' : 'EXPORT BACKUP',
                  onTap: _exporting ? null : _export,
                ),
                const SizedBox(height: 10),
                _SysButton(
                  icon: Icons.file_upload_outlined,
                  label: _importing ? 'RESTORING...' : 'RESTORE FROM BACKUP',
                  color: SysColors.gold,
                  onTap: _importing ? null : _import,
                ),
                const SizedBox(height: 6),
                Text('Restoring replaces everything currently in the app.',
                    style: SysText.label.copyWith(
                        letterSpacing: 0.4, color: SysColors.muted, fontWeight: FontWeight.w500)),
              ]),
            ),
            const SizedBox(height: 18),
            SysPanel(
              tag: 'ACCOUNT',
              accent: supabase.email != null ? SysColors.cyan : SysColors.muted,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _TapRow(
                  icon: Icons.mail_outline,
                  title: 'Email',
                  trailing: supabase.email ?? 'Not signed in',
                ),
                if (supabase.email != null) ...[
                  const SizedBox(height: 8),
                  _SysButton(icon: Icons.logout, label: 'LOG OUT', onTap: _logout),
                  const SizedBox(height: 10),
                  _SysButton(
                    icon: Icons.delete_forever_outlined,
                    label: 'DELETE ACCOUNT',
                    color: SysColors.warn,
                    onTap: _deleteAccount,
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 18),
            SysPanel(
              tag: 'ABOUT',
              child: Column(children: [
                const _TapRow(icon: Icons.info_outline, title: 'Version', trailing: appVersion),
                _TapRow(
                  icon: Icons.code,
                  title: 'Source code',
                  trailing: 'GitHub',
                  onTap: () => launchUrl(Uri.parse(_repoUrl),
                      mode: LaunchMode.externalApplication),
                ),
                _TapRow(
                  icon: Icons.description_outlined,
                  title: 'Open-source licenses',
                  onTap: () => showLicensePage(
                      context: context, applicationName: 'TrackMe', applicationVersion: appVersion),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final SettingsService settings;
  final VoidCallback onEdit;
  const _ProfileCard({required this.settings, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final p = settings.photoPath;
    final hasPhoto = p != null && (p.startsWith('http') || File(p).existsSync());
    return SysPanel(
      tag: 'PLAYER',
      onTap: onEdit,
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(2.5),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(colors: [SysColors.cyan, SysColors.blue, SysColors.cyan]),
          ),
          child: CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF0F2A4A),
            backgroundImage: hasPhoto
                ? (p.startsWith('http') ? NetworkImage(p) : FileImage(File(p)) as ImageProvider)
                : null,
            child: hasPhoto
                ? null
                : Text(
                    settings.fullName.isEmpty ? '?' : settings.fullName[0].toUpperCase(),
                    style: SysText.header.copyWith(fontSize: 22)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(settings.fullName,
                style: SysText.body.copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('@${settings.userName.toLowerCase()}',
                style: SysText.body.copyWith(color: SysColors.cyanSoft, fontSize: 13)),
            const SizedBox(height: 4),
            Text(settings.bio,
                style: SysText.body.copyWith(color: SysColors.muted, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: onEdit,
          style: OutlinedButton.styleFrom(
            foregroundColor: SysColors.cyan,
            side: const BorderSide(color: SysColors.cyan),
            shape: const RoundedRectangleBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: const Text('EDIT', style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

class _SyncPanel extends StatelessWidget {
  final SupabaseService supabase;
  final Future<CloudStatus> Function() onRecheck;
  const _SyncPanel({required this.supabase, required this.onRecheck});

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon, String title, String detail) = switch (supabase.cloudStatus) {
      CloudStatus.checking => (SysColors.muted, Icons.sync, 'Checking...', 'Looking for your cloud profile.'),
      CloudStatus.offline => (
          SysColors.gold,
          Icons.cloud_off_outlined,
          'Offline',
          "Couldn't reach the server. Everything still works and is saved on this phone."
        ),
      CloudStatus.signedOut => (
          SysColors.muted,
          Icons.person_off_outlined,
          'Not signed in',
          'Everything is saved on this phone only. Sign in to use profiles and friends.'
        ),
      CloudStatus.notSetUp => (
          SysColors.gold,
          Icons.cloud_queue,
          'Cloud not set up yet',
          'Signed in, but the profiles database hasn\'t been created. Run supabase/schema.sql '
              'in the Supabase SQL Editor to turn on profiles and friends. Your data is safe on this phone.'
        ),
      CloudStatus.synced => (
          SysColors.ok,
          Icons.cloud_done_outlined,
          'Profile syncing',
          'Your profile, level and streaks sync to the cloud. Goals and quests themselves stay on this phone.'
        ),
      CloudStatus.error => (
          SysColors.warn,
          Icons.error_outline,
          "Couldn't check sync",
          'The server didn\'t answer. Try again when you have a connection.'
        ),
    };
    final last = supabase.lastSyncedAt;
    return SysPanel(
      tag: 'SYNC STATUS',
      accent: color,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
              child: Text(title,
                  style: SysText.body.copyWith(color: color, fontSize: 16, fontWeight: FontWeight.w800))),
          TextButton(
            onPressed: supabase.cloudStatus == CloudStatus.checking ? null : onRecheck,
            child: const Text('CHECK AGAIN', style: TextStyle(letterSpacing: 1.2, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(detail, style: SysText.body.copyWith(color: SysColors.muted, fontSize: 13)),
        if (supabase.cloudStatus == CloudStatus.synced && last != null) ...[
          const SizedBox(height: 8),
          Text('LAST SYNC  ${_ago(last)}', style: SysText.label),
        ],
      ]),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'JUST NOW';
    if (d.inHours < 1) return '${d.inMinutes} MIN AGO';
    if (d.inDays < 1) return '${d.inHours} H AGO';
    return '${d.inDays} D AGO';
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _SwitchRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, color: SysColors.cyanSoft, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: SysText.body),
              if (subtitle != null)
                Text(subtitle!, style: SysText.body.copyWith(color: SysColors.muted, fontSize: 12, fontWeight: FontWeight.w500)),
            ]),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.black,
            activeTrackColor: SysColors.cyan,
            inactiveThumbColor: SysColors.muted,
            inactiveTrackColor: const Color(0xFF0B1A2E),
          ),
        ]),
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback? onTap;
  const _TapRow({required this.icon, required this.title, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Icon(icon, color: SysColors.cyanSoft, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: SysText.body)),
            if (trailing != null)
              Flexible(
                child: Text(trailing!,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: SysText.body.copyWith(color: SysColors.muted, fontSize: 13)),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: SysColors.muted, size: 20),
            ],
          ]),
        ),
      );
}

class _SysButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _SysButton({required this.icon, required this.label, this.color = SysColors.cyan, this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(letterSpacing: 1.6, fontWeight: FontWeight.w800)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.8)),
          backgroundColor: color.withValues(alpha: 0.06),
          shape: const RoundedRectangleBorder(),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      );
}

class _WidgetPreviewStrip extends StatelessWidget {
  final SettingsService settings;
  final DuoUrgency? preview;
  const _WidgetPreviewStrip({required this.settings, this.preview});

  @override
  Widget build(BuildContext context) {
    final goals = context.watch<GoalService>().goals;
    final now = DateTime.now();
    final g = goals.isEmpty ? null : goals.first;
    final streak = g?.streak ?? 0;
    final done = g?.isCompletedToday ?? false;
    final days = [for (var i = 4; i >= 0; i--) DateTime(now.year, now.month, now.day - i)];
    final last5 = [
      for (final d in days)
        g?.notes.any((n) => n.date.year == d.year && n.date.month == d.month && n.date.day == d.day) ?? false
    ];
    return DuoWidgetPreview(
      urgency: preview ?? duoUrgencyFor(done, now.hour),
      style: settings.widgetStyle,
      bgPath: settings.widgetBgPath,
      name: settings.fullName.isNotEmpty && settings.fullName != 'Daily Tracker'
          ? settings.fullName
          : settings.userName,
      title: g == null ? 'Your streak' : '${g.emoji} ${g.title}',
      streak: streak,
      last5: last5,
      today: now,
    );
  }
}

class _StylePicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onPick;
  const _StylePicker({required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    Widget dot(String id, Gradient g, {Widget? child}) {
      final on = id == selected;
      return GestureDetector(
        onTap: () => onPick(id),
        child: Container(
          width: 38,
          height: 38,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: on ? Colors.white : Colors.transparent, width: 2),
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: g),
            child: child ?? (on ? const Icon(Icons.check, size: 16, color: Colors.white) : null),
          ),
        ),
      );
    }

    return Wrap(spacing: 6, runSpacing: 6, children: [
      dot(
        'auto',
        const SweepGradient(colors: [
          Color(0xFFA24BFF), Color(0xFFFF8A00), Color(0xFFC62828), Color(0xFFA24BFF)
        ]),
        child: const Text('A',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
      ),
      for (final t in WidgetThemes.all) dot(t.id, t.gradient),
    ]);
  }
}
