import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../states/timetable_state.dart';
import '../../data/class_time.dart';
import '../../services/timetable/bell_schedule.dart';
import '../../components/inputs/timepicker.dart';
import '../../components/inputs/datepicker.dart';
import '../../components/feedback/notifications.dart';
import '../../components/layout/appbar.dart';
import '../../components/layout/settingscard.dart';
import '../../components/inputs/components.dart';

class TimeSettingsPage extends StatefulWidget {
  const TimeSettingsPage({super.key});
  @override
  State<TimeSettingsPage> createState() => _TimeSettingsPageState();
}

class _TimeSettingsPageState extends State<TimeSettingsPage> {
  List<ClassTime> _times = [];
  DateTime _start = DateTime.now();
  final _duration = TextEditingController(text: '45');
  final _short = TextEditingController(text: '10');
  final _long = TextEditingController(text: '20');
  int _morning = 510, _afternoon = 870, _evening = 1140;
  int _maxPeriods = 10, _morningCount = 4, _afternoonCount = 4;
  int get _nightCount => _maxPeriods - _morningCount - _afternoonCount;
  @override
  void initState() {
    super.initState();
    final t = context.read<TimetableState>().current;
    if (t != null) {
      _start = t.settings.startDate;
      _duration.text = t.settings.lessonMinutes.toString();
      _short.text = t.settings.shortBreakMinutes.toString();
      _long.text = t.settings.longBreakMinutes.toString();
      _times = t.settings.classTimes
          .map((v) => ClassTime()
            ..period = v.period
            ..startTime = v.startTime
            ..endTime = v.endTime)
          .toList();
      // Keep saved custom times until the user explicitly regenerates a schedule.
      _maxPeriods = t.settings.maxPeriods;
      _morningCount = t.settings.morningPeriods.clamp(0,_maxPeriods);
      _afternoonCount = t.settings.afternoonPeriods.clamp(0,_maxPeriods-_morningCount);
      for (final time in _times) {
        if (time.period == 1) _morning = BellSchedule.minutes(time.startTime);
        if (time.period == _morningCount + 1)
          _afternoon = BellSchedule.minutes(time.startTime);
        if (time.period == _morningCount + _afternoonCount + 1)
          _evening = BellSchedule.minutes(time.startTime);
      }
    }
  }

