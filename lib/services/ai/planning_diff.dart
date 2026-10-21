import 'dart:convert';
import 'planning_engine.dart';

/// Compare the validated result, rather than trusting the model's summary.
class PlanningDiff {
  static List<({String title, String before, String after})> between(
    Map<String, dynamic> before,
    Map<String, dynamic> after,
  ) {
    final changes = <({String title, String before, String after})>[];
    final oldRows = _courses(before), newRows = _courses(after);
    for (final name in {...oldRows.keys, ...newRows.keys}) {
      final removed = List<String>.from(oldRows[name] ?? []);
      final added = List<String>.from(newRows[name] ?? []);
      for (final row in List<String>.from(removed)) {
        if (added.contains(row)) {
          removed.remove(row);
          added.remove(row);
        }
      }
      if (removed.isNotEmpty || added.isNotEmpty) {
        changes.add((
          title: name,
          before: removed.join('\n'),
          after: added.join('\n'),
        ));
      }
    }
    final oldEvents = {
      for (final e in before['events'] as List? ?? []) e['id']: e,
    };
    final newEvents = {
      for (final e in after['events'] as List? ?? []) e['id']: e,
    };
    for (final id in {...oldEvents.keys, ...newEvents.keys}) {
      if (jsonEncode(oldEvents[id]) != jsonEncode(newEvents[id])) {
        changes.add((
          title: '活动：${newEvents[id]?['name'] ?? oldEvents[id]['name']}',
          before: _event(oldEvents[id]),
          after: _event(newEvents[id]),
        ));
      }
    }
    if (before['name'] != after['name']) {
      changes.add((
        title: '课表名称',
        before: '${before['name']}',
        after: '${after['name']}',
      ));
    }
    const labels = {
      'startDate': '开学日期',
      'totalWeeks': '学期周数',
      'maxPeriods': '每日节数',
      'classTimes': '作息时间',
      'holidays': '休假日期',
      'showWeekend': '显示周末',
      'morningPeriods': '上午节数',
      'afternoonPeriods': '下午节数',
      'lessonMinutes': '每节时长',
      'shortBreakMinutes': '短课间',
      'longBreakMinutes': '长课间',
      'reminderMinutes': '提前提醒分钟',
    };
    final oldSettings = before['settings'] as Map,
        newSettings = after['settings'] as Map;
    for (final key in {...oldSettings.keys, ...newSettings.keys}) {
      if (jsonEncode(oldSettings[key]) != jsonEncode(newSettings[key])) {
        changes.add((
          title: labels[key] ?? '课表设置：$key',
          before: _setting(key.toString(), oldSettings[key]),
          after: _setting(key.toString(), newSettings[key]),
        ));
      }
    }
    return changes;
  }

  static Map<String, List<String>> _courses(Map<String, dynamic> data) {
    final rows = <String, List<String>>{};
    final first = PlanningEngine.monday(data['settings'] as Map);
    for (final course in data['courses']) {
      final details = [
        course['location'],
        course['teacher'],
      ].where((v) => v is String && v.isNotEmpty).join(' · ');
      final values = rows.putIfAbsent(course['name'] as String, () => []);
      if ((course['schedules'] as List).isEmpty) values.add('未排课 · $details');
      for (final schedule in course['schedules']) {
        for (final week in schedule['weekPattern']) {
          final date = DateTime(
            first.year,
            first.month,
            first.day +
                ((week as int) - 1) * 7 +
                (schedule['weekday'] as int) -
                1,
          );
          values.add(
            '${date.toIso8601String().substring(0, 10)} 第$week周 '
            '周${'一二三四五六日'[schedule['weekday'] - 1]} '
            '第${(schedule['periods'] as List).join('、')}节 · $details',
          );
        }
      }
    }
    return rows;
  }

  static String _event(dynamic e) => e == null
      ? ''
      : '${e['start'].toString().replaceFirst('T', ' ')} → '
            '${e['end'].toString().replaceFirst('T', ' ')}'
            '${e['location'] == null || e['location'] == '' ? '' : ' · ${e['location']}'}';

  static String _setting(String key, dynamic value) {
    if (value == null) return '未设置';
    if (key == 'classTimes' && value is List) {
      return value
          .map((t) => '第${t['period']}节 ${t['startTime']}–${t['endTime']}')
          .join('\n');
    }
    if (key == 'holidays' && value is List) {
      return value.isEmpty
          ? '无'
          : value.map((d) => d.toString().substring(0, 10)).join('、');
    }
    return value.toString();
  }
}
