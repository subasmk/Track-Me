import 'package:flutter_test/flutter_test.dart';
import 'package:trackme/services/ai_service.dart';

void main() {
  test('parses a quest draft and clamps bad values', () {
    final d = AiService.parseDraft('''```json
{"kind":"quest","reply":"Quest generated.","quest":{"title":"AWS Cloud Practitioner Prep","emoji":"☁️",
"type":"Study","difficulty":"Legendary","startTime":"7:00","endTime":"25:00","days":[1,2,3,9,"5"],
"items":[{"name":"Watch module","target":30,"sets":1,"unit":"min"},{"name":"Practice questions","target":-4,"sets":0,"unit":"problems"},{"target":3}]}}
```''');
    expect(d.isQuest, isTrue);
    final q = d.quest!;
    expect(q.title, 'AWS Cloud Practitioner Prep');
    expect(q.type, 'Study');
    expect(q.difficulty, 'Medium');
    expect(q.startTime, '07:00');
    expect(q.endTime, isNull);
    expect(q.days, [1, 2, 3, 5]);
    expect(q.items.length, 2);
    expect(q.items[1].$2, 1);
    expect(q.items[1].$3, 1);
  });

  test('parses a goal draft and rounds minutes to the slider step', () {
    final d = AiService.parseDraft('{"kind":"goal","reply":"Goal set.","goal":{"title":"Read","emoji":"📚","minutes":22}}');
    expect(d.isGoal, isTrue);
    expect(d.goalMinutes, 20);
    expect(d.goalEmoji, '📚');
  });

  test('question or junk answers produce no draft', () {
    expect(AiService.parseDraft('{"kind":"none","reply":"What skill?"}').hasDraft, isFalse);
    expect(AiService.parseDraft('not json').hasDraft, isFalse);
    expect(AiService.parseDraft('{"kind":"quest","quest":{"title":"x","items":[]}}').hasDraft, isFalse);
  });

  test('extracts text and skips thought parts', () {
    const body = '{"candidates":[{"content":{"parts":[{"text":"hmm","thought":true},{"text":"{\\"kind\\":\\"none\\"}"}]}}]}';
    expect(AiService.extractText(body), '{"kind":"none"}');
  });
}
