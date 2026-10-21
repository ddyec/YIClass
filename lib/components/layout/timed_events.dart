import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/timetable.dart';
import '../../states/timetable_state.dart';

/// Events keep their real clock range instead of borrowing a lesson cell.
class TimedEvents extends StatelessWidget {
  final Timetable timetable;
  final DateTime start, end;
  const TimedEvents(
      {super.key,
      required this.timetable,
      required this.start,
      required this.end});
  @override
  Widget build(BuildContext context) {
    final events = timetable.events
        .where((e) =>
            DateTime.parse(e['start']).isBefore(end) &&
            DateTime.parse(e['end']).isAfter(start))
        .toList()
      ..sort((a, b) => (a['start'] as String).compareTo(b['start']));
    if (events.isEmpty) return const SizedBox.shrink();
    final format = DateFormat('MM/dd HH:mm');
    return Container(
        color: Colors.white,
        constraints: const BoxConstraints(maxHeight: 160),
        child: SingleChildScrollView(
            child: Column(children: [
          for (final e in events)
            ListTile(
                dense: true,
                leading: const Icon(Icons.event_outlined, color: Colors.black),
                title: Text(e['name']),
                subtitle: Text(
                    '${format.format(DateTime.parse(e['start']))}–${format.format(DateTime.parse(e['end']))}${(e['location'] ?? '').isEmpty ? '' : ' · ${e['location']}'}'),
                trailing: IconButton(
                    tooltip: '删除事件',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                                  title: Text('删除 ${e['name']}？'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('取消')),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('删除',
                                            style:
                                                TextStyle(color: Colors.black)))
                                  ]));
                      if (ok != true || !context.mounted) return;
                      final state = context.read<TimetableState>();
                      final current = state.current;
                      if (current == null || current.id != timetable.id) return;
                      current.events = current.events
                          .where((v) => v['id'] != e['id'])
                          .toList();
                      await state.put(current);
                    })),
        ])));
  }
}
