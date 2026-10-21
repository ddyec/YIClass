import 'package:flutter/material.dart';
import '../../data/timetable.dart';
import '../../data/course_schedule.dart';
import '../../data/class_time.dart';
import '../../services/ai/planning_engine.dart';
import '../../services/file_service.dart';
import '../../services/timetable/bell_schedule.dart';
import '../../components/layout/appbar.dart';
import '../../components/layout/cards.dart';
import '../../components/layout/settingscard.dart';
import '../../components/inputs/components.dart';
import '../../components/inputs/timepicker.dart';
import '../../components/inputs/datepicker.dart';
import '../../components/feedback/notifications.dart';

Future<Timetable?> reviewImport(BuildContext context, Timetable timetable) =>
    Navigator.push<Timetable>(
        context,
        MaterialPageRoute(
            builder: (_) => ImportReviewPage(timetable: timetable)));

class ImportReviewPage extends StatefulWidget {
  final Timetable timetable;
  const ImportReviewPage({super.key, required this.timetable});
  @override
  State<ImportReviewPage> createState() => _ImportReviewPageState();
}

class _ImportReviewPageState extends State<ImportReviewPage> {
  late final Timetable _timetable = widget.timetable;
  bool _confirmed = false;
  static const days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  Future<void> _pickTime(ClassTime time) async {
    final a = BellSchedule.minutes(time.startTime),
        b = BellSchedule.minutes(time.endTime);
    final result = await YicoreTimeRangePicker.show(
        context: context,
        initial: TimeRange(
            startHour: a ~/ 60,
            startMinute: a % 60,
            endHour: b ~/ 60,
            endMinute: b % 60));
    if (result != null && mounted) {
      setState(() {
        time.startTime = result.formatStart();
        time.endTime = result.formatEnd();
        _confirmed = false;
      });
    }
  }

  Future<void> _editSchedule(CourseSchedule schedule) async {
    var weekday = schedule.weekday;
    final periods = TextEditingController(text: schedule.periods.join(','));
    final weeks = TextEditingController(text: schedule.weekPattern.join(','));
    final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => AlertDialog(
                  title: const Text('调整上课安排'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    DropdownButton<int>(
                        value: weekday,
                        isExpanded: true,
                        items: [
                          for (var d = 1; d <= 7; d++)
                            DropdownMenuItem(value: d, child: Text(days[d - 1]))
                        ],
                        onChanged: (v) => update(() => weekday = v!)),
                    YicoreTextField(
                        labelText: '节次 · 逗号分隔', controller: periods),
                    const SizedBox(height: 12),
                    YicoreTextField(labelText: '周次 · 逗号分隔', controller: weeks),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消')),
                    YicoreButton(
                        text: '保存', onPressed: () => Navigator.pop(ctx, true))
                  ],
                )));
    if (result == true && mounted) {
      try {
        List<int> parse(String text, int max) => PlanningEngine.integers(
            text
                .replaceAll('，', ',')
                .split(',')
                .map((v) => int.parse(v.trim()))
                .toList(),
            1,
            max);
        final p = parse(periods.text, _timetable.settings.maxPeriods),
            w = parse(weeks.text, _timetable.settings.totalWeeks);
        setState(() {
          schedule.weekday = weekday;
          schedule.periods = p;
          schedule.weekPattern = w;
          _confirmed = false;
        });
      } catch (_) {
        Notifications.sonner(context, message: '请输入有效节次与周次');
      }
    }
    periods.dispose();
    weeks.dispose();
  }

  void _save() {
    final times = _timetable.settings.classTimes;
    for (var i = 0; i < times.length; i++) {
      final start = BellSchedule.minutes(times[i].startTime),
          end = BellSchedule.minutes(times[i].endTime);
      if (start >= end ||
          (i > 0 && start < BellSchedule.minutes(times[i - 1].endTime))) {
        Notifications.sonner(context, message: '请检查节次时间重叠');
        return;
      }
    }
    _timetable.id = 0;
    Navigator.pop(context, _timetable);
  }

  @override
  Widget build(BuildContext context) {
    final settings = _timetable.settings;
    final conflicts = PlanningEngine.conflicts(FileService.toMap(_timetable));
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: const YicoreAppBar(title: '确认导入', centerTitle: true),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SettingsBlock(title: _timetable.name, children: [
          SettingsItem.value(
              title: '第 1 周周一',
              value: settings.startDate.toIso8601String().substring(0, 10),
              inBlock: true,
              onTap: () async {
                final day = await YicoreDatePicker.show(
                    context: context,
                    initialDate: settings.startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100));
                if (day != null && mounted) {
                  setState(() {
                    settings.startDate =
                        day.subtract(Duration(days: day.weekday - 1));
                    _confirmed = false;
                  });
                }
              }),
          ExpansionTile(
              title: const Text('课程时间'),
              subtitle: Text(
                  '上午 ${settings.morningPeriods} 节 · 下午 ${settings.afternoonPeriods} 节 · 晚上 ${settings.maxPeriods - settings.morningPeriods - settings.afternoonPeriods} 节'),
              children: [
                for (final t in settings.classTimes)
                  SettingsItem.value(
                      title: '第 ${t.period} 节',
                      value: '${t.startTime}–${t.endTime}',
                      inBlock: true,
                      onTap: () => _pickTime(t)),
              ]),
        ]),
        const SizedBox(height: 16),
        for (var day = 1; day <= 7; day++) ...[
          if (_timetable.courses
              .any((c) => c.schedules.any((s) => s.weekday == day)))
            SettingsBlock(title: days[day - 1], children: [
              for (final c in _timetable.courses)
                for (final s in c.schedules.where((s) => s.weekday == day))
                  SettingsItem(
                      title: c.name,
                      description:
                          '第 ${s.periods.join('、')} 节 · 第 ${s.weekPattern.join('、')} 周\n${c.location}',
                      showArrow: true,
                      inBlock: true,
                      onTap: () => _editSchedule(s)),
            ]),
          const SizedBox(height: 12),
        ],
        if (_timetable.courses.any((c) => c.schedules.isEmpty))
          YicoreCard(
              child: ExpansionTile(title: const Text('待安排课程'), children: [
            for (final c
                in _timetable.courses.where((c) => c.schedules.isEmpty))
              ListTile(title: Text(c.name), subtitle: Text(c.location))
          ])),
        if (conflicts.isNotEmpty)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('请先修正时间冲突：\n${conflicts.take(8).join('\n')}',
                  style: const TextStyle(color: Colors.red))),
        CheckboxListTile(
            activeColor: Colors.black,
            contentPadding: EdgeInsets.zero,
            value: _confirmed,
            title: const Text('已核对星期、周次和作息'),
            onChanged: (v) => setState(() => _confirmed = v ?? false)),
        YicoreButton(
            text: '导入为新课表',
            onPressed: _confirmed && conflicts.isEmpty ? _save : null),
        const SizedBox(height: 24),
      ]),
    );
  }
}
