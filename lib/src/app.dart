import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'model.dart';
import 'store.dart';
import 'editors.dart';
import 'settings.dart';
import 'chat.dart';

class AssistantMark extends StatelessWidget {
  const AssistantMark({super.key, this.size = 28});
  final double size;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icon/assistant.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(
      Theme.of(context).colorScheme.onSurface,
      BlendMode.srcIn,
    ),
  );
}

class Home extends StatefulWidget {
  const Home({super.key, required this.store});
  final Store store;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  int page = 0;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.syncPlatform();
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
      widget.store.syncPlatform();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      widget.store.syncPlatform();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store, colors = Theme.of(context).colorScheme;
    if (s.error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('恢复资料')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              SelectableText(s.error!),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => attempt(context, s.recover),
                child: const Text('恢复上一版备份'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: s.data['gradient'] == true
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [colors.surfaceContainerLow, colors.surface],
                )
              : null,
        ),
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: page,
            children: [
              SchedulePage(store: s),
              TodosPage(store: s),
              SettingsPage(store: s),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Material(
        color: colors.surfaceContainerLow,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                Expanded(
                  child: NavigationBar(
                    height: 64,
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    selectedIndex: page,
                    indicatorColor: colors.secondaryContainer,
                    onDestinationSelected: (v) => setState(() => page = v),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.calendar_month_outlined),
                        selectedIcon: Icon(Icons.calendar_month),
                        label: '课表',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.checklist_outlined),
                        selectedIcon: Icon(Icons.checklist),
                        label: '待办',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.tune_outlined),
                        selectedIcon: Icon(Icons.tune),
                        label: '设置',
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 28,
                  child: VerticalDivider(
                    width: 1,
                    color: colors.outlineVariant,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: IconButton.outlined(
                    tooltip: 'AI 助手',
                    onPressed: () => showChat(context, s),
                    icon: const AssistantMark(size: 25),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void showChat(BuildContext context, Store store) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  builder: (_) =>
      FractionallySizedBox(heightFactor: .96, child: ChatPage(store: store)),
);
void editCourse(BuildContext c, Store s, [J? course]) => Navigator.push(
  c,
  MaterialPageRoute<void>(
    builder: (_) => CourseEditor(store: s, course: course),
  ),
);
void editTodo(BuildContext c, Store s, [J? todo]) => Navigator.push(
  c,
  MaterialPageRoute<void>(
    builder: (_) => TodoEditor(store: s, todo: todo),
  ),
);

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key, required this.store});
  final Store store;
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  DateTime date = day(DateTime.now());
  int mode = 0;
  bool evening = false;
  J get data => widget.store.data;
  Future<void> tables() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => ListenableBuilder(
        listenable: widget.store,
        builder: (c, _) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              const ListTile(
                title: Text(
                  '我的课表',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              ...objects(data['timetables']).map(
                (t) => ListTile(
                  leading: Icon(
                    t['id'] == data['selectedID']
                        ? Icons.check_circle
                        : Icons.calendar_today_outlined,
                  ),
                  title: Text(t['name']),
                  onTap: () => attempt(c, () async {
                    await widget.store.commit((d) => d['selectedID'] = t['id']);
                    if (c.mounted) Navigator.pop(c);
                  }),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'rename') {
                        final n = await ask(c, '课表名称', initial: t['name']);
                        if (n != null && c.mounted) {
                          await attempt(
                            c,
                            () => widget.store.commit(
                              (d) => (d['timetables'] as List).firstWhere(
                                (x) => x['id'] == t['id'],
                              )['name'] = n,
                            ),
                          );
                        }
                      } else if (await confirm(
                        c,
                        '删除课表',
                        '将删除该课表，保留共用待办，可撤销。',
                      )) {
                        if (c.mounted) {
                          await attempt(
                            c,
                            () => widget.store.commit((d) {
                              require(
                                (d['timetables'] as List).length > 1,
                                '至少保留一份课表',
                              );
                              (d['timetables'] as List).removeWhere(
                                (x) => x['id'] == t['id'],
                              );
                              if (d['selectedID'] == t['id']) {
                                d['selectedID'] = d['timetables'][0]['id'];
                              }
                            }),
                          );
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'rename', child: Text('重命名')),
                      PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('新建课表'),
                onTap: () async {
                  final n = await ask(c, '新课表名称');
                  if (n != null && c.mounted) {
                    await attempt(
                      c,
                      () => widget.store.commit((d) {
                        final t = newTable(
                          name: n,
                          start: DateTime.parse(selected(d)['startDate']),
                        );
                        t['totalWeeks'] = selected(d)['totalWeeks'];
                        (d['timetables'] as List).add(t);
                        d['selectedID'] = t['id'];
                      }),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void openItem(J item) {
    if (item['kind'] == 'todo') {
      editTodo(
        context,
        widget.store,
        objects(data['todos']).firstWhere((t) => t['id'] == item['sourceID']),
      );
    } else {
      editCourse(
        context,
        widget.store,
        objects(
          selected(data)['courses'],
        ).firstWhere((t) => t['id'] == item['sourceID']),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final table = selected(data),
        week = weekFor(table, date),
        colors = Theme.of(context).colorScheme;
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 2),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: tables,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              table['name'],
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.expand_more,
                            size: 20,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => date = day(DateTime.now())),
                  child: Text(mode == 0 ? '本周' : '本日'),
                ),
                IconButton.filled(
                  tooltip: '添加课程',
                  onPressed: () => editCourse(context, widget.store),
                  icon: const Icon(Icons.add),
                ),
                IconButton(
                  tooltip: '更多课表操作',
                  onPressed: showActions,
                  icon: const Icon(Icons.more_vert),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 12, 6),
          child: Row(
            children: [
              IconButton(
                tooltip: '上一${mode == 0 ? '周' : '天'}',
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(
                  () => date = date.subtract(Duration(days: mode == 0 ? 7 : 1)),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                  ),
                  onPressed: () async {
                    final v = await pickDate(context, date);
                    if (v != null) setState(() => date = v);
                  },
                  child: Text(
                    mode == 0
                        ? (MediaQuery.sizeOf(context).width < 360
                              ? '第 $week 周'
                              : '第 $week 周 · ${monday.month}/${monday.day}')
                        : '${date.month}月${date.day}日',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: '下一${mode == 0 ? '周' : '天'}',
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(
                  () => date = date.add(Duration(days: mode == 0 ? 7 : 1)),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 34,
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('周')),
                    ButtonSegment(value: 1, label: Text('日')),
                    ButtonSegment(value: 2, label: Text('列表')),
                  ],
                  selected: {mode},
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    side: const WidgetStatePropertyAll(BorderSide.none),
                    minimumSize: const WidgetStatePropertyAll(Size(36, 34)),
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? colors.primaryContainer
                          : colors.surfaceContainerHigh,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? colors.onPrimaryContainer
                          : colors.onSurfaceVariant,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 10),
                    ),
                    textStyle: const WidgetStatePropertyAll(
                      TextStyle(
                        fontFamily: 'NotoSansSC',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  onSelectionChanged: (v) => setState(() => mode = v.first),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: mode == 0
              ? weekGrid()
              : mode == 1
              ? dayTimeline()
              : courseList(),
        ),
      ],
    );
  }

  Future<void> showActions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('切换所选日期停课'),
              onTap: () {
                Navigator.pop(c);
                attempt(
                  context,
                  () => widget.store.commit((d) {
                    final t = (d['timetables'] as List).firstWhere(
                      (t) => t['id'] == d['selectedID'],
                    );
                    final holidays = t['holidays'] as List;
                    final value = dateText(date);
                    if (holidays.contains(value)) {
                      holidays.remove(value);
                    } else {
                      holidays.add(value);
                    }
                  }),
                );
              },
            ),
            if (widget.store.canUndo)
              ListTile(
                title: const Text('撤销上次修改'),
                onTap: () {
                  Navigator.pop(c);
                  attempt(context, widget.store.undo);
                },
              ),
          ],
        ),
      ),
    );
  }

  TextStyle get courseTitleStyle => Theme.of(context).textTheme.bodyMedium!
      .copyWith(fontSize: 11.5, height: 1.2, fontWeight: FontWeight.w600);
  TextStyle get coursePlaceStyle =>
      Theme.of(context).textTheme.bodyMedium!.copyWith(
        fontSize: 10.5,
        height: 1.2,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
  double textHeight(
    String text,
    TextStyle style,
    double width, {
    int? maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '…',
    )..layout(maxWidth: width);
    return painter.height;
  }

  Widget weekGrid() => LayoutBuilder(
    builder: (context, box) {
      final periods = objects(data['timeProfile']['periods']),
          counts = numbers(data['timeProfile']['sessionCounts']);
      final daytime = counts[0] + counts[1],
          visible = evening ? periods.length : daytime,
          days = selected(data)['showWeekend'] == true ? 7 : 5;
      final monday = date.subtract(Duration(days: date.weekday - 1)),
          colors = Theme.of(context).colorScheme;
      final scaler = MediaQuery.textScalerOf(context), scale = scaler.scale(1);
      const header = 56.0, footer = 38.0, lunch = 16.0, rail = 42.0;
      final events = List.generate(
        days,
        (i) => lanes(lessons(data, monday.add(Duration(days: i)))),
      );
      var maxLanes = 1;
      for (final e in events.expand((e) => e)) {
        if (e['lanes'] > maxLanes) maxLanes = e['lanes'];
      }
      // Keep labels legible when days or overlapping courses need more width.
      final minimumDay = 49.0 * maxLanes * scale.clamp(1.0, 1.5);
      final gridWidth = (rail + minimumDay * days).clamp(
            box.maxWidth,
            double.infinity,
          ),
          width = (gridWidth - rail) / days;
      final baseRow =
          ((box.maxHeight - header - footer - lunch) /
                  (daytime == 0 ? 1 : daytime))
              .clamp(44.0, 90.0) *
          scale.clamp(1.0, 1.5);
      final heights = List<double>.filled(periods.length, baseRow);
      double gapBefore(int i) =>
          (counts[0] > 0 && i == counts[0] ? lunch : 0) +
          (daytime > 0 && i == daytime ? lunch : 0);
      double top(int i) {
        var v = 0.0;
        for (var n = 0; n < i; n++) {
          v += heights[n];
        }
        for (var n = 1; n <= i; n++) {
          v += gapBefore(n);
        }
        return v;
      }

      for (final e in events.expand((e) => e)) {
        final ps = numbers(e['periods']);
        final course = objects(
          selected(data)['courses'],
        ).firstWhere((c) => c['id'] == e['sourceID']);
        final usable = (width / (e['lanes'] as int) - 14).clamp(
          16.0,
          double.infinity,
        );
        final location = course['location'].toString().replaceAll('_', ' ');
        // A recognisable title gets up to four lines; the room keeps its own full area.
        final needed =
            textHeight(e['title'], courseTitleStyle, usable, maxLines: 4) +
            (location.isEmpty
                ? 0
                : 5 + textHeight(location, coursePlaceStyle, usable)) +
            24;
        final existing =
            top(ps.last - 1) + heights[ps.last - 1] - top(ps.first - 1) - 6;
        if (needed > existing) {
          final extra = (needed - existing) / ps.length;
          for (final n in ps) {
            heights[n - 1] += extra;
          }
        }
      }
      final height = visible == 0
          ? 0.0
          : top(visible - 1) + heights[visible - 1];
      final hasNight = events
          .expand((e) => e)
          .any((e) => numbers(e['periods']).any((n) => n > daytime));
      Widget nightButton() => SizedBox(
        height: footer,
        child: Center(
          child: TextButton.icon(
            onPressed: () => setState(() => evening = !evening),
            icon: const Icon(Icons.bedtime_outlined, size: 17),
            label: Text(
              evening
                  ? '收起晚间'
                  : hasNight
                  ? '晚间有课 · 展开'
                  : '晚间无课 · 展开',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
      );
      Widget heading() => SizedBox(
        height: header,
        child: Row(
          children: [
            SizedBox(
              width: rail,
              child: Center(
                child: Text(
                  '节次',
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            ...List.generate(days, (i) {
              final d = monday.add(Duration(days: i)),
                  today = dateText(d) == dateText(DateTime.now());
              return SizedBox(
                width: width,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '周${'一二三四五六日'[i]}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(today ? 10 : 14),
                        color: today ? colors.primary : Colors.transparent,
                      ),
                      child: Text(
                        '${d.day}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1,
                          color: today ? colors.onPrimary : colors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );
      return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: gridWidth,
                child: Column(
                  children: [
                    heading(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          children: [
                            SizedBox(
                              height: height,
                              child: Stack(
                                children: [
                                  ...List.generate(days, (i) {
                                    final d = monday.add(Duration(days: i));
                                    return Positioned(
                                      left: rail + i * width,
                                      top: 0,
                                      bottom: 0,
                                      width: width,
                                      child: ColoredBox(
                                        color:
                                            dateText(d) ==
                                                dateText(DateTime.now())
                                            ? colors.primary.withValues(
                                                alpha: .035,
                                              )
                                            : Colors.transparent,
                                      ),
                                    );
                                  }),
                                  ...List.generate(
                                    visible,
                                    (i) => Positioned(
                                      top: top(i),
                                      left: 0,
                                      right: 0,
                                      height: heights[i],
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          border: Border(
                                            top: BorderSide(
                                              color: colors.outlineVariant
                                                  .withValues(alpha: .35),
                                              width: .5,
                                            ),
                                          ),
                                        ),
                                        child: Align(
                                          alignment: Alignment.topLeft,
                                          child: SizedBox(
                                            width: rail,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                top: 7,
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    '${i + 1}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      height: 1.1,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: colors
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    clock(periods[i]['start']),
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      height: 1.15,
                                                      color: colors
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                                  Text(
                                                    clock(periods[i]['end']),
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      height: 1.15,
                                                      color: colors
                                                          .onSurfaceVariant
                                                          .withValues(
                                                            alpha: .7,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  ...List.generate(
                                    days,
                                    (i) => Positioned(
                                      top: 0,
                                      left: rail + i * width,
                                      width: width,
                                      height: height,
                                      child: Stack(
                                        children: weekCards(
                                          events[i],
                                          width,
                                          visible,
                                          top,
                                          heights,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (evening && counts[2] > 0) nightButton(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!evening && counts[2] > 0) nightButton(),
        ],
      );
    },
  );
  List<Widget> weekCards(
    List<J> events,
    double width,
    int visible,
    double Function(int) top,
    List<double> heights,
  ) {
    final result = <Widget>[],
        colors = Theme.of(context).colorScheme,
        dark = Theme.of(context).brightness == Brightness.dark;
    for (final e in events) {
      final ps = numbers(e['periods']);
      if (ps.first > visible) continue;
      final last = ps.last.clamp(1, visible),
          laneWidth = width / (e['lanes'] as int),
          color = Color(e['color']);
      final height = top(last - 1) + heights[last - 1] - top(ps.first - 1) - 6;
      final course = objects(
        selected(data)['courses'],
      ).firstWhere((c) => c['id'] == e['sourceID']);
      result.add(
        Positioned(
          top: top(ps.first - 1) + 3,
          left: laneWidth * e['lane'] + 2,
          width: laneWidth - 4,
          height: height,
          child: Semantics(
            label: '${e['title']} ${course['location']}',
            button: true,
            child: Tooltip(
              message: '${e['title']}\n${course['location']}',
              child: Material(
                key: ValueKey('course-card-${e['id']}'),
                color: Color.alphaBlend(
                  color.withValues(alpha: dark ? 0.22 : 0.105),
                  colors.surface,
                ),
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => openItem(e),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(5, 6, 5, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 18,
                          height: 3,
                          margin: const EdgeInsets.only(bottom: 3),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Text(
                          e['title'],
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: courseTitleStyle,
                        ),
                        if ((course['location'] as String).isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            course['location'].toString().replaceAll('_', ' '),
                            key: ValueKey('course-location-${e['id']}'),
                            style: coursePlaceStyle,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return result;
  }

  Widget dayTimeline() {
    final items = timeline(data, date), colors = Theme.of(context).colorScheme;
    final groups = <List<J>>[];
    DateTime? lastEnd;
    for (final item in items) {
      final start = DateTime.parse(item['start']),
          end = DateTime.parse(item['end']);
      if (lastEnd == null || !start.isBefore(lastEnd)) {
        groups.add([]);
        lastEnd = end;
      } else if (end.isAfter(lastEnd)) {
        lastEnd = end;
      }
      groups.last.add(item);
    }
    Widget itemCard(J e) {
      final a = DateTime.parse(e['start']),
          b = DateTime.parse(e['end']),
          color = Color(e['color']);
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: Color.alphaBlend(color.withValues(alpha: .11), colors.surface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => openItem(e),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      e['kind'] == 'course'
                          ? Icons.school_outlined
                          : Icons.task_alt,
                      size: 17,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${clock(minute(a))}–${clock(minute(b))}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  e['title'],
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (e['subtitle'].toString().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    e['subtitle'],
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        ...objects(data['todos'])
            .where(
              (t) =>
                  t['deadline'] != null &&
                  dateText(DateTime.parse(t['deadline'])) == dateText(date),
            )
            .map(
              (t) => Card(
                color: colors.tertiaryContainer,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(t['title']),
                  subtitle: Text(
                    '今日 ${clock(minute(DateTime.parse(t['deadline'])))} 截止',
                  ),
                  onTap: () => editTodo(context, widget.store, t),
                ),
              ),
            ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: [
                Icon(
                  Icons.event_available_outlined,
                  size: 36,
                  color: colors.primary,
                ),
                const SizedBox(height: 12),
                const Text('今天没有安排'),
                TextButton(
                  onPressed: () => editTodo(context, widget.store),
                  child: const Text('安排一项待办'),
                ),
              ],
            ),
          ),
        ...groups.map((group) {
          final allocated = lanes(group),
              columns = allocated.first['lanes'] as int;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        clock(minute(DateTime.parse(group.first['start']))),
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final width = (columns * 136.0).clamp(
                        box.maxWidth,
                        double.infinity,
                      );
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: width,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List.generate(
                              columns,
                              (lane) => Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: lane == 0 ? 0 : 6,
                                  ),
                                  child: Column(
                                    children: allocated
                                        .where((e) => e['lane'] == lane)
                                        .map(itemCard)
                                        .toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget courseList() {
    final courses = objects(selected(data)['courses']),
        unplanned = courses
            .where((c) => objects(c['schedules']).isEmpty)
            .toList();
    final events = lessons(data, date);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (events.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: Text('当天没有课程')),
        ...events.map(
          (e) => Card(
            child: ListTile(
              onTap: () => openItem(e),
              leading: Container(
                width: 5,
                height: 44,
                decoration: BoxDecoration(
                  color: Color(e['color']),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              title: Text(e['title']),
              subtitle: Text(
                '${clock(minute(DateTime.parse(e['start'])))}–${clock(minute(DateTime.parse(e['end'])))}\n${e['subtitle']}',
              ),
              isThreeLine: true,
            ),
          ),
        ),
        ExpansionTile(
          title: const Text('全部课程'),
          children: courses
              .where((c) => objects(c['schedules']).isNotEmpty)
              .map(
                (c) => ListTile(
                  title: Text(c['name']),
                  subtitle: Text('${c['location']} · ${c['teacher']}'),
                  onTap: () => editCourse(context, widget.store, c),
                ),
              )
              .toList(),
        ),
        if (unplanned.isNotEmpty)
          ExpansionTile(
            title: const Text('其他课程'),
            children: unplanned
                .map(
                  (c) => ListTile(
                    title: Text(c['name']),
                    subtitle: Text('${c['location']} · ${c['teacher']}'),
                    onTap: () => editCourse(context, widget.store, c),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class TodosPage extends StatefulWidget {
  const TodosPage({super.key, required this.store});
  final Store store;
  @override
  State<TodosPage> createState() => _TodosPageState();
}

class _TodosPageState extends State<TodosPage> {
  DateTime date = day(DateTime.now());
  @override
  Widget build(BuildContext context) {
    final all = objects(widget.store.data['todos']), now = DateTime.now();
    final pending =
        all
            .where(
              (t) =>
                  t['completedAt'] == null &&
                  !day(DateTime.parse(t['createdAt'])).isAfter(date),
            )
            .toList()
          ..sort((a, b) {
            final ranked = score(b, now).compareTo(score(a, now));
            return ranked != 0
                ? ranked
                : (a['deadline'] ?? '9999').compareTo(b['deadline'] ?? '9999');
          });
    final completed = all.where((t) => t['completedAt'] != null).toList();
    Widget card(J t) {
      final color = Color(urgencyColor(t, now));
      final due = t['deadline'] == null ? null : DateTime.parse(t['deadline']);
      final dueLabel = due == null
          ? ''
          : dateText(due) == dateText(now)
          ? clock(minute(due))
          : '${due.month}/${due.day} ${clock(minute(due))}';
      return Card(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: .7,
          ),
        ),
        child: ListTile(
          onTap: () => editTodo(context, widget.store, t),
          leading: Checkbox(
            value: t['completedAt'] != null,
            side: BorderSide(color: color, width: 1.6),
            onChanged: (v) => attempt(
              context,
              () => widget.store.commit((d) {
                (d['todos'] as List).firstWhere(
                  (x) => x['id'] == t['id'],
                )['completedAt'] = v == true
                    ? DateTime.now().toIso8601String()
                    : null;
              }),
            ),
          ),
          title: Text(
            t['title'],
            style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: t['completedAt'] == null
                  ? null
                  : TextDecoration.lineThrough,
            ),
          ),
          subtitle: Text(
            '${urgency(t, now)}${t['importance'] == 'high' ? ' · 重要' : ''}${dueLabel.isEmpty ? '' : ' · $dueLabel'}',
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 6),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '待办',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final v = await pickDate(context, date);
                  if (v != null) setState(() => date = v);
                },
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text('${date.month}月${date.day}日'),
              ),
              IconButton.filled(
                tooltip: '添加待办',
                onPressed: () => editTodo(context, widget.store),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Text(
                  '待完成',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              if (pending.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 36,
                    horizontal: 12,
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 36),
                      const SizedBox(height: 12),
                      const Text('把接下来要做的事记在这里'),
                      TextButton(
                        onPressed: () => editTodo(context, widget.store),
                        child: const Text('添加第一项待办'),
                      ),
                    ],
                  ),
                ),
              ...pending.map(card),
              ExpansionTile(
                title: Text('已完成 · ${completed.length}'),
                initiallyExpanded: false,
                children: completed.map(card).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
