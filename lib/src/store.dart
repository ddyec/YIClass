import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'model.dart';

class Store extends ChangeNotifier {
  Store(this.directory);
  final Directory directory;
  J data = fresh();
  String? error, platformIssue;
  J? _undo;
  Future<void> _queue = Future.value();
  static const native = MethodChannel('yiclass/android');
  File get file => File('${directory.path}/library-v3.json');
  File get backup => File('${file.path}.bak');
  int get revision => data['revision'] as int;
  bool get canUndo => _undo != null;
  static Future<Store> open() async {
    final s = Store(await getApplicationSupportDirectory());
    await s.load();
    return s;
  }

  Future<void> load() async {
    if (!await file.exists()) return;
    try {
      final d = jsonDecode(await file.readAsString()) as J;
      validate(d);
      data = d;
    } catch (e) {
      error = '本地数据读取失败，原文件已保留。可恢复上一版备份。\n$e';
    }
  }

  Future<void> _write(J next, {bool preserveBackup = false}) async {
    await directory.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(next), flush: true);
    if (!preserveBackup && await file.exists()) {
      // Atomically replace the backup too; a process interruption cannot truncate it.
      final tempBackup = File('${backup.path}.tmp');
      await file.copy(tempBackup.path);
      await tempBackup.rename(backup.path);
    }
    await temporary.rename(file.path);
  }

  Future<void> commit(
    void Function(J) edit, {
    int? expectedRevision,
    bool undoable = true,
  }) {
    final result = Completer<void>();
    _queue = _queue.then((_) async {
      try {
        if (error != null) throw StateError('请先恢复本地数据，再继续编辑');
        if (expectedRevision != null && revision != expectedRevision) {
          throw StateError('资料已发生变化，请重新发送这条指令');
        }
        final next = copy(data);
        edit(next);
        next['revision'] = revision + 1;
        validate(next);
        await _write(next);
        if (undoable) _undo = copy(data);
        data = next;
        notifyListeners();
        await syncPlatform();
        result.complete();
      } catch (e, st) {
        result.completeError(e, st);
      }
    });
    return result.future;
  }

  Future<void> undo() async {
    final old = _undo;
    if (old == null) return;
    await commit((d) {
      final revision = d['revision'];
      final chats = d['chats'];
      d.clear();
      d.addAll(copy(old));
      d['revision'] = revision;
      d['chats'] = chats;
    }, undoable: false);
    _undo = null;
    notifyListeners();
  }

  Future<void> recover() async {
    final d = jsonDecode(await backup.readAsString()) as J;
    validate(d);
    await _write(d, preserveBackup: true);
    data = d;
    error = null;
    _undo = null;
    notifyListeners();
    await syncPlatform();
  }

  Future<void> syncPlatform() async {
    if (!Platform.isAndroid) return;
    try {
      final now = DateTime.now(), events = <J>[];
      for (var i = 0; i < 8; i++) {
        events.addAll(
          timeline(
            data,
            day(now).add(Duration(days: i)),
          ).where((e) => DateTime.parse(e['end']).isAfter(now)),
        );
      }
      final reminders = data['reminders'] == true;
      final payload = {
        'events': events
            .map(
              (e) => {
                ...e,
                'startMs': DateTime.parse(e['start']).millisecondsSinceEpoch,
                'endMs': DateTime.parse(e['end']).millisecondsSinceEpoch,
              },
            )
            .toList(),
        'todos': data['todos'],
        'lead': data['reminderMinutes'],
        'enabled': reminders,
        'accent': data['accent'],
        'tableName': selected(data)['name'],
      };
      await native.invokeMethod('sync', jsonEncode(payload));
      platformIssue = null;
    } catch (e) {
      platformIssue = '系统提醒／小组件同步失败：$e';
    }
    notifyListeners();
  }
}
