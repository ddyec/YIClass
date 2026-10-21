import 'dart:convert';

/// AI only proposes operations. This deterministic engine validates and applies
/// them to an isolated snapshot; persistence always requires a separate action.
class PlanningEngine {
  static Map<String, dynamic> clone(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

  static List<int> integers(dynamic value, int min, int max) {
    if (value is! List ||
        value.isEmpty ||
        value.any((v) => v is! int || v < min || v > max) ||
        value.toSet().length != value.length) {
      throw FormatException('无效范围：需要 $min–$max 的非重复整数');
    }
    return value.cast<int>().toList()..sort();
  }

  static DateTime monday(Map settings) {
    final d = DateTime.parse(settings['startDate'] as String);
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  static void validate(Map<String, dynamic> data) {
    if (data['name'] is! String ||
        (data['name'] as String).trim().isEmpty ||
        data['courses'] is! List) {
      throw const FormatException('课表需要名称和课程列表');
    }
    final settings = data['settings'] as Map? ?? {};
    final weeks = settings['totalWeeks'] ?? 20;
    final periods = settings['maxPeriods'] ?? 16;
    if (weeks is! int ||
        weeks < 1 ||
        weeks > 20 ||
        periods is! int ||
        periods < 1 ||
        periods > 16) {
      throw const FormatException('周数或节次数超出范围');
    }
    for (final c in data['courses']) {
      if (c is! Map ||
          c['name'] is! String ||
          (c['name'] as String).trim().isEmpty ||
          c['schedules'] is! List) {
        throw const FormatException('课程格式错误');
      }
      // Empty schedules intentionally preserve unscheduled/online courses.
      for (final s in c['schedules']) {
        if (s is! Map ||
            s['weekday'] is! int ||
            s['weekday'] < 1 ||
            s['weekday'] > 7) {
          throw const FormatException('星期需要为 1–7');
        }
        integers(s['periods'], 1, periods);
        integers(s['weekPattern'], 1, weeks);
      }
    }
    final ids = <String>{};
    for (final e in data['events'] as List? ?? []) {
      if (e is! Map ||
          e['id'] is! String ||
          (e['id'] as String).isEmpty ||
          !ids.add(e['id']) ||
          e['name'] is! String ||
          (e['name'] as String).trim().isEmpty) {
        throw const FormatException('事件需要名称与唯一标识');
      }
      eventTime(e['start']);
      eventTime(e['end']);
      if (!eventTime(e['end']).isAfter(eventTime(e['start']))) {
        throw const FormatException('事件结束时间必须晚于开始时间');
      }
    }
  }

  static DateTime eventTime(dynamic value) {
    if (value is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$').hasMatch(value)) {
      throw const FormatException('事件时间需为本地 yyyy-MM-ddTHH:mm:ss');
    }
    final d = DateTime.tryParse(value);
    if (d == null ||
        '${_day(d)}T${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}' !=
            value) {
      throw const FormatException('事件日期或时间无效');
    }
    return d;
  }

  static Map<String, dynamic> apply(
    Map<String, dynamic> baseline,
    Map<String, dynamic> plan,
  ) {
    validate(baseline);
    if (plan['questions'] is! List || (plan['questions'] as List).isNotEmpty) {
      throw const FormatException('请先补充 AI 提出的问题，再生成方案');
    }
    // The assistant may edit the complete JSON snapshot. Always validate a copy;
    // only the preview page can persist it, and the local timetable ID is fixed.
    if (plan.containsKey('timetable')) {
      final value = plan['timetable'];
      if (value is! Map<String, dynamic> ||
          value['settings'] is! Map ||
          value['events'] is! List ||
          value['courses'] is! List) {
        throw const FormatException(
          'AI 需要返回完整课表 JSON（含 settings、courses、events）',
        );
      }
      final result = clone(value)..['id'] = baseline['id'];
      final settings = result['settings'] as Map;
      final start = DateTime.tryParse(settings['startDate']?.toString() ?? '');
      if (start == null ||
          settings['totalWeeks'] is! int ||
          settings['maxPeriods'] is! int ||
          settings['classTimes'] is! List ||
          settings['holidays'] is! List ||
          !settings.keys.toSet().containsAll(
            (baseline['settings'] as Map).keys,
          )) {
        throw const FormatException('AI 返回的学期、作息或休假设置不完整');
      }
      for (final time in settings['classTimes']) {
        if (time is! Map ||
            time['period'] is! int ||
            !_clock(time['startTime']) ||
            !_clock(time['endTime'])) {
          throw const FormatException('AI 返回的作息时间无效');
        }
      }
      for (final holiday in settings['holidays']) {
        if (holiday is! String || DateTime.tryParse(holiday) == null) {
          throw const FormatException('AI 返回的休假日期无效');
        }
      }
      validate(result);
      return result;
    }
    final actions = plan['actions'];
    if (actions is! List || actions.isEmpty || actions.length > 100) {
      throw const FormatException('方案需要 1–100 项操作');
    }
    final result = clone(baseline);
    final settings = result['settings'] as Map;
    final courses = result['courses'] as List;
    final maxWeeks = settings['totalWeeks'] as int;
    final maxPeriods = settings['maxPeriods'] as int;
    final holidays = List<String>.from(settings['holidays'] ?? []);
    final touched = <String>{};
    final events = result.putIfAbsent('events', () => <dynamic>[]) as List;
    for (final dynamic raw in actions) {
      if (raw is! Map) throw const FormatException('操作格式错误');
      final a = Map<String, dynamic>.from(raw);
      final type = a['type'];
      if (type == 'event') {
        if (a['event'] is! Map) throw const FormatException('事件格式错误');
        events.add(clone(Map<String, dynamic>.from(a['event'])));
        continue;
      }
      if (type == 'removeEvent') {
        final matches = events.where((e) => e['id'] == a['eventId']).toList();
        if (matches.length != 1) throw const FormatException('事件不存在');
        events.remove(matches.single);
        continue;
      }
      if (type == 'rest' || type == 'resume') {
        final date = DateTime.tryParse(a['date']?.toString() ?? '');
        if (date == null || a['date'] != _day(date)) {
          throw const FormatException('日期必须为 yyyy-MM-dd');
        }
        final offset = date.difference(monday(settings)).inDays;
        if (offset < 0 || offset >= maxWeeks * 7) {
          throw const FormatException('日期不在本学期内');
        }
        holidays.removeWhere((h) => h.startsWith(a['date'] as String));
        if (type == 'rest') holidays.add(date.toIso8601String());
        continue;
      }
      if (type == 'add') {
        final course = a['course'];
        if (course is! Map ||
            (course['schedules'] as List?)?.isEmpty != false) {
          throw const FormatException('新增事件必须指定节次和周次');
        }
        courses.add(clone(Map<String, dynamic>.from(course)));
        continue;
      }
      if (type != 'move' && type != 'cancel' && type != 'copy') {
        throw const FormatException('未知操作');
      }
      final ci = a['courseIndex'];
      final si = a['scheduleIndex'];
      if (ci is! int ||
          ci < 0 ||
          ci >= (baseline['courses'] as List).length ||
          si is! int ||
          si < 0 ||
          si >= (baseline['courses'][ci]['schedules'] as List).length) {
        throw const FormatException('课程或时间段已不存在');
      }
      final course = courses[ci] as Map;
      final source = course['schedules'][si] as Map;
      final weeks = integers(a['weeks'], 1, maxWeeks);
      for (final week in weeks) {
        if (!(source['weekPattern'] as List).contains(week) ||
            !touched.add('$ci/$si/$week')) {
          throw const FormatException('同一课程周次被重复操作或不存在');
        }
      }
      if (type != 'cancel') {
        final targetWeeks = integers(a['targetWeeks'], 1, maxWeeks);
        final targetPeriods = integers(a['targetPeriods'], 1, maxPeriods);
        final weekday = a['targetWeekday'];
        if (weekday is! int ||
            weekday < 1 ||
            weekday > 7 ||
            targetWeeks.length != weeks.length ||
            targetPeriods.length != (source['periods'] as List).length) {
          throw const FormatException('调课应保留课次与节数，并指定有效星期');
        }
        final moved = clone(Map<String, dynamic>.from(course));
        moved['schedules'] = [
          {
            'weekday': weekday,
            'periods': targetPeriods,
            'weekPattern': targetWeeks,
          },
        ];
        if (a['location'] is String) moved['location'] = a['location'];
        courses.add(moved);
      }
      if (type != 'copy') {
        source['weekPattern'] = (source['weekPattern'] as List)
            .where((w) => !weeks.contains(w))
            .toList();
      }
    }
    for (final c in courses) {
      (c['schedules'] as List).removeWhere(
        (s) => (s['weekPattern'] as List).isEmpty,
      );
    }
    settings['holidays'] = holidays;
    validate(result);
    for (final c in courses.skip((baseline['courses'] as List).length)) {
      for (final s in c['schedules']) {
        for (final w in s['weekPattern']) {
          final date = monday(settings).add(
            Duration(days: ((w as int) - 1) * 7 + (s['weekday'] as int) - 1),
          );
          if (holidays.any((h) => h.startsWith(_day(date)))) {
            throw const FormatException('目标日期是休假日，请明确恢复上课或另选时间');
          }
        }
      }
    }
    // Existing conflicts may be repaired in stages; only new collisions block.
    final oldConflicts = conflicts(baseline).toSet();
    final introduced = conflicts(
      result,
    ).where((c) => !oldConflicts.contains(c));
    if (introduced.isNotEmpty) {
      throw FormatException('方案产生冲突：${introduced.take(8).join('；')}');
    }
    return result;
  }

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static bool _clock(dynamic value) =>
      value is String && RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(value);

  /// Explicit dates remove the need for the model to guess the semester week.
  static List<Map<String, dynamic>> calendar(Map<String, dynamic> data) {
    final settings = data['settings'] as Map;
    final first = monday(settings);
    final holidays = (settings['holidays'] as List? ?? [])
        .map((d) => d.toString().substring(0, 10))
        .toSet();
    return [
      for (
        var offset = 0;
        offset < (settings['totalWeeks'] as int) * 7;
        offset++
      )
        {
          'date': _day(DateTime(first.year, first.month, first.day + offset)),
          'week': offset ~/ 7 + 1,
          'weekday': offset % 7 + 1,
          'rest': holidays.contains(
            _day(DateTime(first.year, first.month, first.day + offset)),
          ),
          'classes': [
            for (var ci = 0; ci < (data['courses'] as List).length; ci++)
              for (
                var si = 0;
                si < (data['courses'][ci]['schedules'] as List).length;
                si++
              )
                if (data['courses'][ci]['schedules'][si]['weekday'] ==
                        offset % 7 + 1 &&
                    (data['courses'][ci]['schedules'][si]['weekPattern']
                            as List)
                        .contains(offset ~/ 7 + 1))
                  {
                    'courseIndex': ci,
                    'scheduleIndex': si,
                    'name': data['courses'][ci]['name'],
                    'periods': data['courses'][ci]['schedules'][si]['periods'],
                  },
          ],
        },
    ];
  }

  static List<String> conflicts(Map<String, dynamic> data) {
    final settings = data['settings'] as Map;
    final holidays = (settings['holidays'] as List? ?? [])
        .map((d) => d.toString().substring(0, 10))
        .toSet();
    final occupied = <String, List<String>>{};
    for (final c in data['courses']) {
      for (final s in c['schedules']) {
        for (final w in s['weekPattern']) {
          final date = monday(settings).add(
            Duration(days: ((w as int) - 1) * 7 + (s['weekday'] as int) - 1),
          );
          if (holidays.contains(_day(date))) continue;
          for (final p in s['periods']) {
            final key = '第$w周 星期${s['weekday']} 第$p节';
            occupied.putIfAbsent(key, () => []).add(c['name'] as String);
          }
        }
      }
    }
    final found = occupied.entries
        .where((e) => e.value.length > 1)
        .map((e) => '${e.key}：${(e.value..sort()).join(' / ')}')
        .toList();
    if ((data['events'] as List? ?? []).isEmpty) return found;
    final intervals =
        <({String name, DateTime start, DateTime end, bool event})>[];
    for (final e in data['events'] as List? ?? []) {
      intervals.add((
        name: e['name'],
        start: eventTime(e['start']),
        end: eventTime(e['end']),
        event: true,
      ));
    }
    final eventCount = intervals.length;
    for (final c in data['courses']) {
      for (final s in c['schedules']) {
        for (final w in s['weekPattern']) {
          final date = monday(settings).add(
            Duration(days: ((w as int) - 1) * 7 + (s['weekday'] as int) - 1),
          );
          if (holidays.contains(_day(date))) continue;
          for (final p in s['periods']) {
            final time = (settings['classTimes'] as List? ?? [])
                .where((t) => t['period'] == p)
                .firstOrNull;
            if (time == null) continue;
            intervals.add((
              name: c['name'],
              start: DateTime.parse('${_day(date)}T${time['startTime']}:00'),
              end: DateTime.parse('${_day(date)}T${time['endTime']}:00'),
              event: false,
            ));
          }
        }
      }
    }
    for (var i = 0; i < eventCount; i++) {
      for (var j = i + 1; j < intervals.length; j++) {
        final a = intervals[i], b = intervals[j];
        if ((a.event || b.event) &&
            a.start.isBefore(b.end) &&
            b.start.isBefore(a.end)) {
          final names = [a.name, b.name]..sort();
          final start = a.start.isAfter(b.start) ? a.start : b.start;
          found.add(
            '${_day(start)} ${start.hour}:${start.minute.toString().padLeft(2, '0')}：${names.join(' / ')}',
          );
        }
      }
    }
    return found.toSet().toList();
  }
}
