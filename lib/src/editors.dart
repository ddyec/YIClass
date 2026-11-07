import 'package:flutter/material.dart';
import 'model.dart';
import 'store.dart';

const palette = [
  0xff637eea,
  0xff298f84,
  0xffb77938,
  0xffae65a3,
  0xffd36d71,
  0xff658aab,
];
void message(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(e.toString().replaceFirst('FormatException: ', ''))),
  );
}

Future<void> attempt(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) message(context, e);
  }
}

Future<bool> confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('确认'),
          ),
        ],
      ),
    ) ??
    false;
Future<String?> ask(
  BuildContext context,
  String title, {
  String initial = '',
  String hint = '',
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
        FilledButton(
          onPressed: () => Navigator.pop(c, controller.text.trim()),
          child: const Text('保存'),
        ),
      ],
    ),
  );
  // Dispose after the dialog transition has released its TextField.
  Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
  return result;
}

Future<DateTime?> pickDate(BuildContext context, DateTime initial) =>
    showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
Future<DateTime?> pickDateTime(BuildContext context, DateTime initial) async {
  final d = await pickDate(context, initial);
  if (d == null || !context.mounted) return null;
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (t == null) return null;
  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}

class CourseEditor extends StatefulWidget {
  const CourseEditor({super.key, required this.store, this.course});
  final Store store;
  final J? course;
  @override
  State<CourseEditor> createState() => _CourseEditorState();
}

class _CourseEditorState extends State<CourseEditor> {
  late final name = TextEditingController(text: widget.course?['name'] ?? ''),
      place = TextEditingController(text: widget.course?['location'] ?? ''),
      teacher = TextEditingController(text: widget.course?['teacher'] ?? '');
  late int color = widget.course?['color'] ?? palette.first;
  late List<J> schedules = objects(widget.course?['schedules'] ?? []);
  late bool unscheduled = schedules.isEmpty;
  late final weeks = TextEditingController(
    text:
        (widget.course?['unscheduledWeeks'] as List?)?.join(',') ??
        '1-${selected(widget.store.data)['totalWeeks']}',
  );
  bool saving = false;
  @override
  void dispose() {
    name.dispose();
    place.dispose();
    teacher.dispose();
    weeks.dispose();
    super.dispose();
  }

