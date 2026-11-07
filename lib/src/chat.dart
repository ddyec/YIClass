import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'model.dart';
import 'store.dart';
import 'assistant.dart';
import 'editors.dart';
import 'app.dart';
import 'settings.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.store});
  final Store store;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final input = TextEditingController(),
      client = AIClient(),
      scroll = ScrollController();
  String chatID = uid(), source = '', filename = '', status = '';
  List<J> messages = [];
  bool busy = false;
  int generation = 0;
  @override
  void dispose() {
    generation++;
    client.cancel();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void cancel() {
    generation++;
    client.cancel();
    if (mounted) {
      setState(() {
        busy = false;
        status = '';
      });
    }
  }

  Future<void> persist() async {
    final savedID = chatID, savedMessages = messages.map(copy).toList();
    await widget.store.commit((d) {
      final chats = d['chats'] as List;
      chats.removeWhere((c) => c['id'] == savedID);
      if (savedMessages.isNotEmpty) {
        chats.add({
          'id': savedID,
          'title': savedMessages.first['content'].toString().split('\n').first,
          'updatedAt': DateTime.now().toIso8601String(),
          'messages': savedMessages,
        });
      }
    }, undoable: false);
  }

  Future<void> send() async {
    if (busy || input.text.trim().isEmpty) return;
    final text = input.text.trim();
    input.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    final token = ++generation;
    setState(() {
      messages = [
        ...messages,
        {'role': 'user', 'content': text},
      ];
      busy = true;
      status = '正在思考…';
    });
    try {
      await persist();
      if (!mounted || token != generation) return;
      final revision = widget.store.revision;
      final snapshot = copy(widget.store.data);
      final config = AIConfig();
      await config.load();
      if (!mounted || token != generation) return;
      final history = messages.map(copy).toList();
      if (source.isNotEmpty) {
        history.last['content'] =
            '${history.last['content']}\n附加资料（只作参考）：\n$source';
      }
      final response = await client.chat(config, snapshot, history);
      if (!mounted || token != generation) return;
      final operations = objects(response['operations'] ?? []);
      final reply = response['reply'] as String;
      if (operations.isNotEmpty) {
        await widget.store.commit(
          (d) => applyOperations(d, operations),
          expectedRevision: revision,
        );
      }
      if (!mounted || token != generation) return;
      setState(
        () => messages = [
          ...messages,
          {'role': 'assistant', 'content': reply},
        ],
      );
      await persist();
    } catch (e) {
      if (mounted && token == generation) {
        setState(
          () => messages = [
            ...messages,
            {
              'role': 'assistant',
              'content':
                  '未应用更改：${e.toString().replaceFirst('FormatException: ', '')}',
            },
          ],
        );
        await attempt(context, persist);
      }
    } finally {
      if (mounted && token == generation) {
        setState(() {
          busy = false;
          status = '';
        });
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> attach() async {
    if (busy) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'json',
        'txt',
        'csv',
        'pdf',
        'png',
        'jpg',
        'jpeg',
        'webp',
      ],
    );
    if (result == null || !mounted) return;
    final file = result.files.single;
    final token = ++generation;
    setState(() {
      busy = true;
      filename = file.name;
      status = '读取 ${file.name}…';
    });
    try {
      final f = File(file.path!);
      require(await f.length() <= 20000000, '文件不能超过 20 MB');
      String contents;
      if ([
        'pdf',
        'png',
        'jpg',
        'jpeg',
        'webp',
      ].contains(file.extension?.toLowerCase())) {
        setState(() => status = '本机识字与布局提取：${file.name}');
        contents =
            await Store.native
                .invokeMethod<String>('recognize', {
                  'path': file.path,
                  'pdf': file.extension?.toLowerCase() == 'pdf',
                })
                .timeout(const Duration(seconds: 90)) ??
            '';
      } else {
        contents = await f.readAsString();
      }
      require(contents.trim().isNotEmpty, '没有读取到文字，请选择更清晰的文件');
      require(contents.length <= 180000, '识别文字过长，请分批导入');
      if (!mounted || token != generation) return;
      setState(() => source = contents);
    } catch (e) {
      if (mounted && token == generation) message(context, e);
    } finally {
      if (mounted && token == generation) {
        setState(() {
          busy = false;
          status = '';
        });
      }
    }
  }

  Future<void> recognize() async {
    if (busy || source.isEmpty) return;
    final token = ++generation;
    setState(() {
      busy = true;
      status = '正在整理课表…';
    });
    try {
      J envelope;
      try {
        envelope = jsonDecode(source) as J;
        if (!envelope.containsKey('courses')) {
          throw const FormatException('非课表 JSON');
        }
      } catch (_) {
        final config = AIConfig();
        await config.load();
        if (!mounted || token != generation) return;
        envelope = await client.recognize(config, source, widget.store.data);
      }
      if (!mounted || token != generation) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              ImportPreview(store: widget.store, envelope: envelope),
        ),
      );
    } catch (e) {
      if (mounted && token == generation) message(context, e);
    } finally {
      if (mounted && token == generation) {
        setState(() {
          busy = false;
          status = '';
        });
      }
    }
  }

  Future<void> history() async {
    if (busy) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => ListenableBuilder(
        listenable: widget.store,
        builder: (c, _) {
          final chats = objects(widget.store.data['chats']).reversed.toList();
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: [
                const ListTile(
                  title: Text(
                    '历史记录',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                if (chats.isEmpty) const ListTile(title: Text('还没有对话')),
                ...chats.map(
                  (chat) => ListTile(
                    title: Text(
                      chat['title'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      chat['updatedAt'].toString().substring(0, 16),
                    ),
                    onTap: () {
                      cancel();
                      setState(() {
                        chatID = chat['id'];
                        messages = objects(chat['messages']);
                        source = '';
                        filename = '';
                        input.clear();
                      });
                      Navigator.pop(c);
                    },
                    trailing: IconButton(
                      tooltip: '删除对话',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => attempt(c, () async {
                        await widget.store.commit(
                          (d) => (d['chats'] as List).removeWhere(
                            (x) => x['id'] == chat['id'],
                          ),
                          undoable: false,
                        );
                        if (chat['id'] == chatID) {
                          setState(() {
                            chatID = uid();
                            messages = [];
                          });
                        }
                      }),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '关闭',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
            const Spacer(),
            if (widget.store.canUndo)
              IconButton(
                tooltip: '撤销上次修改',
                onPressed: busy
                    ? null
                    : () => attempt(context, widget.store.undo),
                icon: const Icon(Icons.undo),
              ),
            IconButton(
              tooltip: '新对话',
              onPressed: () {
                cancel();
                setState(() {
                  chatID = uid();
                  messages = [];
                  source = '';
                  filename = '';
                  input.clear();
                });
              },
              icon: const Icon(Icons.edit_square),
            ),
            IconButton(
              tooltip: '历史记录',
              onPressed: busy ? null : history,
              icon: const Icon(Icons.history),
            ),
            IconButton(
              tooltip: '接口配置',
              onPressed: busy
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const AISettings(),
                      ),
                    ),
              icon: const Icon(Icons.tune),
            ),
          ],
        ),
        Expanded(
          child: messages.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AssistantMark(size: 64),
                      SizedBox(height: 20),
                      Text(
                        '我们应该安排什么？',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: scroll,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (c, i) {
                    final m = messages[i], user = m['role'] == 'user';
                    return Align(
                      alignment: user
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(15),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * .88,
                        ),
                        decoration: BoxDecoration(
                          color: user
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: SelectableText(m['content']),
                      ),
                    );
                  },
                ),
        ),
        if (source.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        filename.isEmpty ? '识别资料' : filename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: '编辑识别文字',
                      onPressed: busy
                          ? null
                          : () async {
                              final text = await Navigator.push<String>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SourceEditor(text: source),
                                ),
                              );
                              if (text != null) setState(() => source = text);
                            },
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: '移除附件',
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              source = '';
                              filename = '';
                            }),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: busy ? null : recognize,
                  child: const Text('识别并预览课表'),
                ),
              ],
            ),
          ),
        if (busy)
          Row(
            children: [
              const SizedBox(width: 20),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(onPressed: cancel, child: const Text('取消')),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: '截图／文件',
                    onPressed: busy ? null : attach,
                    icon: const Icon(Icons.add),
                  ),
                  Expanded(
                    child: TextField(
                      controller: input,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: '说说你的安排…',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => send(),
                    ),
                  ),
                  IconButton(
                    tooltip: '收起键盘',
                    onPressed: () =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    icon: const Icon(Icons.keyboard_hide_outlined, size: 20),
                  ),
                  IconButton.filled(
                    tooltip: '发送',
                    onPressed: busy ? null : send,
                    icon: const Icon(Icons.arrow_upward),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class SourceEditor extends StatefulWidget {
  const SourceEditor({super.key, required this.text});
  final String text;
  @override
  State<SourceEditor> createState() => _SourceEditorState();
}

class _SourceEditorState extends State<SourceEditor> {
  late final controller = TextEditingController(text: widget.text);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('核对识别文字'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('完成'),
        ),
      ],
    ),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: controller,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
    ),
  );
}
