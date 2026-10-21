import 'package:flutter_test/flutter_test.dart';
import 'package:yiclass/services/ai/planning_engine.dart';
import 'package:yiclass/services/file_service.dart';
import 'package:yiclass/services/timetable/query_service.dart';
import 'package:yiclass/utils/get_weekday.dart';

Map<String, dynamic> fixture() => {
      'id': 3,
      'name': '测试课表',
      'settings': {
        'startDate': '2026-08-31T00:00:00.000',
        'totalWeeks': 20,
        'maxPeriods': 10,
        'showWeekend': true,
        'holidays': <String>[],
        'classTimes': [
          for (var p = 1; p <= 10; p++)
            {
              'period': p,
              'startTime': '${(7 + p).toString().padLeft(2, '0')}:30',
              'endTime': '${(8 + p).toString().padLeft(2, '0')}:15'
            }
        ]
      },
      'courses': [
        {
          'name': '化学',
          'location': 'A101',
          'teacher': '甲',
          'color': 4280391411,
          'schedules': [
            {
              'weekday': 1,
              'periods': [1, 2],
              'weekPattern': [4, 5, 6]
            }
          ]
        },
        {
          'name': '数学',
          'location': 'A102',
          'teacher': '乙',
          'color': 4280391411,
          'schedules': [
            {
              'weekday': 2,
              'periods': [1, 2],
              'weekPattern': [4, 6]
            }
          ]
        },
        {
          'name': '网课',
          'location': '线上',
          'teacher': '',
          'color': 4280391411,
          'schedules': []
        },
      ],
    };

Map<String, dynamic> plan(List<Map<String, dynamic>> actions) =>
    {'summary': '测试', 'questions': [], 'actions': actions};
Map<String, dynamic> move({int day = 6}) => {
      'type': 'move',
      'courseIndex': 0,
      'scheduleIndex': 0,
      'weeks': [4],
      'targetWeeks': [4],
      'targetWeekday': day,
      'targetPeriods': [1, 2]
    };

void main() {
  test('move one occurrence, preserve other weeks and baseline', () {
    final base = fixture();
    final next = PlanningEngine.apply(base, plan([move()]));
    expect(base['courses'][0]['schedules'][0]['weekPattern'], [4, 5, 6]);
    expect(next['courses'][0]['schedules'][0]['weekPattern'], [5, 6]);
    expect(next['courses'].last['schedules'][0]['weekPattern'], [4]);
    expect(next['courses'][1], base['courses'][1]);
    expect(next['courses'][2]['schedules'], isEmpty);
  });
  test('reject collisions including same-name overlapping schedules', () {
    expect(() => PlanningEngine.apply(fixture(), plan([move(day: 2)])),
        throwsFormatException);
    final base = fixture();
    base['courses'][1]['name'] = '化学';
    expect(() => PlanningEngine.apply(base, plan([move(day: 2)])),
        throwsFormatException);
  });
  test('odd/even weeks do not conflict', () {
    final a = move(day: 2)
      ..['weeks'] = [5]
      ..['targetWeeks'] = [5];
    expect(PlanningEngine.conflicts(PlanningEngine.apply(fixture(), plan([a]))),
        isEmpty);
  });
  test('cancel only selected week; duplicate operations are rejected', () {
    final a = {
      'type': 'cancel',
      'courseIndex': 0,
      'scheduleIndex': 0,
      'weeks': [4]
    };
    final next = PlanningEngine.apply(fixture(), plan([a]));
    expect(next['courses'][0]['schedules'][0]['weekPattern'], [5, 6]);
    expect(() => PlanningEngine.apply(fixture(), plan([a, a])),
        throwsFormatException);
  });
  test('holiday + makeup retains original pattern and suppresses holiday', () {
    final a = move()..['type'] = 'copy';
    final next = PlanningEngine.apply(
        fixture(),
        plan([
          {'type': 'rest', 'date': '2026-09-21'},
          a
        ]));
    final timetable = FileService.fromMap(next);
    expect(QueryService.dayCourses(timetable, 4, 1), isEmpty);
    expect(QueryService.periodCourse(timetable, 4, 1, 1), isNull);
    expect(QueryService.dayCourses(timetable, 4, 6).single.name, '化学');
    expect(QueryService.dayCourses(timetable, 5, 1).single.name, '化学');
  });
  test('cannot move into holiday or invent source weeks/indices', () {
    expect(
        () => PlanningEngine.apply(
            fixture(),
            plan([
              {'type': 'rest', 'date': '2026-09-26'},
              move()
            ])),
        throwsFormatException);
    expect(
        () => PlanningEngine.apply(
            fixture(),
            plan([
              move()..['weeks'] = [9]
            ])),
        throwsFormatException);
    expect(
        () => PlanningEngine.apply(
            fixture(), plan([move()..['courseIndex'] = 99])),
        throwsFormatException);
    expect(
        () => PlanningEngine.apply(
            fixture(),
            plan([
              move()..['targetPeriods'] = [1]
            ])),
        throwsFormatException);
  });
  test('ambiguous questions, invalid numbers and unknown operations block', () {
    expect(
        () => PlanningEngine.apply(
            fixture(), plan([move()])..['questions'] = ['哪一周？']),
        throwsFormatException);
    expect(
        () => PlanningEngine.apply(
            fixture(),
            plan([
              {'type': 'deleteEverything'}
            ])),
        throwsFormatException);
    final base = fixture();
    base['courses'][0]['schedules'][0]['periods'] = [1, 1];
    expect(() => PlanningEngine.validate(base), throwsFormatException);
  });
  test('file roundtrip keeps class times and unscheduled courses', () {
    final base = fixture();
    final result = FileService.toMap(FileService.fromMap(base));
    expect(result['settings']['classTimes'], base['settings']['classTimes']);
    expect(result['courses'], base['courses']);
  });
  test('Thursday opening date anchors calendar week to Monday', () {
    expect(
        getWeekInfo(
            DateTime(2026, 9, 7), DateTime(2026, 9, 3), 20)!['weekIndex'],
        2);
    expect(
        getWeekInfo(DateTime(2026, 8, 30), DateTime(2026, 9, 3), 20), isNull);
  });
}
