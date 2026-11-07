import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'model.dart';
import 'store.dart';
import 'editors.dart';
import 'assistant.dart';
import 'app.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.store});
  final Store store;
  Future<void> export(BuildContext context, {bool full = false}) async {
    await attempt(context, () async {
      final contents = const JsonEncoder.withIndent(
        '  ',
      ).convert(full ? store.data : exportTable(store.data));
      final file = File(
        '${store.directory.path}/${full ? 'YIClass-backup' : 'YIClass-timetable'}.json',
      );
      await file.writeAsString(contents);
      if (!context.mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    });
  }

  Future<void> import(BuildContext context) async {
    await attempt(context, () async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null) return;
      final file = File(result.files.single.path!);
      require(await file.length() <= 10000000, '请选择 10 MB 以下的 JSON 文件');
      final j = jsonDecode(await file.readAsString()) as J;
      if (!context.mounted) return;
      if (j.containsKey('timetables')) {
        validate(j);
        if (await confirm(context, '恢复完整备份', '将替换当前全部课表、待办与对话，可撤销。')) {
          await store.commit((d) {
            d.clear();
            d.addAll(j);
          });
        }
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ImportPreview(store: store, envelope: j),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = store.data, table = selected(data);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      children: [
        const Text(
          '设置',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/icon/app_logo.png',
                width: 48,
                height: 48,
              ),
            ),
            title: const Text(
              'YIClass',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 21),
            ),
            subtitle: const Text('Android · 3.3.0'),
          ),
        ),
        section('课表与时间'),
        Card(
          child: Column(
            children: [
              ListTile(
                title: const Text('学期设置'),
                subtitle: Text(
                  '${table['startDate']} · ${table['totalWeeks']} 周',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => TermSettings(store: store),
                  ),
                ),
              ),
              ListTile(
                title: const Text('统一课节时间'),
                subtitle: Text(
                  '${(data['timeProfile']['periods'] as List).length} 节 · 所有课表共用',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => TimeSettings(store: store),
                  ),
                ),
              ),
              SwitchListTile(
                title: const Text('显示周末'),
                value: table['showWeekend'],
                onChanged: (v) => attempt(
                  context,
                  () => store.commit(
                    (d) => (d['timetables'] as List).firstWhere(
                      (t) => t['id'] == d['selectedID'],
                    )['showWeekend'] = v,
                  ),
                ),
              ),
            ],
          ),
        ),
        section('外观'),
        Card(
          child: Column(
            children: [
              ListTile(
                title: const Text('深浅模式'),
                trailing: DropdownButton<String>(
                  value: data['theme'],
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'system', child: Text('跟随系统')),
                    DropdownMenuItem(value: 'light', child: Text('浅色')),
                    DropdownMenuItem(value: 'dark', child: Text('深色')),
                  ],
                  onChanged: (v) => attempt(
                    context,
                    () => store.commit((d) => d['theme'] = v),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    ...palette.map(
                      (c) => IconButton(
                        tooltip: '主题颜色',
                        onPressed: () => attempt(
                          context,
                          () => store.commit((d) => d['accent'] = c),
                        ),
                        icon: Icon(
                          data['accent'] == c
                              ? Icons.check_circle
                              : Icons.circle,
                          color: Color(c),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '自定义颜色',
                      onPressed: () async {
                        final hex = await ask(
                          context,
                          '主题色',
                          initial: (data['accent'] as int)
                              .toRadixString(16)
                              .substring(2),
                          hint: '六位十六进制，例如 637eea',
                        );
                        if (hex != null && context.mounted) {
                          await attempt(context, () async {
                            require(
                              RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex),
                              '请输入六位颜色代码',
                            );
                            await store.commit(
                              (d) =>
                                  d['accent'] = int.parse('ff$hex', radix: 16),
                            );
                          });
                        }
                      },
                      icon: const Icon(Icons.palette_outlined),
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                title: const Text('柔和渐变背景'),
                value: data['gradient'],
                onChanged: (v) => attempt(
                  context,
                  () => store.commit((d) => d['gradient'] = v),
                ),
              ),
            ],
          ),
        ),
        section('AI 助手'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const AssistantMark(),
                title: const Text('模式与接口配置'),
                subtitle: const Text('HTTPS · OpenAI 兼容接口'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const AISettings()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.document_scanner_outlined),
                title: const Text('识别课表'),
                subtitle: const Text('图片、PDF、TXT、CSV'),
                onTap: () => showChat(context, store),
              ),
            ],
          ),
        ),
        section('系统功能'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('课程与日程提醒'),
                subtitle: const Text('按实际开课与待办安排提醒'),
                value: data['reminders'],
                onChanged: (v) => attempt(context, () async {
                  if (v) {
                    await Store.native.invokeMethod('requestNotifications');
                  }
                  await store.commit((d) => d['reminders'] = v);
                }),
              ),
              ListTile(
                title: const Text('提前提醒'),
                trailing: DropdownButton<int>(
                  value: data['reminderMinutes'],
                  items: [0, 5, 10, 15, 30, 60]
                      .map(
                        (n) => DropdownMenuItem(value: n, child: Text('$n 分钟')),
                      )
                      .toList(),
                  onChanged: (v) => attempt(
                    context,
                    () => store.commit((d) => d['reminderMinutes'] = v),
                  ),
                ),
              ),
              ListTile(
                title: const Text('桌面小组件'),
                subtitle: const Text('长按桌面 → 小组件 → YIClass，可查看课程与待办'),
                trailing: const Icon(Icons.sync),
                onTap: () => attempt(context, () async {
                  await store.syncPlatform();
                  if (context.mounted) {
                    message(context, store.platformIssue ?? '小组件与提醒已同步');
                  }
                }),
              ),
              ListTile(
                title: const Text('提醒权限与电池设置'),
                subtitle: const Text('系统可能延迟提醒，可在此检查应用权限'),
                onTap: () => attempt(context, () async {
                  await Store.native.invokeMethod('openSettings');
                }),
              ),
              if (store.platformIssue != null)
                ListTile(title: Text(store.platformIssue!)),
            ],
          ),
        ),
        section('资料'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('导出当前课表'),
                subtitle: const Text('兼容 iOS JSON，不含待办'),
                onTap: () => export(context),
              ),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('导入课表或备份'),
                onTap: () => import(context),
              ),
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: const Text('导出完整备份'),
                subtitle: const Text('课表、待办、日程、对话；不含 API Key'),
                onTap: () => export(context, full: true),
              ),
              ListTile(
                leading: const Icon(Icons.undo),
                title: const Text('撤销上次修改'),
                enabled: store.canUndo,
                onTap: () => attempt(context, store.undo),
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('恢复上一版文件'),
                onTap: () async {
                  if (await confirm(context, '恢复备份', '恢复上次保存前的全部资料。')) {
                    if (context.mounted) await attempt(context, store.recover);
                  }
                },
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'YIClass',
            applicationVersion: '3.3.0',
          ),
          child: const Text('开源许可'),
        ),
      ],
    );
  }

  Widget section(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 0, 6),
    child: Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  );
}

