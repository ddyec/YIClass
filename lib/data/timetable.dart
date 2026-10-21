import 'package:isar_plus/isar_plus.dart';
import 'timetable_settings.dart';
import 'course.dart';
import 'class_time.dart';
import 'course_schedule.dart';
import 'dart:convert';

part 'timetable.g.dart';

/// 课表模型，支持嵌套课程和设置
@collection
class Timetable {
  /// 课表唯一ID（自增）
  late int id;

  /// 课表名称
  late String name;

  /// 课表设置（嵌入式）
  late TimetableSettings settings;

  /// 课程列表（嵌入式）
  late List<Course> courses;

  /// Independent date/time events; old databases default to an empty list.
  String eventsJson;

  @ignore
  List<Map<String, dynamic>> get events => (jsonDecode(eventsJson) as List)
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
  set events(List<Map<String, dynamic>> value) =>
      eventsJson = jsonEncode(value);

  Timetable({this.eventsJson = '[]'});
}
