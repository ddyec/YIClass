import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/ai/planning_engine.dart';
import '../../services/ai/planning_service.dart';
import '../../services/ai/planning_diff.dart';
import '../../services/file_service.dart';
import '../../states/timetable_state.dart';
import 'ai_config_page.dart';
import '../../components/layout/appbar.dart';
import '../../components/layout/cards.dart';
import '../../components/inputs/components.dart';

class PlanningPage extends StatefulWidget {
  final Future<Map<String, dynamic>> Function(
    Map<String, dynamic>,
    String, {
    String? imageBase64,
  })? planRequest;
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
      imageQuality: 90,
    );
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
        baseline,
        _request.text.trim(),
        imageBase64: _imageBase64,
      );
      Map<String, dynamic>? result;
      if ((proposal['questions'] as List?)?.isEmpty == true) {
        result = FileService.toMap(FileService.fromMap(
          PlanningEngine.apply(baseline, proposal),
        ))
          ..remove('exportTime');
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
                  child: const Text('返回'),
                ),
                YicoreButton(
                  text: '确认',
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ),
          );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(undo ? '已撤销' : '已应用，可在此页撤销')));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        appBar: YicoreAppBar(
          title: 'AI 助手',
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'API 配置',
              onPressed: _busy
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AIConfigPage()),
                      ),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
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
                    hintText: '想怎样安排学习？\n例如：明天下午安排一小时自习，或按学校通知调整课表。',
                  ),
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.black),
                    onPressed: _busy ? null : _attach,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(_imageBase64 == null ? '添加图片' : '已添加图片'),
                  ),
                  if (_imageBase64 != null)
                    IconButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _imageBase64 = null),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                ],
              ),
              Text(
                '使用已配置的 AI 处理课表',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              YicoreButton(
                text: '生成方案',
                isLoading: _busy,
                onPressed: _busy ? null : _generate,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    _error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              if (_proposal != null) ...[
                const SizedBox(height: 16),
                Text(_proposal!['summary']?.toString() ?? ''),
                for (final q in _proposal!['questions'] as List? ?? [])
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: Text('$q'),
                  ),
                if (_result != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '具体改动（应用后保存）',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (final change
                      in PlanningDiff.between(_baseline!, _result!))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: YicoreCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              change.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (change.before.isNotEmpty)
                              Text('原安排：\n${change.before}'),
                            Text(
                              change.after.isEmpty
                                  ? '新安排：已移除'
                                  : '新安排：\n${change.after}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (PlanningEngine.conflicts(_result!).isNotEmpty)
                    Text(
                      '时间冲突（请核对）：\n${PlanningEngine.conflicts(_result!).join('\n')}',
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ExpansionTile(
                    title: const Text('查看修改后的完整 JSON'),
                    children: [
                      SelectableText(
                        const JsonEncoder.withIndent('  ').convert(_result),
                      ),
                    ],
                  ),
                  YicoreButton(
                    text: '应用方案',
                    onPressed: _busy ? null : () => _save(),
                  ),
                ],
              ],
              if (_undo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: YicoreButton(
                    text: '撤销上次应用',
                    isOutlined: true,
                    onPressed: _busy ? null : () => _save(undo: true),
                  ),
                ),
            ],
          ),
        ),
      );
}
