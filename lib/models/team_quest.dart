class TeamQuest {
  final String id;
  final String title;
  final String emoji;
  final String description;
  final List<String> memberUsernames;
  final int teamStreak;
  final List<String> completedTodayUsernames;
  final DateTime createdAt;

  TeamQuest({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    required this.memberUsernames,
    this.teamStreak = 0,
    List<String>? completedTodayUsernames,
    DateTime? createdAt,
  })  : completedTodayUsernames = completedTodayUsernames ?? [],
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'emoji': emoji,
        'description': description,
        'member_usernames': memberUsernames,
        'team_streak': teamStreak,
        'completed_today': completedTodayUsernames,
        'created_at': createdAt.toIso8601String(),
      };

  factory TeamQuest.fromJson(Map<String, dynamic> json) {
    return TeamQuest(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      emoji: json['emoji'] ?? '🔥',
      description: json['description'] ?? '',
      memberUsernames: List<String>.from(json['member_usernames'] ?? []),
      teamStreak: json['team_streak'] ?? 0,
      completedTodayUsernames: List<String>.from(json['completed_today'] ?? []),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}
