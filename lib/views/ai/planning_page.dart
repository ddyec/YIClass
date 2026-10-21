import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/ai/planning_engine.dart';
import '../../services/ai/planning_service.dart';
import '../../services/file_service.dart';
import '../../states/timetable_state.dart';
import 'ai_config_page.dart';
import '../../components/layout/appbar.dart';
import '../../components/layout/cards.dart';
import '../../components/inputs/components.dart';

class PlanningPage extends StatefulWidget {
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>, String,
      {String? imageBase64})? planRequest;
  const PlanningPage({super.key, this.planRequest});
  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  final _request = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _imageBase64;
  Future<void> _attach() async {
    final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 3200,
        maxHeight: 3200,
        imageQuality: 90);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 20 * 1024 * 1024) {
      setState(() => _error = '图片请小于 20 MB');
      return;
    }
    setState(() => _imageBase64 = base64Encode(bytes));
  }

  Map<String, dynamic>? _baseline, _proposal, _result, _undo, _applied;

  @override
  void dispose() {
    _request.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final current = context.read<TimetableState>().current;
    if (current == null ||
        (_request.text.trim().isEmpty && _imageBase64 == null)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _proposal = null;
      _result = null;
    });
    try {
      final baseline = FileService.toMap(current)..remove('exportTime');
      final proposal = await (widget.planRequest ?? PlanningService.propose)(
          baseline, _request.text.trim(),
          imageBase64: _imageBase64);
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
    final confirm = !undo
        ? true
        : await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                  title: Text(undo ? '撤销上次方案？' : '应用此方案？'),
                  content: const Text('将保存当前预览的安排。'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('返回')),
                    YicoreButton(
                        text: '确认',
                        onPressed: () => Navigator.pop(context, true)),
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
    if (type == 'event') {
      final e = a['event'];
      return '${e['name']}\n${_time(e['start'])} — ${_time(e['end'])} · ${e['location'] ?? ''}';
    }
    if (type == 'removeEvent') {
      final e = (_baseline!['events'] as List? ?? [])
          .where((e) => e['id'] == a['eventId'])
          .firstOrNull;
      return '删除 ${e?['name'] ?? '事件'}';
    }
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
        '${c['name']} 第${_numbers(a['weeks'])}周 ${_day(source['weekday'])} 第${_numbers(source['periods'])}节';
    if (type == 'cancel') return '取消 $from';
    return '${type == 'copy' ? '补课' : '移动'} $from\n→ 第${_numbers(a['targetWeeks'])}周 ${_day(a['targetWeekday'])} 第${_numbers(a['targetPeriods'])}节 ${a['location'] ?? c['location']}';
  }

  String _time(dynamic v) =>
      v.toString().replaceFirst('T', ' ').replaceFirst(RegExp(r':00$'), '');
  String _numbers(dynamic v) => (v as List).join('、');
  String _day(dynamic v) =>
      const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][(v as int) - 1];
  String _schedules(List schedules) => schedules
      .map((s) =>
          '第${_numbers(s['weekPattern'])}周 ${_day(s['weekday'])} 第${_numbers(s['periods'])}节')
      .join('\n');

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        appBar: YicoreAppBar(title: 'AI 助手', centerTitle: true, actions: [
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
          const SizedBox.shrink(),
          const SizedBox(height: 8),
          YicoreCard(
              child: TextField(
                  controller: _request,
                  enabled: !_busy,
                  minLines: 4,
                  maxLines: 8,
                  cursorColor: Colors.black,
                  decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '想怎样调整？\n例如：明天 13:10–14:05 安排紧急会议。'))),
          Row(children: [
            TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.black),
                onPressed: _busy ? null : _attach,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(_imageBase64 == null ? '添加图片' : '已添加图片')),
            if (_imageBase64 != null)
              IconButton(
                  onPressed:
                      _busy ? null : () => setState(() => _imageBase64 = null),
                  icon: const Icon(Icons.close, size: 18))
          ]),
          Text('使用已配置的 AI 处理课表',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 12),
          YicoreButton(
              text: '生成方案',
              isLoading: _busy,
              onPressed: _busy ? null : _generate),
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
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: YicoreCard(child: Text(_describe(a as Map)))),
              YicoreButton(
                  text: '应用方案', onPressed: _busy ? null : () => _save()),
            ],
          ],
          if (_undo != null)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: YicoreButton(
                    text: '撤销上次应用',
                    isOutlined: true,
                    onPressed: _busy ? null : () => _save(undo: true))),
        ])),
      );
}
