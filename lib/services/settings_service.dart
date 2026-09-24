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

  // Preferences shown on the Settings screen. The reminder keys are read
  // directly by ReminderService (it has no provider access), so keep the
  // names in sync with ReminderService.keyRemindersEnabled etc.
  static const String keyRemindersEnabled = 'reminders_enabled';
  static const String keyStreakNudge = 'streak_nudge_enabled';
  static const String keyStreakNudgeTime = 'streak_nudge_time';
  static const String keyReduceMotion = 'reduce_motion';
  static const String keyDiscoverable = 'discoverable';
  static const String keyShareQuests = 'share_quests_on_profile';
  static const String keyWidgetStyle = 'widget_style';
  static const String keyWidgetBgPath = 'widget_bg_path';

  String _userName = 'Learner';
  String _fullName = 'Daily Tracker';
  String _bio = 'Building consistency day by day 🔥';
  String? _photoPath;
  bool _onboardingSeen = false;
  bool _remindersEnabled = true;
  bool _streakNudge = true;
  String _streakNudgeTime = '20:00';
  bool _reduceMotion = false;
  bool _discoverable = true;
  bool _shareQuests = true;
  String _widgetStyle = 'auto';
  String? _widgetBgPath;

  String get userName => _userName;
  String get fullName => _fullName;
  String get bio => _bio;
  String? get photoPath => _photoPath;
  bool get onboardingSeen => _onboardingSeen;
  bool get remindersEnabled => _remindersEnabled;
  bool get streakNudge => _streakNudge;
  String get streakNudgeTime => _streakNudgeTime;
  bool get reduceMotion => _reduceMotion;
  bool get discoverable => _discoverable;
  bool get shareQuests => _shareQuests;
  /// 'auto' = Duolingo-style urgency colors, otherwise a WidgetTheme id.
  String get widgetStyle => _widgetStyle;
  String? get widgetBgPath => _widgetBgPath;

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
    _remindersEnabled = (box.get(keyRemindersEnabled) as bool?) ?? true;
    _streakNudge = (box.get(keyStreakNudge) as bool?) ?? true;
    _streakNudgeTime = (box.get(keyStreakNudgeTime) as String?) ?? '20:00';
    _reduceMotion = (box.get(keyReduceMotion) as bool?) ?? false;
    _discoverable = (box.get(keyDiscoverable) as bool?) ?? true;
    _shareQuests = (box.get(keyShareQuests) as bool?) ?? true;
    _widgetStyle = (box.get(keyWidgetStyle) as String?) ?? 'auto';
    _widgetBgPath = box.get(keyWidgetBgPath) as String?;
  }

  Future<void> _put(String key, Object value) async {
    await HiveService.settingsBox.put(key, value);
    notifyListeners();
  }

  Future<void> setRemindersEnabled(bool v) {
    _remindersEnabled = v;
    return _put(keyRemindersEnabled, v);
  }

  Future<void> setStreakNudge(bool v) {
    _streakNudge = v;
    return _put(keyStreakNudge, v);
  }

  Future<void> setStreakNudgeTime(String hhmm) {
    _streakNudgeTime = hhmm;
    return _put(keyStreakNudgeTime, hhmm);
  }

  Future<void> setReduceMotion(bool v) {
    _reduceMotion = v;
    return _put(keyReduceMotion, v);
  }

  Future<void> setDiscoverable(bool v) {
    _discoverable = v;
    return _put(keyDiscoverable, v);
  }

  Future<void> setWidgetStyle(String style) {
    _widgetStyle = style;
    return _put(keyWidgetStyle, style);
  }

  Future<void> setWidgetBackground(String? path) async {
    _widgetBgPath = path;
    if (path == null) {
      await HiveService.settingsBox.delete(keyWidgetBgPath);
      notifyListeners();
    } else {
      await _put(keyWidgetBgPath, path);
    }
  }

  Future<void> setShareQuests(bool v) {
    _shareQuests = v;
    return _put(keyShareQuests, v);
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
