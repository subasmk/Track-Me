import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/goal_service.dart';
import '../../services/settings_service.dart';
import '../../services/supabase_service.dart';
import '../../services/backup_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameController;
  bool _exporting = false;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: context.read<SettingsService>().userName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    await context.read<SettingsService>().setUserName(name);
    if (mounted) {
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name updated')),
      );
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await BackupService.exportData();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create the backup file')),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read that backup file')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }

    if (restored && mounted) {
      context.read<GoalService>().notifyExternalChange();
      context.read<SettingsService>().reloadFromDisk();
      _nameController.text = context.read<SettingsService>().userName;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restored')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text('Your name', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Shown in the app and on your widgets',
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: AppTextStyles.body,
                    textCapitalization: TextCapitalization.words,
                    onSubmitted: (_) => _saveName(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed: _saveName,
                  icon: const Icon(Icons.check_circle,
                      color: AppColors.purpleLight),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const Divider(color: AppColors.surfaceBorder),
            const SizedBox(height: AppSpacing.lg),

            Text('Backup & restore', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'TrackMe is fully offline — your data lives only on this '
              'phone. Export a backup file (including photos) before you '
              'switch devices or reinstall.',
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: AppSpacing.md),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _exporting ? null : _export,
                icon: _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share, size: 18),
                label: Text(_exporting ? 'Preparing...' : 'Export backup'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _importing ? null : _import,
                icon: _importing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_upload_outlined, size: 18),
                label: Text(_importing ? 'Restoring...' : 'Restore from backup'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.danger),
                  foregroundColor: AppColors.danger,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Restoring replaces everything currently in the app.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.xl),
            const Divider(color: AppColors.surfaceBorder),
            const SizedBox(height: AppSpacing.lg),

            Text('Cloud Storage Status', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Online Database Sync is active. Your profile, streaks, badges, and team tasks sync automatically under your username.',
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cloud_done_rounded, color: AppColors.success),
                  SizedBox(width: 10),
                  Text('Cloud Profile Sync Active',
                      style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Divider(color: AppColors.surfaceBorder),
            const SizedBox(height: AppSpacing.lg),

            Text('Account & Session', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Sign out of your account or switch to another account.',
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Logout / Switch Account'),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      title: const Text('Logout Account'),
                      content: const Text('Are you sure you want to sign out? You will need to log in again.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Logout', style: TextStyle(color: AppColors.danger)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && context.mounted) {
                    final supabase = context.read<SupabaseService>();
                    await supabase.signOut();
                    if (context.mounted) {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