  Future<void> slot([int? index]) async {
    final old = index == null ? null : schedules[index];
    int weekday = old?['weekday'] ?? DateTime.now().weekday;
    final periods = TextEditingController(
      text: (old?['periods'] as List?)?.join(',') ?? '1-2',
    );
    final pattern = TextEditingController(
      text:
          (old?['weekPattern'] as List?)?.join(',') ??
          '1-${selected(widget.store.data)['totalWeeks']}',
    );
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: const Text('上课安排'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: weekday,
                  decoration: const InputDecoration(labelText: '星期'),
                  items: List.generate(
                    7,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text('星期${'一二三四五六日'[i]}'),
                    ),
                  ),
                  onChanged: (v) => update(() => weekday = v!),
                ),
                TextField(
                  controller: periods,
                  decoration: const InputDecoration(
                    labelText: '节次',
                    hintText: '如 1-2 或 1,3',
                  ),
                ),
                TextField(
                  controller: pattern,
                  decoration: const InputDecoration(
                    labelText: '周次',
                    hintText: '如 1-16 或 1,3,5',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  final value = {
                    'weekday': weekday,
                    'periods': parseRange(
                      periods.text,
                      (widget.store.data['timeProfile']['periods'] as List)
                          .length,
                    ),
                    'weekPattern': parseRange(
                      pattern.text,
                      selected(widget.store.data)['totalWeeks'],
                    ),
                  };
                  setState(() {
                    if (index == null) {
                      schedules.add(value);
                    } else {
                      schedules[index] = value;
                    }
                  });
                  Navigator.pop(c);
                } catch (e) {
                  message(c, e);
                }
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      periods.dispose();
      pattern.dispose();
    });
  }

  Future<void> save() async {
    setState(() => saving = true);
    await attempt(context, () async {
      final c = {
        'id': widget.course?['id'] ?? uid(),
        'name': name.text.trim(),
        'location': place.text.trim(),
        'teacher': teacher.text.trim(),
        'color': color,
        'schedules': unscheduled ? <J>[] : schedules,
        if (unscheduled)
          'unscheduledWeeks': parseRange(
            weeks.text,
            selected(widget.store.data)['totalWeeks'],
          ),
      };
      await widget.store.commit((d) {
        final table = (d['timetables'] as List).firstWhere(
          (t) => t['id'] == d['selectedID'],
        );
        (table['courses'] as List).removeWhere((x) => x['id'] == c['id']);
        (table['courses'] as List).add(c);
      });
      if (mounted) Navigator.pop(context);
    });
    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.course == null ? '添加课程' : '编辑课程'),
      actions: [
        TextButton(onPressed: saving ? null : save, child: const Text('保存')),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: '课程名称'),
        ),
        TextField(
          controller: place,
          decoration: const InputDecoration(labelText: '上课地点'),
        ),
        TextField(
          controller: teacher,
          decoration: const InputDecoration(labelText: '任课教师'),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          children: palette
              .map(
                (c) => IconButton(
                  tooltip: '课程颜色',
                  onPressed: () => setState(() => color = c),
                  style: IconButton.styleFrom(
                    backgroundColor: Color(c).withValues(alpha: .2),
                  ),
                  icon: Icon(
                    color == c ? Icons.check_circle : Icons.circle,
                    color: Color(c),
                  ),
                ),
              )
              .toList(),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('未排时间的课程'),
          value: unscheduled,
          onChanged: (v) => setState(() => unscheduled = v),
        ),
        if (unscheduled)
          TextField(
            controller: weeks,
            decoration: const InputDecoration(
              labelText: '课程周次',
              hintText: '如 1-16',
            ),
          )
        else ...[
          ...schedules.asMap().entries.map(
            (e) => Card(
              child: ListTile(
                onTap: () => slot(e.key),
                title: Text(
                  '星期${'一二三四五六日'[e.value['weekday'] - 1]} · 第 ${e.value['periods'].join(',')} 节',
                ),
                subtitle: Text('第 ${e.value['weekPattern'].join(',')} 周'),
                trailing: IconButton(
                  tooltip: '删除安排',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => schedules.removeAt(e.key)),
                ),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => slot(),
            icon: const Icon(Icons.add),
            label: const Text('添加上课安排'),
          ),
        ],
        if (widget.course != null)
          TextButton.icon(
            onPressed: () async {
              if (await confirm(context, '删除课程', '将删除这门课程的全部安排，可撤销。')) {
                if (!context.mounted) return;
                await attempt(context, () async {
                  await widget.store.commit((d) {
                    for (final t in d['timetables'] as List) {
                      (t['courses'] as List).removeWhere(
                        (c) => c['id'] == widget.course!['id'],
                      );
                    }
                  });
                  if (context.mounted) Navigator.pop(context);
                });
              }
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('删除课程'),
          ),
      ],
    ),
  );
}

class TodoEditor extends StatefulWidget {
  const TodoEditor({super.key, required this.store, this.todo});
  final Store store;
  final J? todo;
  @override
  State<TodoEditor> createState() => _TodoEditorState();
}

