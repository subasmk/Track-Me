import 'package:flutter_test/flutter_test.dart';
import 'package:trackme/services/progression_service.dart';

void main() {
  test('level curve', () {
    expect(ProgressionService.levelFor(0), (level: 1, into: 0));
    expect(ProgressionService.levelFor(199), (level: 1, into: 199));
    expect(ProgressionService.levelFor(200), (level: 2, into: 0));
    expect(ProgressionService.levelFor(200 + 300 + 10), (level: 3, into: 10));
  });
}
