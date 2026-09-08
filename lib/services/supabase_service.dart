import 'dart:convert';
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
  static const String defaultUrl = 'https://YOUR_SUPABASE_PROJECT.supabase.co';
  static const String defaultAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  String _currentUsername = 'Learner';
  String get currentUsername => _currentUsername;

  List<PublicProfile> _mockProfiles = [];
  List<String> _friendsList = [];
  List<TeamQuest> _teamQuests = [];

  List<String> get friendsList => List.unmodifiable(_friendsList);
  List<TeamQuest> get teamQuests => List.unmodifiable(_teamQuests);

  SupabaseService() {
    _loadLocalState();
    _initMockData();
  }

  Future<void> initSupabase({String? url, String? anonKey}) async {
    final finalUrl = url ?? defaultUrl;
    final finalKey = anonKey ?? defaultAnonKey;

    if (finalUrl.contains('YOUR_SUPABASE_PROJECT')) {
      debugPrint('Supabase credentials not configured yet, running in Cloud-Ready Offline Mode.');
      _isInitialized = true;
      notifyListeners();
      return;
    }

    try {
      await Supabase.initialize(
        url: finalUrl,
        anonKey: finalKey,
      );
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Supabase init failed: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  void _loadLocalState() {
    final box = HiveService.settingsBox;
    _currentUsername = (box.get('user_name') as String?) ?? 'Learner';
    _friendsList = List<String>.from((box.get('friends_list') as List?) ?? ['AlexCoder', 'FitNinja']);
    
    final rawTeams = box.get('team_quests_json') as String?;
    if (rawTeams != null) {
      try {
        final decoded = jsonDecode(rawTeams) as List;
        _teamQuests = decoded.map((e) => TeamQuest.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    if (_teamQuests.isEmpty) {
      _teamQuests = [
        TeamQuest(
          id: 'team_1',
          title: '30-Day Code & Fitness Sprint',
          emoji: '🔥',
          description: 'Complete daily goal to maintain our 7-day team streak!',
          memberUsernames: [_currentUsername, 'AlexCoder', 'FitNinja'],
          teamStreak: 7,
          completedTodayUsernames: ['AlexCoder'],
        ),
      ];
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

  void _initMockData() {
    _mockProfiles = [
      PublicProfile(
        id: 'user_alex',
        username: 'AlexCoder',
        level: 5,
        xp: 450,
        currentStreak: 14,
        longestStreak: 21,
        badges: ['first_step', 'streak_7', 'streak_14', 'xp_500'],
        mainTasks: [
          PublicTask(id: 'g1', title: 'Flutter & Dart Mastery', emoji: '💙', type: 'goal', streak: 14, dailyMinutes: 30),
          PublicTask(id: 'q1', title: 'Daily Code Review Quest', emoji: '💻', type: 'quest', streak: 8, items: ['Read 1 PR', 'Write 50 lines', 'Refactor 1 function']),
        ],
      ),
      PublicProfile(
        id: 'user_fit',
        username: 'FitNinja',
        level: 8,
        xp: 890,
        currentStreak: 28,
        longestStreak: 30,
        badges: ['first_step', 'streak_7', 'streak_14', 'streak_30', 'notes_5'],
        mainTasks: [
          PublicTask(id: 'g2', title: 'Morning Calisthenics', emoji: '⚡', type: 'goal', streak: 28, dailyMinutes: 20),
          PublicTask(id: 'q2', title: 'Full Body Workout Quest', emoji: '🏋️', type: 'quest', streak: 15, items: ['30 Pushups', '20 Squats', '1 min Plank']),
        ],
      ),
      PublicProfile(
        id: 'user_mind',
        username: 'ZenMaster',
        level: 3,
        xp: 220,
        currentStreak: 5,
        longestStreak: 12,
        badges: ['first_step', 'streak_7'],
        mainTasks: [
          PublicTask(id: 'g3', title: 'Daily Mindfulness & Meditation', emoji: '🧘', type: 'goal', streak: 5, dailyMinutes: 15),
        ],
      ),
    ];
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

    final profile = PublicProfile(
      id: 'local_user',
      username: _currentUsername,
      level: level,
      xp: totalXp,
      currentStreak: maxStreak,
      longestStreak: longest,
      badges: ['first_step', if (maxStreak >= 7) 'streak_7', if (maxStreak >= 14) 'streak_14'],
      mainTasks: mainTasks,
    );

    // Update in mock list if offline or Supabase table if online
    final index = _mockProfiles.indexWhere((p) => p.username.toLowerCase() == _currentUsername.toLowerCase());
    if (index >= 0) {
      _mockProfiles[index] = profile;
    } else {
      _mockProfiles.add(profile);
    }

    if (_isInitialized && !defaultUrl.contains('YOUR_SUPABASE_PROJECT')) {
      try {
        await Supabase.instance.client.from('profiles').upsert(profile.toJson());
      } catch (e) {
        debugPrint('Supabase cloud sync error: $e');
      }
    }
    notifyListeners();
  }

  Future<List<PublicProfile>> searchProfiles(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _mockProfiles;

    if (_isInitialized && !defaultUrl.contains('YOUR_SUPABASE_PROJECT')) {
      try {
        final res = await Supabase.instance.client
            .from('profiles')
            .select()
            .ilike('username', '%$q%');
        return (res as List).map((e) => PublicProfile.fromJson(e)).toList();
      } catch (_) {}
    }

    return _mockProfiles.where((p) => p.username.toLowerCase().contains(q)).toList();
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
