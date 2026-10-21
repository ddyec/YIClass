import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/ai/planning_engine.dart';
import '../../services/ai/planning_service.dart';
import '../../services/file_service.dart';
import '../../states/timetable_state.dart';
import 'ai_config_page.dart';

class PlanningPage extends StatefulWidget {
  const PlanningPage({super.key});
  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  final _request = TextEditingController();
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _baseline, _proposal, _result, _undo, _applied;

  @override
  void dispose() {
    _request.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final current = context.read<TimetableState>().current;
    if (current == null || _request.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _proposal = null;
      _result = null;
    });
    try {
      final baseline = FileService.toMap(current)..remove('exportTime');
      final proposal =
          await PlanningService.propose(baseline, _request.text.trim());
      Map<String, dynamic>? result;
      if ((proposal['questions'] as List?)?.isEmpty == true) {
        result = PlanningEngine.apply(baseline, proposal);
      }
      if (!mounted) return;
      setState(() {
        _baseline = baseline;
        _proposal = proposal;
        _result = result;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save({bool undo = false}) async {
    final state = context.read<TimetableState>();
    final current = state.current;
    final expected = undo ? _applied : _baseline;
    final target = undo ? _undo : _result;
    if (current == null || target == null) return;
    final snapshot = FileService.toMap(current)..remove('exportTime');
    if (jsonEncode(snapshot) != jsonEncode(expected)) {
      setState(() => _error = '课表已变化，请重新生成方案，避免覆盖新修改。');
      return;
    }
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(undo ? '撤销上次方案？' : '应用此方案？'),
              content: const Text('这会修改个人课表。涉及学校课程的调整请自行确认。'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('返回')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('确认')),
              ],
            ));
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      // Recheck after the dialog: another page may have edited the timetable.
      final latest = FileService.toMap(state.current!)..remove('exportTime');
      if (jsonEncode(latest) != jsonEncode(expected)) {
        throw StateError('课表已变化，请重新生成');
      }
      final ok = await state.put(FileService.fromMap(target));
      if (!ok) throw StateError('保存失败，原课表未被替换');
      if (!mounted) return;
      setState(() {
        if (undo) {
          _undo = null;
          _applied = null;
        } else {
          _undo = _baseline;
          _applied = FileService.toMap(state.current!)..remove('exportTime');
        }
        _result = null;
        _proposal = null;
        _error = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(undo ? '已撤销' : '已应用，可在此页撤销')));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _describe(Map a) {
    final type = a['type'];
    if (type == 'rest' || type == 'resume') {
      return '${type == 'rest' ? '休假' : '恢复上课'} ${a['date']}';
    }
    if (type == 'add') {
      final c = a['course'];
      return '新增 ${c['name']} · ${c['location'] ?? ''}\n${_schedules(c['schedules'])}';
    }
    final c = _baseline!['courses'][a['courseIndex']];
    final source = c['schedules'][a['scheduleIndex']];
    final from =
        '${c['name']} 第${a['weeks']}周 星期${source['weekday']} ${source['periods']}节';
    if (type == 'cancel') return '取消 $from';
    return '${type == 'copy' ? '补课' : '移动'} $from\n→ 第${a['targetWeeks']}周 星期${a['targetWeekday']} ${a['targetPeriods']}节 ${a['location'] ?? c['location']}';
  }

  String _schedules(List schedules) => schedules
      .map((s) => '第${s['weekPattern']}周 星期${s['weekday']} ${s['periods']}节')
      .join('\n');

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('AI 排课助手'), actions: [
          IconButton(
            tooltip: 'API 配置',
            onPressed: _busy
                ? null
                : () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AIConfigPage())),
            icon: const Icon(Icons.settings_outlined),
          )
        ]),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('描述要安排或调整的课程、周次和时间。'),
          const SizedBox(height: 8),
          TextField(
              controller: _request,
              enabled: !_busy,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '例如：第8周周一化学课调到同周周六1–2节；第9周周五休假，并补到周六。')),
          const SizedBox(height: 12),
          const Text('生成时会将当前课表和请求发送至你配置的 API。'),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: _busy ? null : _generate,
              child: Text(_busy ? '处理中…' : '生成方案')),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          if (_proposal != null) ...[
            const SizedBox(height: 16),
            Text(_proposal!['summary']?.toString() ?? ''),
            for (final q in _proposal!['questions'] as List? ?? [])
              ListTile(
                  leading: const Icon(Icons.help_outline), title: Text('$q')),
            if (_result != null) ...[
              for (final a in _proposal!['actions'])
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_describe(a as Map)))),
              FilledButton(
                  onPressed: _busy ? null : () => _save(),
                  child: const Text('确认并应用')),
            ],
          ],
          if (_undo != null)
            OutlinedButton(
                onPressed: _busy ? null : () => _save(undo: true),
                child: const Text('撤销上次应用')),
        ])),
      );
}
