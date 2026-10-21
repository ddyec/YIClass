// Opt-in integration test: never stores API credentials or personal timetables.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yiclass/services/ai/ai_transport.dart';
import 'package:yiclass/services/ai/planning_engine.dart';
import 'package:yiclass/services/ai/planning_service.dart';
import 'planning_engine_test.dart' as fixtures;

void main() {
  final key = Platform.environment['YICLASS_TEST_API_KEY'];
  final scenarios = <String, String>{
    'move': '把第4周周一1、2节化学移动到同周周六1、2节，其他不动。',
    'rest': '第4周周一全天休假，把当天化学补到同周周六1、2节。',
    'emergency': '第4周周一1、2节安排紧急会议，把原来同一时间的化学移动到同周周六1、2节。',
    'ambiguous': '帮我调一下化学课。',
    'add': '第5周周日第5、6节安排图书馆自习，地点图书馆。',
  };
  for (final scenario in scenarios.entries) {
    test('live DeepSeek ${scenario.key}', () async {
      final base = fixtures.fixture();
      final response = await AITransport.complete(
          url: 'https://api.deepseek.com/v1',
          apiKey: key!,
          body: {
            'model': 'deepseek-chat',
            'max_tokens': 3000,
            'temperature': 0.1,
            'messages': [
              {
                'role': 'user',
                'content': PlanningService.prompt(base, scenario.value,
                    now: DateTime(2026, 9, 20))
              }
            ],
          });
      final proposal = AITransport.object(response);
      if (scenario.key == 'ambiguous') {
        expect(proposal['questions'], isNotEmpty);
        expect(proposal['actions'], isEmpty);
      } else {
        final result = PlanningEngine.apply(base, proposal);
        expect(PlanningEngine.conflicts(result), isEmpty);
        expect(base['courses'][0]['schedules'][0]['weekPattern'], [4, 5, 6]);
        final courses = result['courses'] as List;
        bool containsSlot(String name, int day, int week) => courses.any((c) =>
            (c['name'] as String).contains(name) &&
            (c['schedules'] as List).any((s) =>
                s['weekday'] == day &&
                (s['weekPattern'] as List).contains(week)));
        if (scenario.key == 'move' || scenario.key == 'emergency') {
          expect(containsSlot('化学', 6, 4), isTrue);
          expect(containsSlot('化学', 1, 4), isFalse);
          expect(containsSlot('化学', 1, 5), isTrue);
        }
        if (scenario.key == 'rest') {
          expect(result['settings']['holidays'],
              contains(startsWith('2026-09-21')));
          expect(containsSlot('化学', 6, 4), isTrue);
        }
        if (scenario.key == 'emergency') {
          expect(containsSlot('会议', 1, 4), isTrue);
        }
        if (scenario.key == 'add') expect(containsSlot('自习', 7, 5), isTrue);
      }
      // No credentials are present in the proposal; safe for local test evidence.
      // ignore: avoid_print
      print('VERIFIED ${scenario.key}: ${proposal['summary']}');
    },
        skip: key == null
            ? 'Set YICLASS_TEST_API_KEY to run actual API requests'
            : false,
        timeout: const Timeout(Duration(minutes: 2)));
  }
}
