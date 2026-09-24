import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../services/goal_service.dart';
import '../services/settings_service.dart';
import '../services/supabase_service.dart';
import 'system_ui.dart';

/// Edit name, @username, bio and photo. Used by Settings and Profile.
/// Username changes go through the same format rule and live availability
/// check as sign-up, and the cloud profile is updated when it's reachable.
Future<void> showEditProfileSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _EditProfileSheet(),
  );
}

/// Copies a picked photo into app storage so it survives cache clean-up.
Future<String> keepPhoto(String pickedPath) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final dest = File('${dir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await File(pickedPath).copy(dest.path);
    return dest.path;
  } catch (_) {
    return pickedPath;
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet();

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _bio;
  late final String _originalUsername;
  String? _photo;
  bool? _available;
  bool _checking = false;
  bool _saving = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsService>();
    _originalUsername = s.userName.toLowerCase();
    _name = TextEditingController(text: s.fullName);
    _username = TextEditingController(text: _originalUsername);
    _bio = TextEditingController(text: s.bio);
    _photo = s.photoPath;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _onUsername(String raw) {
    final v = raw.trim().toLowerCase();
    _debounce?.cancel();
    setState(() {
      _available = null;
      _error = SupabaseService.usernamePattern.hasMatch(v)
          ? null
          : '3-20 characters: letters, numbers, _ or .';
      _checking = _error == null && v != _originalUsername;
    });
    if (!_checking) return;
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final ok = await context.read<SupabaseService>().isUsernameAvailable(v);
      if (!mounted || _username.text.trim().toLowerCase() != v) return;
      setState(() {
        _checking = false;
        _available = ok;
        if (ok == false) _error = '@$v is taken';
      });
    });
  }

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (picked == null) return;
    final kept = await keepPhoto(picked.path);
    if (mounted) setState(() => _photo = kept);
  }

  Future<void> _save() async {
    final username = _username.text.trim().toLowerCase();
    if (!SupabaseService.usernamePattern.hasMatch(username) || _available == false) {
      setState(() => _error ??= '3-20 characters: letters, numbers, _ or .');
      return;
    }
    setState(() => _saving = true);
    final settings = context.read<SettingsService>();
    final supabase = context.read<SupabaseService>();
    final goals = context.read<GoalService>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final name = _name.text.trim().isEmpty ? username : _name.text.trim();
    var cloudOk = false;
    try {
      if (supabase.isLoggedIn) {
        cloudOk = await supabase.saveMyProfile(
            username: username, fullName: name, bio: _bio.text.trim(), avatarPath: _photo);
      }
    } on UsernameTakenException {
      if (mounted) {
        setState(() {
          _saving = false;
          _available = false;
          _error = '@$username is taken';
        });
      }
      return;
    }
    await settings.setUserName(username);
    await settings.updateProfile(fullName: name, bio: _bio.text.trim(), photoPath: _photo);
    goals.setUserName(username);
    supabase.updateUsername(username);
    nav.pop();
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(cloudOk || !supabase.isLoggedIn
          ? 'Profile updated'
          : 'Saved on this phone. It will reach the cloud once sync is set up.'),
    ));
  }

  InputDecoration _dec(String label, {Widget? suffix, String? error, String? prefix}) =>
      InputDecoration(
        labelText: label,
        prefixText: prefix,
        errorText: error,
        suffixIcon: suffix,
        labelStyle: const TextStyle(color: SysColors.muted),
        prefixStyle: const TextStyle(color: SysColors.cyanSoft),
        enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0x553FD4FF)), borderRadius: BorderRadius.zero),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: SysColors.cyan), borderRadius: BorderRadius.zero),
        errorBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: SysColors.warn), borderRadius: BorderRadius.zero),
        focusedErrorBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: SysColors.warn), borderRadius: BorderRadius.zero),
      );

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    final hasPhoto = photo != null && (photo.startsWith('http') || File(photo).existsSync());
    Widget? status;
    if (_checking) {
      status = const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)));
    } else if (_available == true) {
      status = const Icon(Icons.check_circle, color: SysColors.ok);
    } else if (_available == false) {
      status = const Icon(Icons.cancel, color: SysColors.warn);
    }
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF06101F),
          border: Border(top: BorderSide(color: SysColors.cyan, width: 1.2)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SysTag('EDIT PROFILE'),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: _pick,
              child: Stack(alignment: Alignment.bottomRight, children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: const Color(0xFF0F2A4A),
                  backgroundImage: hasPhoto
                      ? (photo.startsWith('http')
                          ? NetworkImage(photo)
                          : FileImage(File(photo)) as ImageProvider)
                      : null,
                  child: hasPhoto
                      ? null
                      : const Icon(Icons.person, size: 44, color: SysColors.cyanSoft),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: SysColors.cyan, shape: BoxShape.circle),
                  child: const Icon(Icons.photo_camera, size: 16, color: Colors.black),
                ),
              ]),
            ),
            const SizedBox(height: 6),
            TextButton(onPressed: _pick, child: const Text('Change photo')),
            const SizedBox(height: 8),
            TextField(
                controller: _name,
                style: SysText.body,
                textCapitalization: TextCapitalization.words,
                decoration: _dec('Name')),
            const SizedBox(height: 12),
            TextField(
              controller: _username,
              style: SysText.body,
              onChanged: _onUsername,
              autocorrect: false,
              decoration: _dec('Username', prefix: '@', suffix: status, error: _error),
            ),
            const SizedBox(height: 12),
            TextField(
                controller: _bio,
                style: SysText.body,
                maxLines: 3,
                maxLength: 150,
                decoration: _dec('Bio')),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: SysColors.cyan,
                  foregroundColor: Colors.black,
                  shape: const RoundedRectangleBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _saving || _checking ? null : _save,
                child: Text(_saving ? 'SAVING...' : 'SAVE',
                    style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
