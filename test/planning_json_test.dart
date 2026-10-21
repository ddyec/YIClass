import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:yiclass/services/ai/planning_engine.dart';
import 'package:yiclass/services/ai/planning_diff.dart';
import 'package:yiclass/services/ai/planning_service.dart';
import 'package:yiclass/services/file_service.dart';
import 'planning_engine_test.dart' as f;

void main() {
  test('complete JSON can move a historical day and preview exact changes', () {
    final base = f.fixture();
    final original = jsonEncode(base);
    final edited = PlanningEngine.clone(base)..['events'] = [];
    edited['courses'][0]['schedules'][0]['weekPattern'] = [5, 6];
    edited['courses'].add({
      ...Map<String, dynamic>.from(base['courses'][0]),
      'schedules': [
        {
          'weekday': 7,
          'periods': [1, 2],
          'weekPattern': [7],
        },
      ],
    });
    final result = PlanningEngine.apply(base, {
      'summary': '调课',
      'questions': [],
      'timetable': edited,
    });
    final changes = PlanningDiff.between(base, result);
    expect(changes.single.title, '化学');
    expect(changes.single.before, contains('2026-09-21'));
    expect(changes.single.after, contains('2026-10-18'));
    expect(jsonEncode(base), original);
    expect(
      FileService.toMap(FileService.fromMap(result))['courses'],
      result['courses'],
    );
  });

  test(
    'full JSON permits event overlap with an empty location for preview',
    () {
      final base = f.fixture(), edited = PlanningEngine.clone(f.fixture());
      edited['events'] = [
        {
          'id': 'meeting',
          'name': '会议',
          'location': '',
          'start': '2026-09-21T08:43:00',
          'end': '2026-09-21T09:15:00',
        },
      ];
      edited['id'] = 99;
      final result = PlanningEngine.apply(base, {
        'questions': [],
        'timetable': edited,
      });
      expect(result['id'], base['id']);
      expect(PlanningEngine.conflicts(result), isNotEmpty);
      expect(
        PlanningDiff.between(base, result).single.after,
        contains('08:43'),
      );
      expect(base['events'], isNull);
    },
  );

  test('partial JSON and invalid schedules cannot be applied', () {
    final base = f.fixture();
    expect(
      () => PlanningEngine.apply(base, {
        'questions': [],
        'timetable': {'courses': []},
      }),
      throwsFormatException,
    );
    final edited = PlanningEngine.clone(base)..['events'] = [];
    edited['courses'][0]['schedules'][0]['weekday'] = 9;
    expect(
      () => PlanningEngine.apply(base, {'questions': [], 'timetable': edited}),
      throwsFormatException,
    );
  });

  test('date index reads original slots on holidays without guessing', () {
    final base = f.fixture();
    base['settings']['holidays'] = ['2026-09-21T00:00:00.000'];
    final day = PlanningEngine.calendar(
      base,
    ).singleWhere((d) => d['date'] == '2026-09-21');
    expect(day['week'], 4);
    expect(day['rest'], isTrue);
    expect((day['classes'] as List).single['courseIndex'], 0);
    expect((day['classes'] as List).single['periods'], [1, 2]);
    final prompt = PlanningService.prompt(
      base,
      '照通知调课',
      now: DateTime(2026, 10, 21, 19, 52),
    );
    expect(prompt, contains('2026-10-21T19:52'));
    expect(prompt, contains('"date":"2026-09-21"'));
  });
}
