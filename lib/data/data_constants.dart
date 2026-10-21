/// 数据模型默认常量
///
/// 包含课表等数据模型相关的默认配置
class DataConstants {
  // 课表默认配置
  static const String defaultTimetableName = '默认课表';
  static const int defaultTotalWeeks = 20;
  static const int defaultMaxPeriods = 10;

  // 课表范围配置
  static const int minTotalWeeks = 1;
  static const int maxTotalWeeks = 20;
  static const int minMaxPeriods = 1;
  static const int maxMaxPeriods = 16;

  // 视图和显示默认配置
  static const int defaultCurrentWeek = 1;
  static const String defaultSelectedView = '周视图';
  static const bool defaultShowWeekend = true;

  // 默认节次时间配置
  static const Map<String, String> defaultPeriodTimes = {
    '1': '08:30-09:15',
    '2': '09:25-10:10',
    '3': '10:30-11:15',
    '4': '11:25-12:10',
    '5': '14:30-15:15',
    '6': '15:25-16:10',
    '7': '16:30-17:15',
    '8': '17:25-18:10',
    '9': '19:00-19:45',
    '10': '19:55-20:40',
    '11': '18:30-19:15',
    '12': '19:20-20:05',
    '13': '20:10-20:55',
    '14': '21:00-21:45',
    '15': '21:50-22:35',
    '16': '22:40-23:25'
  };
}
