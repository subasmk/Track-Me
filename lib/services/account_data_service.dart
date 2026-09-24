import 'package:hive/hive.dart';

import '../models/goal.dart';
import '../models/learning_note.dart';
import '../models/quest.dart';
import '../models/quest_item.dart';
import 'hive_service.dart';

/// Keeps each signed-in account's on-phone data separate.
///
/// Goals, quests, XP and profile settings all live in shared Hive boxes. The
/// live boxes always belong to one account (the "owner"). When a different
/// account signs in, the owner's data is moved into a private stash box and
/// the new account's stash (if any) is moved back in. Nothing is deleted.
class AccountDataService {
  AccountDataService._();

  static const ownerKey = 'data_owner_uid';
  static const _legacy = 'legacy';

  /// Settings that belong to the phone, not to an account.
  static bool isDeviceKey(String key) =>
      key == ownerKey ||
      key == 'onboarding_seen' ||
      key == 'reduce_motion' ||
      key.startsWith('profile_done_');

  static String _stashName(String id) => 'user_stash_$id';

  static String? get owner => HiveService.settingsBox.get(ownerKey) as String?;

  /// True when the live boxes already belong to [uid].
  static bool isActive(String uid) => owner == uid;

  /// Phones that ran an older build have no owner yet. If more than one
  /// account finished setup there, the data got mixed and we have to ask
  /// who it belongs to instead of guessing.
  static bool needsOwnerChoice(String uid) {
    if (owner != null) return false;
    final done = HiveService.settingsBox.keys
        .whereType<String>()
        .where((k) => k.startsWith('profile_done_'))
        .length;
    return done > 1;
  }

  /// Makes the live data belong to [uid]. Call after sign-in, before any
  /// screen reads goals, quests or settings.
  static Future<void> activate(String uid) async {
    final current = owner;
    if (current == uid) return;
    if (current == null) {
      await HiveService.settingsBox.put(ownerKey, uid);
      return;
    }
    await _stash(current);
    await _restore(uid);
    await HiveService.settingsBox.put(ownerKey, uid);
  }

  /// Old-build phones with mixed data: [keepHere] true gives the phone's
  /// data to [uid]; false parks it for the next other account that signs
  /// in and starts [uid] fresh. Either way every account sets up its
  /// profile again, because the old build could not keep them apart.
  static Future<void> resolveMixed(String uid, {required bool keepHere}) async {
    final box = HiveService.settingsBox;
    for (final k in box.keys.whereType<String>().toList()) {
      if (k.startsWith('profile_done_')) await box.delete(k);
    }
    for (final k in const ['user_name', 'full_name', 'user_bio', 'photo_path']) {
      await box.delete(k);
    }
    if (keepHere) {
      await box.put(ownerKey, uid);
    } else {
      await _stash(_legacy);
      await box.put(ownerKey, uid);
    }
  }

  static Future<void> _stash(String id) async {
    final stash = await Hive.openBox(_stashName(id));
    await stash.clear();
    await stash.put('goals', HiveService.goalsBox.values.map(_copyGoal).toList());
    await stash.put('quests', HiveService.questsBox.values.map(_copyQuest).toList());
    final settings = <String, dynamic>{};
    for (final k in HiveService.settingsBox.keys.whereType<String>()) {
      if (!isDeviceKey(k)) settings[k] = HiveService.settingsBox.get(k);
    }
    await stash.put('settings', settings);
    await stash.close();

    await HiveService.goalsBox.clear();
    await HiveService.questsBox.clear();
    for (final k in settings.keys) {
      await HiveService.settingsBox.delete(k);
    }
  }

  static Future<void> _restore(String uid) async {
    var id = uid;
    if (!await Hive.boxExists(_stashName(uid))) {
      if (!await Hive.boxExists(_stashName(_legacy))) return;
      id = _legacy; // parked data from an old build goes to the next account
    }
    final stash = await Hive.openBox(_stashName(id));
    for (final g in ((stash.get('goals') as List?) ?? const []).cast<Goal>()) {
      await HiveService.goalsBox.put(g.id, _copyGoal(g));
    }
    for (final q in ((stash.get('quests') as List?) ?? const []).cast<Quest>()) {
      await HiveService.questsBox.put(q.id, _copyQuest(q));
    }
    final settings = (stash.get('settings') as Map?) ?? const {};
    for (final e in settings.entries) {
      await HiveService.settingsBox.put(e.key as String, e.value);
    }
    await stash.deleteFromDisk();
  }

  // A HiveObject can only live in one box, so copy before moving.
  static Goal _copyGoal(Goal g) => Goal(
        id: g.id,
        title: g.title,
        emoji: g.emoji,
        streak: g.streak,
        longestStreak: g.longestStreak,
        dailyMinutes: g.dailyMinutes,
        lastCompleted: g.lastCompleted,
        notes: [
          for (final n in g.notes)
            LearningNote(
                text: n.text, date: n.date, id: n.id, imagePath: n.imagePath, linkUrl: n.linkUrl)
        ],
        xp: g.xp,
        level: g.level,
        createdAt: g.createdAt,
        unlockedBadgeIds: List<String>.from(g.unlockedBadgeIds),
        themeId: g.themeId,
      );

  static Quest _copyQuest(Quest q) => Quest(
        id: q.id,
        title: q.title,
        emoji: q.emoji,
        type: q.type,
        difficulty: q.difficulty,
        startTime: q.startTime,
        endTime: q.endTime,
        streak: q.streak,
        longestStreak: q.longestStreak,
        items: [
          for (final i in q.items)
            QuestItem(
                id: i.id, name: i.name, target: i.target, sets: i.sets, unit: i.unit, isDone: i.isDone)
        ],
        xp: q.xp,
        gold: q.gold,
        focusStats: q.focusStats,
        lastCompleted: q.lastCompleted,
        createdAt: q.createdAt,
        targetDays: q.targetDays == null ? null : List<int>.from(q.targetDays!),
        lastItemToggleDate: q.lastItemToggleDate,
        completionHistory: List<DateTime>.from(q.completionHistory),
        reminderTime: q.reminderTime,
        focusMinutes: q.focusMinutes,
      );
}
