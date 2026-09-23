import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/public_profile.dart';
import '../models/team_quest.dart';
import '../models/goal.dart';
import '../models/quest.dart';
import '../models/quest_item.dart';
import 'hive_service.dart';
import 'goal_service.dart';
import 'quest_service.dart';

class SupabaseService extends ChangeNotifier {
  static const String defaultUrl = 'https://ceckjlbfwwjdhuffsmta.supabase.co';
  static const String defaultAnonKey = 'sb_publishable_jQ20Rs4lNnGCxP0xMuRcpg_pLPDH69e';

  /// Deep link the confirmation / magic-link emails send the user back to.
  /// Must also be listed under Auth > URL Configuration > Redirect URLs in
  /// the Supabase dashboard, and matches the intent filter in
  /// AndroidManifest.xml.
  static const String authRedirectUrl = 'com.trackme.tracker://login-callback';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// False when Supabase could not start (e.g. no network on first launch).
  bool _clientReady = false;
  StreamSubscription<AuthState>? _authSub;

  User? get currentUser => _clientReady ? Supabase.instance.client.auth.currentUser : null;
  bool get isLoggedIn => currentUser != null;

  String _currentUsername = 'Learner';
  String get currentUsername => _currentUsername;

  List<String> _friendsList = [];
  List<TeamQuest> _teamQuests = [];

  List<String> get friendsList => List.unmodifiable(_friendsList);
  List<TeamQuest> get teamQuests => List.unmodifiable(_teamQuests);

  SupabaseService() {
    _loadLocalState();
  }