  @override
  void dispose() {
    _duration.dispose();
    _short.dispose();
    _long.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      if (_times.length != _maxPeriods) throw const FormatException('请先重新生成作息');
      for (var i = 0; i < _times.length; i++) {
        final a = BellSchedule.minutes(_times[i].startTime),
            b = BellSchedule.minutes(_times[i].endTime);
        if (a >= b ||
            (i > 0 && a < BellSchedule.minutes(_times[i - 1].endTime)))
          throw const FormatException('时间不能重叠');
      }
      final state = context.read<TimetableState>();
      final t = state.current!;
      final used =
          t.courses.expand((c) => c.schedules).expand((s) => s.periods);
      if (used.any((p) => p > _times.length))
        throw const FormatException('已有课程使用晚间节次，请先调整课程再减少晚课');
      t.settings.lessonMinutes = int.parse(_duration.text);
      t.settings.shortBreakMinutes = int.parse(_short.text);
      t.settings.longBreakMinutes = int.parse(_long.text);
      t.settings.classTimes = _times;
      t.settings.maxPeriods = _times.length;
      t.settings.morningPeriods = _morningCount;
      t.settings.afternoonPeriods = _afternoonCount;
      t.settings.startDate = DateTime(_start.year, _start.month, _start.day)
          .subtract(Duration(days: _start.weekday - 1));
      if (!await state.put(t)) throw StateError('保存失败');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) Notifications.sonner(context, message: '$e');
    }
  }

  Future<void> _pickBlock(int current, ValueChanged<int> set) async {
    final value = await YicoreTimeRangePicker.show(
        context: context,
        initial: TimeRange(
            startHour: current ~/ 60,
            startMinute: current % 60,
            endHour: (current + 45) ~/ 60,
            endMinute: (current + 45) % 60));
    if (value != null && mounted)
      setState(() => set(BellSchedule.minutes(value.formatStart())));
  }

  Future<void> _pickLesson(ClassTime time) async {
    final a = BellSchedule.minutes(time.startTime),
        b = BellSchedule.minutes(time.endTime);
    final value = await YicoreTimeRangePicker.show(
        context: context,
        initial: TimeRange(
            startHour: a ~/ 60,
            startMinute: a % 60,
            endHour: b ~/ 60,
            endMinute: b % 60));
    if (value != null && mounted)
      setState(() {
        time.startTime = value.formatStart();
        time.endTime = value.formatEnd();
      });
  }

  void _generate() {
    try {
      final values = BellSchedule.generate(
          duration: int.parse(_duration.text),
          shortBreak: int.parse(_short.text),
          longBreak: int.parse(_long.text),
          morning: _morning,
          afternoon: _afternoon,
          evening: _evening,
          eveningPeriods: _nightCount,
          morningPeriods: _morningCount,
          afternoonPeriods: _afternoonCount);
      setState(() => _times = values);
    } catch (e) {
      Notifications.sonner(context, message: '请检查时长和开课时间：$e');
    }
  }

  Widget _countItem(String label, int value, ValueChanged<int> change) =>
      SettingsItem(
          title: label,
          inBlock: true,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
                icon: const Icon(Icons.remove),
                onPressed:
                    value > 0 ? () => setState(() => change(value - 1)) : null),
            Text('$value 节'),
            IconButton(
                icon: const Icon(Icons.add),
                onPressed: value < _maxPeriods
                    ? () => setState(() => change(value + 1))
                    : null)
          ]));
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        appBar: YicoreAppBar(title: '课程时间设置', centerTitle: true, actions: [
          YicoreIconButton(
              icon: Icons.save, onPressed: _save, showBorder: false)
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          SettingsBlock(title: '学期', children: [
            SettingsItem.value(
                title: '第 1 周周一',
                value: _start.toIso8601String().substring(0, 10),
                inBlock: true,
                onTap: () async {
                  final day = await YicoreDatePicker.show(
                      context: context,
                      initialDate: _start,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100));
                  if (day != null && mounted)
                    setState(() =>
                        _start = day.subtract(Duration(days: day.weekday - 1)));
                })
          ]),
          const SizedBox(height: 16),
          SettingsBlock(title: '每日节数', children: [
            SettingsItem.slider(
                title: '每日总节数',
                description: '共 $_maxPeriods 节',
                value: _maxPeriods.toDouble(),
                min: 1,
                max: 16,
                inBlock: true,
                onChanged: (v) => setState(() {
                      _maxPeriods = v.round();
                      _morningCount = _morningCount.clamp(0, _maxPeriods);
                      _afternoonCount =
                          _afternoonCount.clamp(0, _maxPeriods - _morningCount);
                    })),
            _countItem('上午', _morningCount, (v) {
              _morningCount = v;
              _afternoonCount = _afternoonCount.clamp(0, _maxPeriods - v);
            }),
            _countItem('下午', _afternoonCount, (v) {
              _afternoonCount = v;
              _morningCount = _morningCount.clamp(0, _maxPeriods - v);
            }),
            SettingsItem.value(
                title: '晚上',
                value: '$_nightCount 节',
                inBlock: true,
                showArrow: false),
          ]),
          const SizedBox(height: 16),
          SettingsBlock(title: '作息生成', children: [
            SettingsItem.value(
                title: '上午开课',
                value: BellSchedule.clock(_morning),
                inBlock: true,
                onTap: () => _pickBlock(_morning, (v) => _morning = v)),
            SettingsItem.value(
                title: '下午开课',
                value: BellSchedule.clock(_afternoon),
                inBlock: true,
                onTap: () => _pickBlock(_afternoon, (v) => _afternoon = v)),
            SettingsItem.value(
                title: '晚上开课',
                value: BellSchedule.clock(_evening),
                inBlock: true,
                onTap: () => _pickBlock(_evening, (v) => _evening = v)),
            Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  YicoreTextField(
                      labelText: '每节课（分钟）',
                      controller: _duration,
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  YicoreTextField(
                      labelText: '短休（分钟）',
                      controller: _short,
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  YicoreTextField(
                      labelText: '每两节后大课间（分钟）',
                      controller: _long,
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  YicoreButton(text: '重新生成作息', onPressed: _generate),
                ])),
          ]),
          const SizedBox(height: 16),
          for (final block in [
            ('上午', 1, _morningCount),
            ('下午', _morningCount + 1, _morningCount + _afternoonCount),
            ('晚上', _morningCount + _afternoonCount + 1, _maxPeriods)
          ]) ...[
            if (_times.any((t) => t.period >= block.$2 && t.period <= block.$3))
              SettingsBlock(title: block.$1, children: [
                for (final time in _times
                    .where((t) => t.period >= block.$2 && t.period <= block.$3))
                  SettingsItem.value(
                      title: '第 ${time.period} 节',
                      value: '${time.startTime}–${time.endTime}',
                      inBlock: true,
                      onTap: () => _pickLesson(time)),
              ]),
            const SizedBox(height: 16),
          ],
        ]),
      );
}
