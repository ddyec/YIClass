import 'dart:convert';
import 'dart:math';
import 'package:uuid/uuid.dart';

typedef J = Map<String, dynamic>;
String uid() => const Uuid().v4();
J copy(J value) => jsonDecode(jsonEncode(value)) as J;
DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
String dateText(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String clock(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
int minute(DateTime d) => d.hour * 60 + d.minute;
DateTime at(DateTime d, int m) =>
    DateTime(d.year, d.month, d.day, m ~/ 60, m % 60);
List<J> objects(dynamic value) =>
    (value as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
List<int> numbers(dynamic value) => (value as List).cast<int>();
void require(bool ok, String message) {
  if (!ok) throw FormatException(message);
}

J newTable({String name = '我的课表', DateTime? start}) => {
  'id': uid(),
  'name': name,
  'startDate': dateText(
    start ??
        day(
          DateTime.now(),
        ).subtract(Duration(days: DateTime.now().weekday - 1)),
  ),
  'totalWeeks': 20,
  'showWeekend': true,
  'holidays': <String>[],
  'courses': <J>[],
};
J fresh() {
  final table = newTable();
  return {
    'schemaVersion': 1,
    'revision': 0,
    'selectedID': table['id'],
    'timetables': [table],
    'timeProfile': {
      'sessionCounts': [4, 4, 2],
      'periods': [480, 535, 600, 655, 840, 895, 960, 1015, 1140, 1195]
          .asMap()
          .entries
          .map(
            (e) => {'period': e.key + 1, 'start': e.value, 'end': e.value + 45},
          )
          .toList(),
    },
    'todos': <J>[],
    'placements': <J>[],
    'chats': <J>[],
    'theme': 'system',
    'accent': 0xff3785f6,
    'gradient': true,
    'reminderMinutes': 10,
    'reminders': false,
  };
}

J selected(J data) => objects(
  data['timetables'],
).firstWhere((t) => t['id'] == data['selectedID']);
int weekFor(J table, DateTime date) {
  final start = DateTime.parse(table['startDate']);
  final monday = day(start).subtract(Duration(days: start.weekday - 1));
  // UTC day ordinals avoid DST changing the academic week.
  return (DateTime.utc(date.year, date.month, date.day)
                  .difference(
                    DateTime.utc(monday.year, monday.month, monday.day),
                  )
                  .inDays /
              7)
          .floor() +
      1;
}

void validate(J d) {
  require(d['schemaVersion'] == 1, '数据版本不受支持');
  final periods = objects(d['timeProfile']['periods']);
  final counts = numbers(d['timeProfile']['sessionCounts']);
  require(
    periods.isNotEmpty &&
        periods.length <= 20 &&
        counts.length == 3 &&
        counts.every((n) => n >= 0) &&
        counts.reduce((a, b) => a + b) == periods.length,
    '课节数量无效',
  );
  for (var i = 0; i < periods.length; i++) {
    final p = periods[i];
    require(
      p['period'] == i + 1 &&
          p['start'] is int &&
          p['end'] is int &&
          p['start'] >= 0 &&
          p['end'] < 1440 &&
          p['start'] < p['end'],
      '第 ${i + 1} 节时间无效',
    );
    if (i > 0) require(periods[i - 1]['end'] <= p['start'], '课节时间重叠');
  }
  final tables = objects(d['timetables']);
  require(
    tables.isNotEmpty &&
        tables.length <= 100 &&
        tables.map((t) => t['id']).toSet().length == tables.length &&
        tables.any((t) => t['id'] == d['selectedID']),
    '当前课表或标识无效',
  );
  for (final t in tables) {
    require(
      (t['name'] as String).trim().isNotEmpty &&
          t['totalWeeks'] is int &&
          t['totalWeeks'] >= 1 &&
          t['totalWeeks'] <= 60,
      '课表名称或学期周数无效',
    );
    DateTime.parse(t['startDate']);
    for (final h in t['holidays'] as List) {
      DateTime.parse(h);
    }
    final courses = objects(t['courses']);
    require(
      courses.length <= 500 &&
          courses.map((c) => c['id']).toSet().length == courses.length,
      '课程数量或标识无效',
    );
    for (final c in courses) {
      require(
        (c['name'] as String).trim().isNotEmpty && c['name'].length <= 120,
        '课程名称无效',
      );
      final schedules = objects(c['schedules']);
      final unscheduled = c['unscheduledWeeks'];
      require(
        schedules.isNotEmpty || (unscheduled is List && unscheduled.isNotEmpty),
        '请设置课程安排或未排课周次',
      );
      void weeks(dynamic w) {
        final v = numbers(w);
        require(
          v.isNotEmpty &&
              v.toSet().length == v.length &&
              v.every((n) => n >= 1 && n <= t['totalWeeks']),
          '周次超出学期范围',
        );
      }

      if (unscheduled != null) weeks(unscheduled);
      for (final s in schedules) {
        require(
          s['weekday'] is int && s['weekday'] >= 1 && s['weekday'] <= 7,
          '星期无效',
        );
        final ps = numbers(s['periods']);
        require(
          ps.isNotEmpty &&
              ps.toSet().length == ps.length &&
              ps.every((n) => n >= 1 && n <= periods.length),
          '课程节次超出设置范围',
        );
        weeks(s['weekPattern']);
      }
    }
  }
  final todos = objects(d['todos']);
  require(todos.map((t) => t['id']).toSet().length == todos.length, '待办标识重复');
  for (final t in todos) {
    require(
      (t['title'] as String).trim().isNotEmpty &&
          t['title'].length <= 200 &&
          (t['notes'] as String).length <= 10000 &&
          ['low', 'normal', 'high'].contains(t['importance']),
      '待办标题、备注或重要程度无效',
    );
    for (final key in ['deadline', 'createdAt', 'completedAt']) {
      if (t[key] != null) DateTime.parse(t[key]);
    }
  }
  final placements = objects(d['placements']);
  require(
    placements.map((p) => p['todoID']).toSet().length == placements.length,
    '同一待办存在重复安排',
  );
  for (final p in placements) {
    require(todos.any((t) => t['id'] == p['todoID']), '日程引用了不存在的待办');
    final a = DateTime.parse(p['start']), b = DateTime.parse(p['end']);
    require(
      b.isAfter(a) && b.difference(a) <= const Duration(days: 7),
      '日程结束须晚于开始，且不超过七天',
    );
  }
}

List<J> lessons(J data, DateTime date) {
  final table = selected(data), week = weekFor(table, date);
  if (week < 1 ||
      week > table['totalWeeks'] ||
      (table['holidays'] as List).any(
        (h) => dateText(DateTime.parse(h)) == dateText(date),
      )) {
    return [];
  }
  final periods = objects(data['timeProfile']['periods']);
  final result = <J>[];
  for (final c in objects(table['courses'])) {
    for (final s in objects(c['schedules'])) {
      if (s['weekday'] != date.weekday ||
          !(s['weekPattern'] as List).contains(week)) {
        continue;
      }
      final ps = numbers(s['periods'])..sort();
      // Separate nonconsecutive periods into blocks rather than inventing a long class.
      final blocks = <List<int>>[];
      for (final p in ps) {
        if (blocks.isEmpty || blocks.last.last + 1 != p) blocks.add([]);
        blocks.last.add(p);
      }
      for (final block in blocks) {
        result.add({
          'id': '${c['id']}-${s['weekday']}-${block.first}',
          'sourceID': c['id'],
          'kind': 'course',
          'title': c['name'],
          'subtitle': [
            c['location'],
            c['teacher'],
          ].where((x) => x.toString().isNotEmpty).join(' · '),
          'color': c['color'],
          'start': at(
            date,
            periods[block.first - 1]['start'],
          ).toIso8601String(),
          'end': at(date, periods[block.last - 1]['end']).toIso8601String(),
          'periods': block,
        });
      }
    }
  }
  result.sort((a, b) => a['start'].compareTo(b['start']));
  return result;
}

List<J> timeline(J data, DateTime date) {
  final result = lessons(data, date);
  for (final p in objects(data['placements'])) {
    if (!DateTime.parse(
          p['start'],
        ).isBefore(day(date).add(const Duration(days: 1))) ||
        !DateTime.parse(p['end']).isAfter(day(date))) {
      continue;
    }
    final t = objects(data['todos']).firstWhere((t) => t['id'] == p['todoID']);
    result.add({
      'id': t['id'],
      'sourceID': t['id'],
      'kind': 'todo',
      'completed': t['completedAt'] != null,
      'title': t['title'],
      'subtitle': t['completedAt'] == null ? '待办' : '已完成',
      'color': urgencyColor(t, date),
      'start': p['start'],
      'end': p['end'],
    });
  }
  result.sort((a, b) => a['start'].compareTo(b['start']));
  return result;
}

List<J> lanes(List<J> items) {
  final sorted = items.map(copy).toList()
    ..sort((a, b) => a['start'].compareTo(b['start']));
  final result = <J>[], cluster = <J>[];
  var clusterEnd = -1;
  void flush() {
    final ends = <int>[];
    for (final item in cluster) {
      final start = minute(DateTime.parse(item['start']));
      var lane = ends.indexWhere((end) => end <= start);
      if (lane < 0) {
        lane = ends.length;
        ends.add(0);
      }
      ends[lane] = max(start + 35, minute(DateTime.parse(item['end'])));
      item['lane'] = lane;
    }
    for (final item in cluster) {
      item['lanes'] = ends.length;
      result.add(item);
    }
    cluster.clear();
  }

  for (final item in sorted) {
    final start = minute(DateTime.parse(item['start']));
    if (cluster.isNotEmpty && start >= clusterEnd) {
      flush();
      clusterEnd = -1;
    }
    cluster.add(item);
    clusterEnd = max(
      clusterEnd,
      max(start + 35, minute(DateTime.parse(item['end']))),
    );
  }
  flush();
  return result;
}

String urgency(J t, DateTime now) {
  if (t['completedAt'] != null) return '已完成';
  if (t['deadline'] == null) return '未设截止时间';
  final due = DateTime.parse(t['deadline']);
  if (due.isBefore(now)) return '已逾期';
  final delta = day(due).difference(day(now)).inDays;
  return delta == 0
      ? '今日截止'
      : delta <= 3
      ? '三天内截止'
      : '稍后截止';
}

int urgencyColor(J t, DateTime now) => switch (urgency(t, now)) {
  '已完成' => 0xff298f84,
  '已逾期' => 0xffd36d71,
  '今日截止' => 0xffbd813b,
  '三天内截止' => 0xffa78a32,
  '稍后截止' => 0xff658aab,
  _ => 0xff7a8292,
};
int score(J t, DateTime now) {
  final weight = switch (t['importance']) {
    'high' => 40,
    'normal' => 20,
    _ => 0,
  };
  if (t['deadline'] == null) return weight;
  final days = day(DateTime.parse(t['deadline'])).difference(day(now)).inDays;
  return weight +
      (days < 0
          ? 100
          : days == 0
          ? 80
          : days == 1
          ? 60
          : days <= 3
          ? 35
          : days <= 7
          ? 15
          : 0);
}

List<int> parseRange(String text, int maxValue) {
  final result = <int>{};
  for (final part in text.replaceAll('，', ',').split(',')) {
    final bits = part.trim().split(RegExp(r'[-–]'));
    require(bits.length <= 2, '使用 1-4,6 这样的格式');
    final a = int.parse(bits[0]), b = bits.length == 1 ? a : int.parse(bits[1]);
    require(a >= 1 && b >= a && b <= maxValue, '范围应为 1–$maxValue');
    for (var i = a; i <= b; i++) {
      result.add(i);
    }
  }
  return result.toList()..sort();
}

J importTable(J envelope, J data) {
  final settings = envelope['settings'] as Map? ?? envelope;
  final table = newTable(
    name: envelope['name'] ?? '导入课表',
    start: DateTime.parse(settings['startDate'] ?? selected(data)['startDate']),
  );
  table['totalWeeks'] = settings['totalWeeks'] ?? 20;
  table['showWeekend'] = settings['showWeekend'] ?? true;
  table['holidays'] = settings['holidays'] ?? [];
  table['courses'] = objects(envelope['courses'])
      .map(
        (c) => {
          'id': uid(),
          'name': c['name'],
          'teacher': c['teacher'] ?? '',
          'location': c['location'] ?? '',
          'color': c['color'] ?? 0xff637eea,
          'schedules': objects(c['schedules'] ?? [])
              .map(
                (s) => {
                  'weekday': s['weekday'] ?? s['day'],
                  'periods': s['periods'],
                  'weekPattern': s['weekPattern'],
                },
              )
              .toList(),
          if (c['unscheduledWeeks'] != null)
            'unscheduledWeeks': c['unscheduledWeeks'],
        },
      )
      .toList();
  final test = copy(data);
  (test['timetables'] as List).add(table);
  test['selectedID'] = table['id'];
  validate(test);
  return table;
}

J exportTable(J data) {
  final t = selected(data);
  return {
    'version': '3.3',
    'name': t['name'],
    'settings': {
      'startDate': t['startDate'],
      'totalWeeks': t['totalWeeks'],
      'showWeekend': t['showWeekend'],
      'holidays': t['holidays'],
    },
    'timeProfile': data['timeProfile'],
    'courses': t['courses'],
  };
}

void resizeSessions(J d, List<int> counts) {
  require(
    counts.length == 3 &&
        counts.every((n) => n >= 0 && n <= 12) &&
        counts.reduce((a, b) => a + b) >= 1 &&
        counts.reduce((a, b) => a + b) <= 20,
    '每天应有 1–20 节',
  );
  final old = numbers(d['timeProfile']['sessionCounts']),
      periods = objects(d['timeProfile']['periods']);
  final mapping = <int, int>{}, result = <J>[];
  var oldOffset = 0, newOffset = 0;
  for (var g = 0; g < 3; g++) {
    for (var i = 0; i < counts[g]; i++) {
      final start = i < old[g]
          ? periods[oldOffset + i]['start']
          : (i == 0 ? [480, 840, 1140][g] : result.last['end'] + 10);
      result.add({
        'period': result.length + 1,
        'start': start,
        'end': i < old[g] ? periods[oldOffset + i]['end'] : start + 45,
      });
      if (i < old[g]) mapping[oldOffset + i + 1] = newOffset + i + 1;
    }
    oldOffset += old[g];
    newOffset += counts[g];
  }
  for (final t in d['timetables'] as List) {
    for (final c in t['courses'] as List) {
      for (final s in c['schedules'] as List) {
        require(
          numbers(s['periods']).every(mapping.containsKey),
          '有课程使用了将删除的课节，请先调整课程',
        );
        s['periods'] = numbers(s['periods']).map((p) => mapping[p]!).toList();
      }
    }
  }
  d['timeProfile'] = {'sessionCounts': counts, 'periods': result};
}
