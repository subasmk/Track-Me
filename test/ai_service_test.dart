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

  group('providers', () {
    const turns = [AiTurn(true, 'learn AWS')];
    test('guess provider from key shape', () {
      expect(AiService.guessProvider('sk-ant-api03-xxxx')!.id, 'anthropic');
      expect(AiService.guessProvider('sk-or-v1-xxxx')!.id, 'openrouter');
      expect(AiService.guessProvider('gsk_xxxx')!.id, 'groq');
      expect(AiService.guessProvider('AIzaSyxxxx')!.id, 'gemini');
      expect(AiService.guessProvider('sk-proj-xxxx'), isNull);
    });
    test('openai-compatible request', () {
      final (uri, headers, body) = AiService.buildRequest(AiService.providerById('groq'), 'm1', 'k', turns);
      expect(uri.toString(), 'https://api.groq.com/openai/v1/chat/completions');
      expect(headers['Authorization'], 'Bearer k');
      expect(body['model'], 'm1');
      expect((body['messages'] as List).first['role'], 'system');
      expect((body['messages'] as List).last['content'], 'learn AWS');
    });
    test('anthropic request', () {
      final (uri, headers, body) = AiService.buildRequest(AiService.providerById('anthropic'), 'm2', 'k', turns);
      expect(uri.host, 'api.anthropic.com');
      expect(headers['x-api-key'], 'k');
      expect(body['system'], AiService.systemPrompt);
    });
    test('gemini request', () {
      final (uri, headers, _) = AiService.buildRequest(AiService.providerById('gemini'), 'g', 'k', turns);
      expect(uri.path, contains('/models/g:generateContent'));
      expect(headers['x-goog-api-key'], 'k');
    });
    test('extract text from openai and anthropic responses', () {
      expect(AiService.extractText('{"choices":[{"message":{"role":"assistant","content":"{\\"kind\\":\\"none\\"}"}}]}'),
          '{"kind":"none"}');
      expect(AiService.extractText('{"content":[{"type":"text","text":"hi"}]}'), 'hi');
    });
  });
}
