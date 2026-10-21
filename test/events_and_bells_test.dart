import 'package:flutter_test/flutter_test.dart';
import 'package:yiclass/services/timetable/bell_schedule.dart';
import 'package:yiclass/services/ai/planning_engine.dart';
import 'package:yiclass/services/file_service.dart';
import 'planning_engine_test.dart' as f;

void main() {
  test('4/4/2 defaults preserve ten minute and twenty minute breaks and lunch',
      () {
    final times = BellSchedule.generate();
    expect(times.length, 10);
    expect(times.map((t) => t.startTime), [
      '08:30',
      '09:25',
      '10:30',
      '11:25',
      '14:30',
      '15:25',
      '16:30',
      '17:25',
      '19:00',
      '19:55'
    ]);
    expect(times[0].endTime, '09:15');
    final custom = BellSchedule.generate(
        morningPeriods: 3,
        afternoonPeriods: 3,
        eveningPeriods: 1,
        shortBreak: 15,
        longBreak: 30);
    expect(custom.length, 7);
    expect(custom[1].startTime, '09:30');
    expect(custom[2].startTime, '10:45');
    expect(custom[3].startTime, '14:30');
    expect(() => BellSchedule.generate(afternoon: 600), throwsFormatException);
  });
  test('minute precise cross-day events persist, undo and keep courses intact',
      () {
    final base = f.fixture();
    final result = PlanningEngine.apply(
        base,
        f.plan([
          {
            'type': 'event',
            'event': {
              'id': 'e',
              'name': '值班',
              'location': '办公室',
              'start': '2026-09-26T22:13:00',
              'end': '2026-09-27T01:07:00'
            }
          }
        ]));
    expect(result['courses'], base['courses']);
    final saved = FileService.toMap(FileService.fromMap(result));
    expect(saved['events'], result['events']);
    final undone = PlanningEngine.apply(
        saved,
        f.plan([
          {'type': 'removeEvent', 'eventId': 'e'}
        ]));
    expect(undone['events'], isEmpty);
    expect(base.containsKey('events'), false);
  });
  test('events detect real clock overlap but allow exact end boundaries', () {
    Map<String, dynamic> event(String a, String b) => {
          'type': 'event',
          'event': {
            'id': 'e',
            'name': '会议',
            'start': '2026-09-21T$a:00',
            'end': '2026-09-21T$b:00'
          }
        };
    expect(
        () => PlanningEngine.apply(
            f.fixture(), f.plan([event('08:45', '09:00')])),
        throwsFormatException);
    expect(
        PlanningEngine.apply(
            f.fixture(), f.plan([event('08:15', '08:30')]))['events'],
        hasLength(1));
    expect(
        () => PlanningEngine.apply(
            f.fixture(), f.plan([event('08:45', '08:30')])),
        throwsFormatException);
  });
}
