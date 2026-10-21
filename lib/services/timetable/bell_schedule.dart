import '../../data/class_time.dart';

class BellSchedule {
  static String clock(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  static int minutes(String value) {
    final p = value.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  static List<ClassTime> generate(
      {int duration = 45,
      int shortBreak = 10,
      int longBreak = 20,
      int morning = 510,
      int afternoon = 870,
      int evening = 1140,
      int eveningPeriods = 2,
      int morningPeriods = 4,
      int afternoonPeriods = 4}) {
    if (duration < 1 ||
        shortBreak < 0 ||
        longBreak < 0 ||
        eveningPeriods < 0 ||
        eveningPeriods > 16) {
      throw const FormatException('请检查课时与休息时长');
    }
    if (morningPeriods < 0 ||
        afternoonPeriods < 0 ||
        morningPeriods + afternoonPeriods + eveningPeriods < 1 ||
        morningPeriods + afternoonPeriods + eveningPeriods > 16)
      throw const FormatException('总节数应为 1–16');
    final result = <ClassTime>[];
    for (final block in [
      (morning, morningPeriods),
      (afternoon, afternoonPeriods),
      (evening, eveningPeriods)
    ]) {
      var start = block.$1;
      for (var i = 0; i < block.$2; i++) {
        final end = start + duration;
        if (end > 1440 ||
            (result.isNotEmpty && start < minutes(result.last.endTime))) {
          throw const FormatException('时段重叠或超出当天，请调整开课时间');
        }
        result.add(ClassTime()
          ..period = result.length + 1
          ..startTime = clock(start)
          ..endTime = clock(end));
        start = end + (i.isOdd ? longBreak : shortBreak);
      }
    }
    return result;
  }
}
