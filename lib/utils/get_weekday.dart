Map<String, int>? getWeekInfo(
    DateTime date, DateTime startMonday, int totalWeeks) {
  final day = DateTime(date.year, date.month, date.day);
  final start = DateTime(startMonday.year, startMonday.month, startMonday.day)
      .subtract(Duration(days: startMonday.weekday - 1));
  final deltaDays = day.difference(start).inDays;

  // 越界检查
  if (deltaDays < 0) return null; // 学期未开始
  if (deltaDays >= totalWeeks * 7) return null; // 学期已结束

  final weekIndex = (deltaDays ~/ 7) + 1; // 第几周，从1开始
  final weekday = date.weekday; // 1=周一, 7=周日

  return {
    'weekIndex': weekIndex,
    'weekday': weekday,
  };
}