  Future<void> initSupabase({String? url, String? anonKey}) async {
    final finalUrl = url ?? defaultUrl;
    final finalKey = anonKey ?? defaultAnonKey;

    try {
      await Supabase.initialize(
        url: finalUrl,
        anonKey: finalKey,
      );
      _clientReady = true;
      // Sign-in can also complete outside our own calls: when the user taps
      // the confirmation link in their email, the app is opened through
      // authRedirectUrl and supabase_flutter exchanges it for a session.
      // Re-render so the app leaves the auth screen right away.
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
        refreshProfileStatus();
        notifyListeners();
      });
      await refreshProfileStatus();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Supabase init failed: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<AuthResponse?> signUp({required String email, required String password}) async {
    if (!_clientReady) return null;
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email.trim(),
        password: password.trim(),
        emailRedirectTo: authRedirectUrl,
      );
      notifyListeners();
      return res;
    } catch (e) {
      rethrow;
    }
  }

  /// Sends the sign-up confirmation email again.
  Future<void> resendConfirmation(String email) async {
    if (!_clientReady) return;
    await Supabase.instance.client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: authRedirectUrl,
    );
  }

  Future<AuthResponse?> signIn({required String email, required String password}) async {
    if (!_clientReady) return null;
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );
      notifyListeners();
      return res;
    } catch (e) {
      rethrow;
    }
  }

  // ---------------------------------------------------------------------
  // Per-user profile (multi-user). Table + RLS: supabase/schema.sql
  // ---------------------------------------------------------------------

  static final usernamePattern = RegExp(r'^[a-z0-9_.]{3,20}$');

  /// Whether the signed-in user has finished profile setup. Remembered per
  /// user id on this phone, and confirmed against the cloud on sign-in.
  bool get profileComplete {
    final uid = currentUser?.id;
    if (uid == null) return false;
    return HiveService.settingsBox.get('profile_done_$uid') == true;
  }

  Future<void> _markProfileComplete() async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await HiveService.settingsBox.put('profile_done_$uid', true);
    notifyListeners();
  }

  /// Marks setup done if a cloud profile already exists for this user
  /// (e.g. signing in on a new phone).
  Future<void> refreshProfileStatus() async {
    final uid = currentUser?.id;
    if (uid == null || profileComplete) return;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('username')
          .eq('id', uid)
          .maybeSingle();
      if (row != null) {
        _currentUsername = row['username'] as String;
        await _markProfileComplete();
      }
    } catch (e) {
      debugPrint('profile status check failed: $e');
    }
  }

  /// true = free, false = taken, null = could not check (offline or the
  /// cloud tables are not set up yet).
  Future<bool?> isUsernameAvailable(String username) async {
    if (!_clientReady) return null;
    try {
      final res = await Supabase.instance.client
          .rpc('username_available', params: {'name': username.toLowerCase()});
      return res as bool;
    } catch (e) {
      debugPrint('username check failed: $e');
      return null;
    }
  }

  /// Creates or updates the signed-in user's cloud profile. Throws
  /// [UsernameTakenException] when someone else already has the username.
  /// Returns false if the cloud isn't reachable/set up (saved locally only).
  Future<bool> saveMyProfile({
    required String username,
    required String fullName,
    required String bio,
    String? avatarPath,
  }) async {
    final uid = currentUser?.id;
    var cloudOk = false;
    if (_clientReady && uid != null) {
      try {
        String? avatarUrl;
        if (avatarPath != null && !avatarPath.startsWith('http')) {
          final file = File(avatarPath);
          if (await file.exists()) {
            final path = '$uid/avatar.jpg';
            await Supabase.instance.client.storage.from('avatars').upload(
                path, file,
                fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
            avatarUrl =
                '${Supabase.instance.client.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
          }
        }
        await Supabase.instance.client.from('profiles').upsert({
          'id': uid,
          'username': username.toLowerCase(),
          'full_name': fullName,
          'bio': bio,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        cloudOk = true;
      } on PostgrestException catch (e) {
        if (e.code == '23505') throw UsernameTakenException();
        debugPrint('saveMyProfile: $e');
      } catch (e) {
        debugPrint('saveMyProfile: $e');
      }
    }
    _currentUsername = username.toLowerCase();
    _saveLocalState();
    await _markProfileComplete();
    return cloudOk;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> signOut() async {
    if (_clientReady) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
    }
    notifyListeners();
  }

  void _loadLocalState() {
    final box = HiveService.settingsBox;
    _currentUsername = (box.get('user_name') as String?) ?? 'Learner';
    _friendsList = List<String>.from((box.get('friends_list') as List?) ?? []);
    
    final rawTeams = box.get('team_quests_json') as String?;
    if (rawTeams != null) {
      try {
        final decoded = jsonDecode(rawTeams) as List;
        _teamQuests = decoded.map((e) => TeamQuest.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
  }

  void _saveLocalState() {
    final box = HiveService.settingsBox;
    box.put('friends_list', _friendsList);
    box.put('team_quests_json', jsonEncode(_teamQuests.map((t) => t.toJson()).toList()));
  }

  void updateUsername(String newName) {
    _currentUsername = newName;
    _saveLocalState();
    notifyListeners();
  }

  Future<void> syncLocalProfileToCloud({
    required List<Goal> goals,
    required List<Quest> quests,
  }) async {
    final maxStreak = goals.fold<int>(0, (prev, g) => g.streak > prev ? g.streak : prev);
    final longest = goals.fold<int>(0, (prev, g) => g.longestStreak > prev ? g.longestStreak : prev);
    final totalXp = goals.fold<int>(0, (prev, g) => prev + g.xp);
    final level = (totalXp / 100).floor() + 1;

    final mainTasks = <PublicTask>[];
    for (final g in goals) {
      mainTasks.add(PublicTask(
        id: g.id,
        title: g.title,
        emoji: g.emoji,
        type: 'goal',
        streak: g.streak,
        dailyMinutes: g.dailyMinutes,
      ));
    }
    for (final q in quests) {
      mainTasks.add(PublicTask(
        id: q.id,
        title: q.title,
        emoji: q.emoji,
        type: 'quest',
        streak: q.streak,
        items: q.items.map((i) => i.name).toList(),
      ));
    }

    final userId = currentUser?.id;
    if (userId == null || !profileComplete) return;

    final profile = PublicProfile(
      id: userId,
      username: _currentUsername,
      level: level,
      xp: totalXp,
      currentStreak: maxStreak,
      longestStreak: longest,
      badges: ['first_step', if (maxStreak >= 7) 'streak_7', if (maxStreak >= 14) 'streak_14'],
      mainTasks: mainTasks,
    );

    if (_clientReady) {
      try {
        final data = profile.toJson()
          ..remove('id')
          ..remove('username');
        await Supabase.instance.client.from('profiles').update(data).eq('id', userId);
      } catch (e) {
        debugPrint('Supabase cloud sync error: $e');
      }
    }
    notifyListeners();
  }

  Future<List<PublicProfile>> searchProfiles(String query) async {
    final q = query.trim().toLowerCase();

    if (_clientReady) {
      try {
        if (q.isEmpty) {
          final res = await Supabase.instance.client
              .from('profiles')
              .select()
              .limit(20);
          return (res as List).map((e) => PublicProfile.fromJson(e)).toList();
        } else {
          final res = await Supabase.instance.client
              .from('profiles')
              .select()
              .ilike('username', '%$q%');
          return (res as List).map((e) => PublicProfile.fromJson(e)).toList();
        }
      } catch (e) {
        debugPrint('Supabase search profiles error: $e');
      }
    }

    return [];
  }

  Future<PublicProfile?> getProfileByUsername(String username) async {
    final results = await searchProfiles(username);
    if (results.isNotEmpty) return results.first;
    return null;
  }

  void addFriend(String username) {
    if (!_friendsList.contains(username) && username != _currentUsername) {
      _friendsList.add(username);
      _saveLocalState();
      notifyListeners();
    }
  }

  void removeFriend(String username) {
    _friendsList.remove(username);
    _saveLocalState();
    notifyListeners();
  }

  void createTeamQuest({
    required String title,
    required String emoji,
    required String description,
    required List<String> invitedFriends,
  }) {
    final members = {_currentUsername, ...invitedFriends}.toList();
    final newTeam = TeamQuest(
      id: 'team_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      emoji: emoji.isEmpty ? '🔥' : emoji,
      description: description,
      memberUsernames: members,
      teamStreak: 1,
      completedTodayUsernames: [_currentUsername],
    );
    _teamQuests.insert(0, newTeam);
    _saveLocalState();
    notifyListeners();
  }

  void completeTeamTaskToday(String teamId) {
    final idx = _teamQuests.indexWhere((t) => t.id == teamId);
    if (idx == -1) return;

    final team = _teamQuests[idx];
    if (team.completedTodayUsernames.contains(_currentUsername)) return;

    final updatedCompleted = [...team.completedTodayUsernames, _currentUsername];
    int newStreak = team.teamStreak;
    // If all members finished today, increment team streak!
    if (updatedCompleted.length >= team.memberUsernames.length) {
      newStreak += 1;
    }

    _teamQuests[idx] = TeamQuest(
      id: team.id,
      title: team.title,
      emoji: team.emoji,
      description: team.description,
      memberUsernames: team.memberUsernames,
      teamStreak: newStreak,
      completedTodayUsernames: updatedCompleted,
      createdAt: team.createdAt,
    );

    _saveLocalState();
    notifyListeners();
  }

  void copyTaskToLocal({
    required PublicTask task,
    required GoalService goalService,
    required QuestService questService,
  }) {
    if (task.type == 'quest') {
      const uuid = Uuid();
      final items = (task.items.isNotEmpty ? task.items : ['Step 1', 'Step 2'])
          .map((title) => QuestItem(id: uuid.v4(), name: title, target: 10))
          .toList();

      questService.addQuest(
        title: '${task.title} (Copied)',
        emoji: task.emoji,
        type: 'Custom',
        difficulty: 'Medium',
        items: items,
      );
    } else {
      goalService.addGoal(
        title: '${task.title} (Copied)',
        emoji: task.emoji,
        dailyMinutes: task.dailyMinutes > 0 ? task.dailyMinutes : 15,
      );
    }
  }
}

class UsernameTakenException implements Exception {}