class TermSettings extends StatelessWidget {
  const TermSettings({super.key, required this.store});
  final Store store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final t = selected(store.data);
      Future<void> set(String key, dynamic value) => store.commit(
        (d) => (d['timetables'] as List).firstWhere(
          (t) => t['id'] == d['selectedID'],
        )[key] = value,
      );
      return Scaffold(
        appBar: AppBar(title: const Text('学期设置')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              title: const Text('开学日期'),
              subtitle: Text(t['startDate']),
              onTap: () async {
                final v = await pickDate(
                  context,
                  DateTime.parse(t['startDate']),
                );
                if (v != null && context.mounted) {
                  await attempt(context, () => set('startDate', dateText(v)));
                }
              },
            ),
            ListTile(
              title: const Text('学期周数'),
              subtitle: Text('${t['totalWeeks']} 周'),
              onTap: () async {
                final v = await ask(
                  context,
                  '学期周数',
                  initial: t['totalWeeks'].toString(),
                );
                if (v != null && context.mounted) {
                  await attempt(context, () => set('totalWeeks', int.parse(v)));
                }
              },
            ),
            const Divider(),
            const ListTile(title: Text('停课日期')),
            ...List<String>.from(t['holidays']).map(
              (h) => ListTile(
                title: Text(h),
                trailing: IconButton(
                  tooltip: '取消停课',
                  icon: const Icon(Icons.close),
                  onPressed: () => attempt(
                    context,
                    () => set(
                      'holidays',
                      List<String>.from(t['holidays'])..remove(h),
                    ),
                  ),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final v = await pickDate(context, DateTime.now());
                if (v != null && context.mounted) {
                  await attempt(
                    context,
                    () => set(
                      'holidays',
                      <String>{
                        ...List<String>.from(t['holidays']),
                        dateText(v),
                      }.toList(),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('添加停课日期'),
            ),
          ],
        ),
      );
    },
  );
}

class TimeSettings extends StatelessWidget {
  const TimeSettings({super.key, required this.store});
  final Store store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final ps = objects(store.data['timeProfile']['periods']);
      return Scaffold(
        appBar: AppBar(title: const Text('统一课节时间')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              title: const Text('上午、下午、晚上节数'),
              subtitle: Text(
                numbers(store.data['timeProfile']['sessionCounts']).join(' + '),
              ),
              onTap: () async {
                final v = await ask(
                  context,
                  '分段节数',
                  initial: numbers(
                    store.data['timeProfile']['sessionCounts'],
                  ).join(','),
                  hint: '例如 4,4,2',
                );
                if (v != null && context.mounted) {
                  await attempt(
                    context,
                    () => store.commit(
                      (d) => resizeSessions(
                        d,
                        v.split(',').map((n) => int.parse(n.trim())).toList(),
                      ),
                    ),
                  );
                }
              },
            ),
            ListTile(
              title: const Text('统一时长与课间'),
              subtitle: const Text('保留午休和晚间间隔'),
              onTap: () async {
                final v = await ask(context, '课程时长、课间（分钟）', initial: '45,10');
                if (v != null && context.mounted) {
                  await attempt(
                    context,
                    () => store.commit((d) {
                      final values = v.split(',').map(int.parse).toList();
                      require(
                        values.length == 2 && values[0] > 0 && values[1] >= 0,
                        '请输入有效的时长和课间',
                      );
                      final original = objects(d['timeProfile']['periods']),
                          counts = numbers(d['timeProfile']['sessionCounts']);
                      final periods = d['timeProfile']['periods'] as List;
                      for (var i = 0; i < periods.length; i++) {
                        if (i > 0) {
                          final boundary =
                              i == counts[0] || i == counts[0] + counts[1];
                          periods[i]['start'] =
                              periods[i - 1]['end'] +
                              (boundary
                                  ? original[i]['start'] -
                                        original[i - 1]['end']
                                  : values[1]);
                        }
                        periods[i]['end'] = periods[i]['start'] + values[0];
                      }
                    }),
                  );
                }
              },
            ),
            ...ps.asMap().entries.map(
              (e) => Card(
                child: ListTile(
                  title: Text('第 ${e.key + 1} 节'),
                  subtitle: Row(
                    children: ['start', 'end']
                        .map(
                          (key) => TextButton(
                            onPressed: () async {
                              final old = e.value[key] as int;
                              final v = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(
                                  hour: old ~/ 60,
                                  minute: old % 60,
                                ),
                              );
                              if (v != null && context.mounted) {
                                await attempt(
                                  context,
                                  () => store.commit((d) {
                                    final p =
                                        d['timeProfile']['periods'] as List;
                                    final delta = v.hour * 60 + v.minute - old;
                                    if (key == 'start') {
                                      for (var i = e.key; i < p.length; i++) {
                                        p[i]['start'] += delta;
                                        p[i]['end'] += delta;
                                      }
                                    } else {
                                      p[e.key]['end'] += delta;
                                      for (
                                        var i = e.key + 1;
                                        i < p.length;
                                        i++
                                      ) {
                                        p[i]['start'] += delta;
                                        p[i]['end'] += delta;
                                      }
                                    }
                                  }),
                                );
                              }
                            },
                            child: Text(
                              '${key == 'start' ? '开始' : '结束'} ${clock(e.value[key])}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class AISettings extends StatefulWidget {
  const AISettings({super.key});
  @override
  State<AISettings> createState() => _AISettingsState();
}

class _AISettingsState extends State<AISettings> {
  final endpoint = TextEditingController(),
      model = TextEditingController(),
      key = TextEditingController(),
      client = AIClient();
  bool ready = false, busy = false;
  String? status;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final c = AIConfig();
      await c.load();
      if (!mounted) return;
      endpoint.text = c.endpoint;
      model.text = c.model;
      key.text = c.key;
      setState(() => ready = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          ready = true;
          status = e.toString();
        });
      }
    }
  }

  AIConfig config() => AIConfig()
    ..endpoint = endpoint.text.trim()
    ..model = model.text.trim()
    ..key = key.text.trim();
  @override
  void dispose() {
    client.cancel();
    endpoint.dispose();
    model.dispose();
    key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('AI 接口配置'),
      actions: [
        TextButton(
          onPressed: !ready || busy
              ? null
              : () => attempt(context, () async {
                  await config().save();
                  if (context.mounted) Navigator.pop(context);
                }),
          child: const Text('保存'),
        ),
      ],
    ),
    body: !ready
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                '使用 OpenAI 兼容接口。API Key 由 Android 安全存储保管，仅发送给你设置的 HTTPS 服务。对话与识别时会发送相关资料和课表。',
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  endpoint.text = 'https://api.deepseek.com/chat/completions';
                  model.text = 'deepseek-chat';
                },
                child: const Text('填入 DeepSeek 配置'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: endpoint,
                decoration: const InputDecoration(
                  labelText: '完整 Chat Completions 地址',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: model,
                decoration: const InputDecoration(labelText: '模型名称'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: key,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'API Key'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        setState(() {
                          busy = true;
                          status = '正在测试当前填写的配置…';
                        });
                        try {
                          await client.request(config(), [
                            {'role': 'user', 'content': 'Reply with OK.'},
                          ], json: false);
                          if (mounted) setState(() => status = '连接成功');
                        } catch (e) {
                          if (mounted) setState(() => status = e.toString());
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
                child: const Text('测试连接（不上传课表）'),
              ),
              if (status != null) SelectableText(status!),
            ],
          ),
  );
}

class ImportPreview extends StatefulWidget {
  const ImportPreview({super.key, required this.store, required this.envelope});
  final Store store;
  final J envelope;
  @override
  State<ImportPreview> createState() => _ImportPreviewState();
}

class _ImportPreviewState extends State<ImportPreview> {
  late J envelope = copy(widget.envelope);
  bool adopt = false, saving = false;
  @override
  Widget build(BuildContext context) {
    J? table;
    String? issue;
    try {
      final previewData = copy(widget.store.data);
      if (adopt) previewData['timeProfile'] = envelope['timeProfile'];
      table = importTable(envelope, previewData);
    } catch (e) {
      issue = e.toString();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('导入预览')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('导入会新建课表。请核对开学日期、课程与周次，识别结果可以返回修改。'),
          const SizedBox(height: 12),
          if (issue != null) SelectableText(issue),
          ListTile(
            title: Text(envelope['name'] ?? '导入课表'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () async {
              final n = await ask(
                context,
                '课表名称',
                initial: envelope['name'] ?? '导入课表',
              );
              if (n != null) setState(() => envelope['name'] = n);
            },
          ),
          ListTile(
            title: const Text('开学日期'),
            subtitle: Text(
              envelope['settings']?['startDate'] ??
                  selected(widget.store.data)['startDate'],
            ),
            onTap: () async {
              final v = await pickDate(
                context,
                DateTime.parse(
                  envelope['settings']?['startDate'] ??
                      selected(widget.store.data)['startDate'],
                ),
              );
              if (v != null) {
                setState(() {
                  envelope['settings'] ??= <String, dynamic>{};
                  envelope['settings']['startDate'] = dateText(v);
                });
              }
            },
          ),
          if (envelope['timeProfile'] != null)
            SwitchListTile(
              title: const Text('采用文件内课节时间'),
              subtitle: const Text('会同时检查全部已有课表'),
              value: adopt,
              onChanged: (v) => setState(() => adopt = v),
            ),
          if (table != null)
            ...objects(table['courses']).map(
              (c) => Card(
                child: ListTile(
                  title: Text(c['name']),
                  subtitle: Text(
                    '${c['teacher']} · ${c['location']}\n${objects(c['schedules']).map((s) => '周${'一二三四五六日'[s['weekday'] - 1]}  第${s['periods'].join(',')}节  ${s['weekPattern'].join(',')}周').join('\n')}${c['unscheduledWeeks'] == null ? '' : '未排课：${c['unscheduledWeeks'].join(',')}周'}',
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: table == null || saving
                ? null
                : () async {
                    setState(() => saving = true);
                    await attempt(context, () async {
                      await widget.store.commit((d) {
                        if (adopt) d['timeProfile'] = envelope['timeProfile'];
                        final t = importTable(envelope, d);
                        (d['timetables'] as List).add(t);
                        d['selectedID'] = t['id'];
                      });
                      if (context.mounted) Navigator.pop(context);
                    });
                    if (mounted) setState(() => saving = false);
                  },
            child: const Text('确认并新建课表'),
          ),
        ],
      ),
    );
  }
}
