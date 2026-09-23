import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/settings_service.dart';
import '../../services/goal_service.dart';
import '../../services/quest_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';

class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  String? _photoPath;
  bool _isLoading = false;

  /// Live username check: null = not checked yet / can't check.
  bool? _available;
  bool _checking = false;
  String? _usernameError;
  Timer? _debounce;

  void _onUsernameChanged(String raw) {
    final v = raw.trim().toLowerCase();
    _debounce?.cancel();
    setState(() {
      _available = null;
      _usernameError = v.isEmpty || SupabaseService.usernamePattern.hasMatch(v)
          ? null
          : '3-20 characters: letters, numbers, _ or .';
      _checking = _usernameError == null && v.isNotEmpty;
    });
    if (!_checking) return;
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final ok = await context.read<SupabaseService>().isUsernameAvailable(v);
      if (!mounted || _usernameController.text.trim().toLowerCase() != v) return;
      setState(() {
        _checking = false;
        _available = ok;
        if (ok == false) _usernameError = '@$v is taken';
      });
    });
  }

  Widget? _usernameStatus() {
    if (_checking) {
      return const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (_available == true) return const Icon(Icons.check_circle, color: Color(0xFF4ADE80));
    if (_available == false) return const Icon(Icons.cancel, color: Color(0xFFF87171));
    return null;
  }

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsService>();
    _nameController = TextEditingController(
        text: settings.fullName == 'Daily Tracker' ? '' : settings.fullName);
    final existing = settings.userName.toLowerCase();
    _usernameController = TextEditingController(
        text: SupabaseService.usernamePattern.hasMatch(existing) && existing != 'learner' ? existing : '');
    _bioController = TextEditingController(text: settings.bio);
    _photoPath = settings.photoPath;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (picked != null) {
      setState(() => _photoPath = picked.path);
    }
  }

  Future<void> _saveAndContinue() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim().toLowerCase();
    final bio = _bioController.text.trim();

    if (!SupabaseService.usernamePattern.hasMatch(username)) {
      setState(() => _usernameError = '3-20 characters: letters, numbers, _ or .');
      return;
    }
    if (_available == false) return;

    setState(() => _isLoading = true);

    final settings = context.read<SettingsService>();
    final goalService = context.read<GoalService>();
    final questService = context.read<QuestService>();
    final supabase = context.read<SupabaseService>();
    final messenger = ScaffoldMessenger.of(context);

    final bool cloudOk;
    try {
      cloudOk = await supabase.saveMyProfile(
        username: username,
        fullName: name.isNotEmpty ? name : username,
        bio: bio,
        avatarPath: _photoPath,
      );
    } on UsernameTakenException {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _available = false;
          _usernameError = '@$username is taken';
        });
      }
      return;
    }

    await settings.setUserName(username);
    await settings.updateProfile(
      fullName: name.isNotEmpty ? name : username,
      bio: bio,
      photoPath: _photoPath,
    );
    goalService.setUserName(username);

    await supabase.syncLocalProfileToCloud(
      goals: goalService.goals,
      quests: questService.quests,
    );
    if (!cloudOk) {
      messenger.showSnackBar(const SnackBar(
          content: Text("Saved on this phone. Couldn't reach the cloud, so friends can't find you yet.")));
    }

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.md),
              Text(
                'Create Your Profile',
                style: AppTextStyles.headline.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 6),
              Text(
                'Set up your username, bio, and photo so friends can find you!',
                style: AppTextStyles.bodyMuted,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Profile Photo Selector
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.purpleMid,
                      backgroundImage: _photoPath != null
                          ? FileImage(File(_photoPath!))
                          : null,
                      child: _photoPath == null
                          ? const Icon(Icons.person, size: 50, color: Colors.white)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.purpleLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt,
                          size: 18, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('Tap to choose profile photo',
                  style: AppTextStyles.caption.copyWith(color: AppColors.purpleLight)),

              const SizedBox(height: AppSpacing.xl),

              // Input Form Card
              Card(
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      TextField(
                        controller: _usernameController,
                        style: AppTextStyles.body,
                        autocorrect: false,
                        onChanged: _onUsernameChanged,
                        decoration: InputDecoration(
                          labelText: 'Username *',
                          hintText: 'alex_coder',
                          prefixIcon: const Icon(Icons.alternate_email),
                          suffixIcon: _usernameStatus(),
                          errorText: _usernameError,
                          helperText: _available == true ? 'Available' : 'Unique. Friends find you by this.',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _nameController,
                        style: AppTextStyles.body,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          hintText: 'Alex Rivera',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _bioController,
                        maxLines: 2,
                        style: AppTextStyles.body,
                        decoration: const InputDecoration(
                          labelText: 'Bio',
                          hintText: 'Building daily consistency 🔥',
                          prefixIcon: Icon(Icons.edit_note),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purpleMid,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading || _checking || _available == false ? null : _saveAndContinue,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Save & Complete Setup',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
