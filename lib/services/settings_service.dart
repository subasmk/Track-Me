import 'package:flutter/foundation.dart';
import 'hive_service.dart';

/// Small persisted settings that aren't goal-specific: the user's display
/// name (used in "Keep going, {name}!") and whether onboarding has been
/// shown yet. Backed by a plain untyped Hive box, so no adapter is needed.
class SettingsService extends ChangeNotifier {
  static const String _keyUserName = 'user_name';
  static const String _keyFullName = 'full_name';
  static const String _keyBio = 'user_bio';
  static const String _keyPhotoPath = 'photo_path';
  static const String _keyOnboardingSeen = 'onboarding_seen';

  String _userName = 'Learner';
  String _fullName = 'Daily Tracker';
  String _bio = 'Building consistency day by day 🔥';
  String? _photoPath;
  bool _onboardingSeen = false;

  String get userName => _userName;
  String get fullName => _fullName;
  String get bio => _bio;
  String? get photoPath => _photoPath;
  bool get onboardingSeen => _onboardingSeen;

  SettingsService() {
    _load();
  }

  void _load() {
    final box = HiveService.settingsBox;
    _userName = (box.get(_keyUserName) as String?) ?? 'Learner';
    _fullName = (box.get(_keyFullName) as String?) ?? 'Daily Tracker';
    _bio = (box.get(_keyBio) as String?) ?? 'Building consistency day by day 🔥';
    _photoPath = box.get(_keyPhotoPath) as String?;
    _onboardingSeen = (box.get(_keyOnboardingSeen) as bool?) ?? false;
  }

  Future<void> setUserName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _userName = trimmed;
    await HiveService.settingsBox.put(_keyUserName, trimmed);
    notifyListeners();
  }

  Future<void> updateProfile({required String fullName, required String bio, String? photoPath}) async {
    _fullName = fullName.trim();
    _bio = bio.trim();
    if (photoPath != null) _photoPath = photoPath;
    final box = HiveService.settingsBox;
    await box.put(_keyFullName, _fullName);
    await box.put(_keyBio, _bio);
    if (_photoPath != null) await box.put(_keyPhotoPath, _photoPath);
    notifyListeners();
  }

  Future<void> markOnboardingSeen() async {
    _onboardingSeen = true;
    await HiveService.settingsBox.put(_keyOnboardingSeen, true);
    notifyListeners();
  }

  /// Called by BackupService after an import writes directly into the
  /// settings box (bypassing setUserName) — re-reads from disk and
  /// notifies listeners so the UI (and GoalService's widget-sync copy of
  /// the name, via main.dart's listener) picks up the restored name.
  void reloadFromDisk() {
    _load();
    notifyListeners();
  }
}
