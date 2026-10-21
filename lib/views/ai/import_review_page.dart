import 'package:flutter/material.dart';
import '../../data/timetable.dart';
import '../../data/class_time.dart';
import '../../services/ai/planning_engine.dart';
import '../../services/file_service.dart';

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

  Future<void> _pickTime(ClassTime time, bool start) async {
    final parts = (start ? time.startTime : time.endTime).split(':');
    final selected = await showTimePicker(
        context: context,
        initialTime:
            TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!));
    if (selected == null || !mounted) return;
    String format(int minutes) =>
        '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
    setState(() {
      if (start) {
        time.startTime = format(selected.hour * 60 + selected.minute);
        time.endTime =
            format((selected.hour * 60 + selected.minute + 45) % 1440);
      } else {
        time.endTime = format(selected.hour * 60 + selected.minute);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _timetable.settings;
    final conflicts = PlanningEngine.conflicts(FileService.toMap(_timetable));
    return Scaffold(
      appBar: AppBar(title: const Text('确认导入')),
      body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
        Text(_timetable.name, style: Theme.of(context).textTheme.titleLarge),
        ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('第 1 周周一'),
            subtitle: Text(s.startDate.toIso8601String().substring(0, 10)),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final date = await showDatePicker(
                  context: context,
                  initialDate: s.startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100));
              if (date != null && mounted) {
                setState(() {
                  s.startDate = date.subtract(Duration(days: date.weekday - 1));
                  _confirmed = false;
                });
              }
            }),
        const Text('点按时间可调整；修改开始时间后，默认按 45 分钟计算结束时间。'),
        for (final time in s.classTimes)
          Row(children: [
            SizedBox(width: 70, child: Text('第 ${time.period} 节')),
            TextButton(
                onPressed: () => _pickTime(time, true),
                child: Text(time.startTime)),
            const Text('—'),
            TextButton(
                onPressed: () => _pickTime(time, false),
                child: Text(time.endTime)),
          ]),
        const Divider(),
        Text('${_timetable.courses.length} 门课程 / 事件'),
        for (final c in _timetable.courses)
          ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.name),
              subtitle: Text(
                  '${c.location} ${c.teacher}\n${c.schedules.isEmpty ? '未指定节次，请后续安排' : c.schedules.map((s) => '星期${s.weekday} ${s.periods.join(',')}节 · 第${s.weekPattern.join(',')}周').join('\n')}')),
        if (conflicts.isNotEmpty)
          Text('原课表存在冲突：\n${conflicts.take(8).join('\n')}'),
        CheckboxListTile(
            value: _confirmed,
            contentPadding: EdgeInsets.zero,
            title: const Text('已核对第 1 周周一、作息及课程周次'),
            onChanged: (value) => setState(() => _confirmed = value ?? false)),
        FilledButton(
            onPressed: !_confirmed
                ? null
                : () {
                    var lastEnd = -1;
                    for (final time in s.classTimes) {
                      int minutes(String v) {
                        final p = v.split(':');
                        return int.parse(p[0]) * 60 + int.parse(p[1]);
                      }

                      final start = minutes(time.startTime),
                          end = minutes(time.endTime);
                      if (start >= end || start < lastEnd) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('节次时间需按顺序排列，且开始早于结束')));
                        return;
                      }
                      lastEnd = end;
                    }
                    _timetable.id =
                        0; // Imported IDs must never overwrite another timetable.
                    Navigator.pop(context, _timetable);
                  },
            child: const Text('导入为新课表')),
      ])),
    );
  }
}
