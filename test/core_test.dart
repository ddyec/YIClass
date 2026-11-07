import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yiclass/src/model.dart';
import 'package:yiclass/src/store.dart';
import 'package:yiclass/src/assistant.dart';

J fixture() {
  final d = fresh();
  final t = d['timetables'][0];
  t['startDate'] = '2026-09-07';
  t['courses'] = [
    {
      'id': 'course-1',
      'name': '实验课',
      'teacher': '李老师',
      'location': 'A301',
      'color': 0xff637eea,
      'schedules': [
        {
          'weekday': 1,
          'periods': [1, 2, 5],
          'weekPattern': [1, 3, 5],
        },
      ],
    },
  ];
  return d;
}

J todo(String id, {String? deadline}) => {
  'id': id,
  'title': '实验报告',
  'notes': '',
  'deadline': deadline,
  'importance': 'normal',
  'createdAt': '2026-09-01T10:00:00',
  'completedAt': null,
};
void main() {
  test('fresh data and stable academic week boundaries', () {
    final d = fixture();
    validate(d);
    expect(weekFor(selected(d), DateTime(2026, 9, 6)), 0);
    expect(weekFor(selected(d), DateTime(2026, 9, 13)), 1);
    expect(weekFor(selected(d), DateTime(2026, 9, 14)), 2);
  });
  test('odd weeks, holidays, and separated blocks are respected', () {
    final d = fixture();
    final events = lessons(d, DateTime(2026, 9, 7));
    expect(events.length, 2);
    expect(events[0]['periods'], [1, 2]);
    expect(events[1]['periods'], [5]);
    expect(lessons(d, DateTime(2026, 9, 14)), isEmpty);
    d['timetables'][0]['holidays'] = ['2026-09-07'];
    expect(lessons(d, DateTime(2026, 9, 7)), isEmpty);
  });
  test(
    'resizing sessions remaps every table and protects occupied periods',
    () {
      final d = fixture();
      resizeSessions(d, [5, 4, 2]);
      validate(d);
      expect(d['timetables'][0]['courses'][0]['schedules'][0]['periods'], [
        1,
        2,
        6,
      ]);
      expect(() => resizeSessions(d, [1, 4, 2]), throwsFormatException);
    },
  );
  test(
    'iOS interchange roundtrip preserves every schedule and unplanned course',
    () {
      final d = fixture();
      (d['timetables'][0]['courses'] as List).add({
        'id': 'unplanned',
        'name': '军训',
        'teacher': '',
        'location': '',
        'color': 0xff298f84,
        'schedules': [],
        'unscheduledWeeks': [1, 2],
      });
      final encoded = jsonDecode(jsonEncode(exportTable(d))) as J;
      final t = importTable(encoded, d);
      expect(
        t['courses'][0]['schedules'],
        d['timetables'][0]['courses'][0]['schedules'],
      );
      expect(t['courses'][1]['unscheduledWeeks'], [1, 2]);
      expect(t['id'], isNot(selected(d)['id']));
      expect(d['timetables'].length, 1);
    },
  );
  test('invalid week and period imports cannot partially apply', () {
    final d = fixture(), envelope = exportTable(d);
    envelope['courses'] = jsonDecode(jsonEncode(envelope['courses']));
    envelope['courses'][0]['schedules'][0]['periods'] = [21];
    expect(() => importTable(envelope, d), throwsFormatException);
    expect(d['timetables'].length, 1);
  });
  test(
    'deadline and placement are independent and deletion removes references',
    () {
      final d = fixture();
      d['todos'] = [todo('t', deadline: '2026-09-20T23:59:00')];
      d['placements'] = [
        {
          'todoID': 't',
          'start': '2026-09-07T08:00:00',
          'end': '2026-09-07T09:00:00',
        },
      ];
      validate(d);
      expect(
        timeline(
          d,
          DateTime(2026, 9, 7),
        ).where((e) => e['kind'] == 'todo').length,
        1,
      );
      expect(d['todos'][0]['deadline'], '2026-09-20T23:59:00');
      applyOperations(d, [
        {'type': 'delete_todo', 'id': 't'},
      ]);
      expect(d['placements'], isEmpty);
    },
  );
  test('overlapping timeline cluster uses separate lanes', () {
    final items = [
      {'id': 'a', 'start': '2026-09-07T08:00:00', 'end': '2026-09-07T09:00:00'},
      {'id': 'b', 'start': '2026-09-07T08:30:00', 'end': '2026-09-07T09:30:00'},
      {'id': 'c', 'start': '2026-09-07T10:00:00', 'end': '2026-09-07T11:00:00'},
    ];
    final allocated = lanes(items);
    expect(allocated[0]['lanes'], 2);
    expect(allocated[1]['lane'], 1);
    expect(allocated[2]['lanes'], 1);
  });
  test('urgency text and importance weighting are date aware', () {
    final t = todo('t', deadline: '2026-09-07T18:00:00');
    expect(urgency(t, DateTime(2026, 9, 7, 12)), '今日截止');
    expect(urgency(t, DateTime(2026, 9, 7, 19)), '已逾期');
    final low = score(t, DateTime(2026, 9, 7));
    t['importance'] = 'high';
    expect(score(t, DateTime(2026, 9, 7)), low + 20);
  });
  test('zero duration, duplicate and dangling placements are rejected', () {
    final d = fixture();
    d['todos'] = [todo('t')];
    d['placements'] = [
      {
        'todoID': 't',
        'start': '2026-09-07T08:00:00',
        'end': '2026-09-07T08:00:00',
      },
    ];
    expect(() => validate(d), throwsFormatException);
    d['placements'][0]['end'] = '2026-09-07T09:00:00';
    d['placements'][0]['todoID'] = 'missing';
    expect(() => validate(d), throwsFormatException);
  });
  test('AI refuses unknown targets and unsupported operations', () {
    final d = fixture();
    expect(
      () => applyOperations(d, [
        {'type': 'delete_course', 'id': 'missing'},
      ]),
      throwsFormatException,
    );
    expect(
      () => applyOperations(d, [
        {'type': 'wipe_database'},
      ]),
      throwsFormatException,
    );
  });
  test(
    'transaction queue, disk restart, stale AI rejection, undo and recovery',
    () async {
      final dir = await Directory.systemTemp.createTemp('yiclass-store');
      addTearDown(() => dir.delete(recursive: true));
      final s = Store(dir);
      await Future.wait([
        s.commit((d) => d['accent'] = 0xff298f84),
        s.commit((d) => d['gradient'] = false),
      ]);
      expect(s.revision, 2);
      expect(s.data['gradient'], false);
      expect(s.data['accent'], 0xff298f84);
      final disk = Store(dir);
      await disk.load();
      expect(disk.data, s.data);
      final revision = s.revision;
      await expectLater(
        s.commit((d) => d['accent'] = 1, expectedRevision: 0),
        throwsStateError,
      );
      expect(s.revision, revision);
      await expectLater(
        s.commit((d) => d['timetables'] = []),
        throwsFormatException,
      );
      expect(s.revision, revision);
      await s.undo();
      expect(s.data['gradient'], true);
      await s.file.writeAsString('{broken');
      final corrupt = Store(dir);
      await corrupt.load();
      expect(corrupt.error, isNotNull);
      await expectLater(
        corrupt.commit((d) => d['gradient'] = true),
        throwsStateError,
      );
      expect(await corrupt.file.readAsString(), '{broken');
      await corrupt.recover();
      expect(corrupt.error, isNull);
      validate(corrupt.data);
    },
  );
  test('invalid AI batch leaves disk and memory untouched', () async {
    final dir = await Directory.systemTemp.createTemp('yiclass-ai');
    addTearDown(() => dir.delete(recursive: true));
    final s = Store(dir);
    await s.commit((d) => d['todos'] = [todo('t')]);
    final before = copy(s.data);
    await expectLater(
      s.commit(
        (d) => applyOperations(d, [
          {'type': 'complete_todo', 'id': 't', 'completed': true},
          {'type': 'delete_course', 'id': 'missing'},
        ]),
      ),
      throwsFormatException,
    );
    expect(s.data, before);
    expect(jsonDecode(await s.file.readAsString()), before);
  });
}
