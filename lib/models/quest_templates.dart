import 'quest_item.dart';

/// Ready-made quests to start from. Items are copied with fresh ids.
class QuestTemplate {
  final String title;
  final String emoji;
  final String type;
  final String difficulty;
  final String? startTime;
  final String? endTime;
  final List<int> days;
  final List<(String name, int target, int sets, String unit)> items;

  const QuestTemplate({
    required this.title,
    required this.emoji,
    required this.type,
    required this.difficulty,
    this.startTime,
    this.endTime,
    this.days = const [1, 2, 3, 4, 5, 6, 7],
    required this.items,
  });

  List<QuestItem> buildItems(String Function() newId) => [
        for (final i in items)
          QuestItem(id: newId(), name: i.$1, target: i.$2, sets: i.$3, unit: i.$4),
      ];
}

const questTemplates = <QuestTemplate>[
  QuestTemplate(
    title: 'Morning Workout',
    emoji: '💪',
    type: 'Fitness',
    difficulty: 'Medium',
    startTime: '07:00',
    endTime: '07:40',
    items: [('Pushups', 15, 3, 'reps'), ('Squats', 20, 3, 'reps'), ('Plank', 60, 1, 'sec')],
  ),
  QuestTemplate(
    title: 'Deep Study',
    emoji: '📚',
    type: 'Study',
    difficulty: 'Hard',
    startTime: '19:00',
    endTime: '20:30',
    days: [1, 2, 3, 4, 5],
    items: [('Focus session', 50, 1, 'min'), ('Review notes', 1, 1, 'topic'), ('Practice problems', 5, 1, 'problems')],
  ),
  QuestTemplate(
    title: 'Mindful Evening',
    emoji: '🧘',
    type: 'Mindfulness',
    difficulty: 'Easy',
    startTime: '21:30',
    items: [('Meditate', 10, 1, 'min'), ('Journal', 3, 1, 'lines'), ('No screens', 30, 1, 'min')],
  ),
  QuestTemplate(
    title: '10k Steps',
    emoji: '🏃',
    type: 'Fitness',
    difficulty: 'Easy',
    items: [('Walk', 10000, 1, 'steps'), ('Water', 8, 1, 'glasses')],
  ),
  QuestTemplate(
    title: 'Skill Builder',
    emoji: '🎸',
    type: 'Skill',
    difficulty: 'Medium',
    days: [2, 4, 6],
    items: [('Warm-up', 10, 1, 'min'), ('Practice', 30, 1, 'min'), ('Record progress', 1, 1, 'clip')],
  ),
  QuestTemplate(
    title: 'Code Daily',
    emoji: '💻',
    type: 'Study',
    difficulty: 'Medium',
    items: [('LeetCode', 2, 1, 'problems'), ('Side project', 30, 1, 'min')],
  ),
];
