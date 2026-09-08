class PublicProfile {
  final String id;
  final String username;
  final int level;
  final int xp;
  final int currentStreak;
  final int longestStreak;
  final List<String> badges;
  final List<PublicTask> mainTasks;

  PublicProfile({
    required this.id,
    required this.username,
    this.level = 1,
    this.xp = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    List<String>? badges,
    List<PublicTask>? mainTasks,
  })  : badges = badges ?? [],
        mainTasks = mainTasks ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'level': level,
        'xp': xp,
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
        'badges': badges,
        'main_tasks': mainTasks.map((t) => t.toJson()).toList(),
      };

  factory PublicProfile.fromJson(Map<String, dynamic> json) {
    return PublicProfile(
      id: json['id'] ?? '',
      username: json['username'] ?? 'Anonymous',
      level: json['level'] ?? 1,
      xp: json['xp'] ?? 0,
      currentStreak: json['current_streak'] ?? 0,
      longestStreak: json['longest_streak'] ?? 0,
      badges: List<String>.from(json['badges'] ?? []),
      mainTasks: (json['main_tasks'] as List<dynamic>?)
              ?.map((t) => PublicTask.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class PublicTask {
  final String id;
  final String title;
  final String emoji;
  final String type; // 'goal' or 'quest'
  final int streak;
  final int dailyMinutes;
  final List<String> items;

  PublicTask({
    required this.id,
    required this.title,
    required this.emoji,
    this.type = 'goal',
    this.streak = 0,
    this.dailyMinutes = 15,
    List<String>? items,
  }) : items = items ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'emoji': emoji,
        'type': type,
        'streak': streak,
        'daily_minutes': dailyMinutes,
        'items': items,
      };

  factory PublicTask.fromJson(Map<String, dynamic> json) {
    return PublicTask(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      emoji: json['emoji'] ?? '🎯',
      type: json['type'] ?? 'goal',
      streak: json['streak'] ?? 0,
      dailyMinutes: json['daily_minutes'] ?? 15,
      items: List<String>.from(json['items'] ?? []),
    );
  }
}