class _TodoEditorState extends State<TodoEditor> {
  late final title = TextEditingController(text: widget.todo?['title'] ?? ''),
      notes = TextEditingController(text: widget.todo?['notes'] ?? '');
  late String importance = widget.todo?['importance'] ?? 'normal';
  late DateTime? deadline = widget.todo?['deadline'] == null
      ? null
      : DateTime.parse(widget.todo!['deadline']);
  DateTime? start, end;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final ps = objects(
      widget.store.data['placements'],
    ).where((p) => p['todoID'] == widget.todo?['id']);
    if (ps.isNotEmpty) {
      start = DateTime.parse(ps.first['start']);
      end = DateTime.parse(ps.first['end']);
    }
  }

  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => saving = true);
    await attempt(context, () async {
      final id = widget.todo?['id'] ?? uid();
      await widget.store.commit((d) {
        (d['todos'] as List).removeWhere((t) => t['id'] == id);
        (d['todos'] as List).add({
          'id': id,
          'title': title.text.trim(),
          'notes': notes.text,
          'importance': importance,
          'deadline': deadline?.toIso8601String(),
          'createdAt':
              widget.todo?['createdAt'] ?? DateTime.now().toIso8601String(),
          'completedAt': widget.todo?['completedAt'],
        });
        (d['placements'] as List).removeWhere((p) => p['todoID'] == id);
        if (start != null) {
          require(end != null, '请选择安排结束时间');
          (d['placements'] as List).add({
            'todoID': id,
            'start': start!.toIso8601String(),
            'end': end!.toIso8601String(),
          });
        }
      });
      if (mounted) Navigator.pop(context);
    });
    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.todo == null ? '添加待办' : '编辑待办'),
      actions: [
        TextButton(onPressed: saving ? null : save, child: const Text('保存')),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: '待办事项'),
          maxLength: 200,
        ),
        TextField(
          controller: notes,
          decoration: const InputDecoration(labelText: '备注'),
          minLines: 2,
          maxLines: 5,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: importance,
          decoration: const InputDecoration(labelText: '重要程度'),
          items: const [
            DropdownMenuItem(value: 'low', child: Text('低')),
            DropdownMenuItem(value: 'normal', child: Text('普通')),
            DropdownMenuItem(value: 'high', child: Text('高')),
          ],
          onChanged: (v) => setState(() => importance = v!),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('截止时间'),
          subtitle: Text(
            deadline == null
                ? '未设置'
                : '${dateText(deadline!)} ${clock(minute(deadline!))}',
          ),
          onTap: () async {
            final v = await pickDateTime(
              context,
              deadline ?? at(DateTime.now(), 1439),
            );
            if (v != null) setState(() => deadline = v);
          },
          trailing: IconButton(
            tooltip: '清除截止时间',
            onPressed: () => setState(() => deadline = null),
            icon: const Icon(Icons.close),
          ),
        ),
        const Divider(),
        const Text('安排到日程', style: TextStyle(fontWeight: FontWeight.bold)),
        const Text('工作时间与截止时间分别保存。'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('开始'),
          subtitle: Text(start?.toString().substring(0, 16) ?? '未安排'),
          onTap: () async {
            final v = await pickDateTime(context, start ?? DateTime.now());
            if (v != null) {
              setState(() {
                start = v;
                end ??= v.add(const Duration(hours: 1));
              });
            }
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('结束'),
          subtitle: Text(end?.toString().substring(0, 16) ?? '未安排'),
          onTap: () async {
            final v = await pickDateTime(
              context,
              end ?? DateTime.now().add(const Duration(hours: 1)),
            );
            if (v != null) setState(() => end = v);
          },
        ),
        if (start != null)
          TextButton(
            onPressed: () => setState(() {
              start = null;
              end = null;
            }),
            child: const Text('移出日程'),
          ),
        if (widget.todo != null)
          TextButton.icon(
            onPressed: () async {
              if (await confirm(context, '删除待办', '同时删除该事项的时间安排，可撤销。')) {
                if (!context.mounted) return;
                await attempt(context, () async {
                  await widget.store.commit((d) {
                    (d['todos'] as List).removeWhere(
                      (t) => t['id'] == widget.todo!['id'],
                    );
                    (d['placements'] as List).removeWhere(
                      (p) => p['todoID'] == widget.todo!['id'],
                    );
                  });
                  if (context.mounted) Navigator.pop(context);
                });
              }
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('删除待办'),
          ),
      ],
    ),
  );
}
