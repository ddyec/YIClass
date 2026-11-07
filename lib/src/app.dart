import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
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
  bool collapsed = false;
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

  static const icons = [
    CupertinoIcons.calendar,
    CupertinoIcons.list_bullet,
    CupertinoIcons.slider_horizontal_3,
  ];
  @override
  Widget build(BuildContext context) {
    final s = widget.store,
        dark = Theme.of(context).brightness == Brightness.dark;
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
      extendBody: true,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: s.data['gradient'] == true
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? [const Color(0xff151b29), const Color(0xff14191f)]
                      : [const Color(0xffeef3ff), const Color(0xfff3f6f5)],
                )
              : null,
        ),
        child: SafeArea(
          bottom: false,
          child: NotificationListener<UserScrollNotification>(
            onNotification: (n) {
              final next = n.direction == ScrollDirection.reverse;
              if (n.direction != ScrollDirection.idle && next != collapsed) {
                setState(() => collapsed = next);
              }
              return false;
            },
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
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                heightFactor: 1,
                child: LayoutBuilder(
                  builder: (c, box) => navigation(c, box.maxWidth),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAction(
              label: 'AI 助手',
              size: 60,
              onTap: () => showChat(context, s),
              child: const AssistantMark(size: 31),
            ),
          ],
        ),
      ),
    );
  }

  Widget navigation(BuildContext context, double available) {
    final dark = Theme.of(context).brightness == Brightness.dark,
        accent = Color(widget.store.data['accent']);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: 60,
      width: collapsed ? 60 : available,
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xff262d36).withValues(alpha: .96)
            : const Color(0xfff7f9fa).withValues(alpha: .94),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: dark ? Colors.white12 : Colors.white,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 1,
            spreadRadius: 1,
          ),
        ],
      ),
      child: collapsed
          ? IconButton(
              tooltip: '展开导航',
              onPressed: () => setState(() => collapsed = false),
              icon: Icon(icons[page], color: accent, size: 25),
            )
          : Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                children: List.generate(
                  3,
                  (i) => Expanded(child: navigationItem(context, i)),
                ),
              ),
            ),
    );
  }

  Widget navigationItem(BuildContext context, int i) {
    final dark = Theme.of(context).brightness == Brightness.dark,
        accent = Color(widget.store.data['accent']);
    final foreground = page == i
        ? accent
        : Theme.of(context).colorScheme.onSurface;
    return Semantics(
      selected: page == i,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: () => setState(() => page = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: page == i
                  ? (dark
                        ? Colors.white.withValues(alpha: .09)
                        : const Color(0xffe5e9ed))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icons[i], size: 25, color: foreground),
                const SizedBox(height: 1),
                Text(
                  ['课表', '待办', '设置'][i],
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: foreground,
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

class CircleAction extends StatelessWidget {
  const CircleAction({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.size = 44,
  });
  final String label;
  final VoidCallback onTap;
  final Widget child;
  final double size;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: label,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: dark
              ? Colors.white.withValues(alpha: .04)
              : Colors.white.withValues(alpha: .28),
          border: Border.all(
            color: dark ? Colors.white12 : const Color(0xffd9dfe5),
            width: .7,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .035),
              blurRadius: 7,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(child: child),
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
        accent = Color(data['accent']);
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              CircleAction(
                label: '切换课表',
                onTap: tables,
                child: Icon(
                  CupertinoIcons.square_stack,
                  color: accent,
                  size: 25,
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: tables,
                  onLongPress: () => showActions(),
                  child: Text(
                    table['name'],
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              CircleAction(
                label: '添加课程',
                onTap: () => editCourse(context, widget.store),
                child: Icon(CupertinoIcons.plus, color: accent, size: 28),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: '上一${mode == 0 ? '周' : '天'}',
                  onPressed: () => setState(
                    () =>
                        date = date.subtract(Duration(days: mode == 0 ? 7 : 1)),
                  ),
                  icon: Icon(
                    CupertinoIcons.chevron_left,
                    color: accent,
                    size: 21,
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final v = await pickDate(context, date);
                      if (v != null) setState(() => date = v);
                    },
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: mode == 0
                                ? (week < 1
                                      ? '学期未开始'
                                      : week > table['totalWeeks']
                                      ? '学期已结束'
                                      : '第 $week 周')
                                : '${date.month}月${date.day}日',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                          if (mode == 0)
                            TextSpan(
                              text: '  ${monday.month}月${monday.day}日',
                              style: TextStyle(
                                fontSize: 12,
                                color: accent.withValues(alpha: .48),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => date = day(DateTime.now())),
                  child: Text(
                    mode == 0 ? '本周' : '本日',
                    style: TextStyle(fontSize: 14, color: accent),
                  ),
                ),
                IconButton(
                  tooltip: '下一${mode == 0 ? '周' : '天'}',
                  onPressed: () => setState(
                    () => date = date.add(Duration(days: mode == 0 ? 7 : 1)),
                  ),
                  icon: Icon(
                    CupertinoIcons.chevron_right,
                    color: accent,
                    size: 21,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
          child: Container(
            height: 32,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white10
                  : const Color(0xffdfe3eb),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: List.generate(
                3,
                (i) => Expanded(
                  child: Semantics(
                    selected: mode == i,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => setState(() => mode = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: mode == i
                                ? (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xff47505c)
                                      : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            ['周', '日', '列表'][i],
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
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

  Widget weekGrid() => LayoutBuilder(
    builder: (context, box) {
      final periods = objects(data['timeProfile']['periods']),
          counts = numbers(data['timeProfile']['sessionCounts']);
      final daytime = counts[0] + counts[1],
          visible = evening ? periods.length : daytime,
          days = selected(data)['showWeekend'] == true ? 7 : 5;
      final monday = date.subtract(Duration(days: date.weekday - 1)),
          accent = Color(data['accent']),
          dark = Theme.of(context).brightness == Brightness.dark;
      final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
      const header = 74.0, footer = 44.0, bottom = 92.0, lunch = 22.0;
      final row =
          ((box.maxHeight - header - footer - bottom - lunch) /
                  (daytime == 0 ? 1 : daytime))
              .clamp(36.0, 82.0) *
          scale;
      const rail = 44.0;
      final width = (box.maxWidth - rail) / days;
      double top(int i) =>
          i * row +
          (counts[0] > 0 && i >= counts[0] ? lunch : 0) +
          (daytime > 0 && i >= daytime ? lunch : 0);
      final height =
          visible * row +
          (counts[0] > 0 && visible > counts[0] ? lunch : 0) +
          (daytime > 0 && visible > daytime ? lunch : 0);
      final events = List.generate(
        days,
        (i) => lessons(data, monday.add(Duration(days: i))),
      );
      final hasNight = events
          .expand((e) => e)
          .any((e) => numbers(e['periods']).any((n) => n > daytime));
      final subtle = Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: .42);
      return Column(
        children: [
          SizedBox(
            height: header,
            child: Row(
              children: [
                SizedBox(
                  width: rail,
                  child: Center(
                    child: Text(
                      '节次',
                      style: TextStyle(fontSize: 10, color: subtle),
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
                          style: TextStyle(fontSize: 11, color: subtle),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: today ? accent : Colors.transparent,
                          ),
                          child: Text(
                            '${d.day}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1,
                              color: today
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: bottom),
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
                              color: dateText(d) == dateText(DateTime.now())
                                  ? accent.withValues(
                                      alpha: dark ? 0.035 : 0.02,
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
                            height: row,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).dividerColor.withValues(alpha: .035),
                                    width: .5,
                                  ),
                                ),
                              ),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: SizedBox(
                                  width: rail,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.topCenter,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${i + 1}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              height: 1.2,
                                              fontWeight: FontWeight.w500,
                                              color: subtle,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            clock(periods[i]['start']),
                                            style: TextStyle(
                                              fontSize: 10,
                                              height: 1.2,
                                              color: subtle,
                                            ),
                                          ),
                                          Text(
                                            clock(periods[i]['end']),
                                            style: TextStyle(
                                              fontSize: 10,
                                              height: 1.2,
                                              color: subtle.withValues(
                                                alpha: .3,
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
                                row,
                                width,
                                visible,
                                top,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (counts[2] > 0)
                    SizedBox(
                      height: footer,
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () => setState(() => evening = !evening),
                          icon: Icon(
                            CupertinoIcons.moon,
                            size: 17,
                            color: accent,
                          ),
                          label: Text(
                            evening
                                ? '收起晚间'
                                : hasNight
                                ? '晚间有课 · 展开'
                                : '晚间无课 · 展开',
                            style: TextStyle(
                              color: accent,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
  List<Widget> weekCards(
    List<J> events,
    double row,
    double width,
    int visible,
    double Function(int) top,
  ) {
    final result = <Widget>[],
        dark = Theme.of(context).brightness == Brightness.dark;
    for (final e in lanes(events)) {
      final ps = numbers(e['periods']);
      if (ps.first > visible) continue;
      final last = ps.last.clamp(1, visible),
          laneWidth = width / (e['lanes'] as int),
          color = Color(e['color']);
      final height = top(last - 1) + row - top(ps.first - 1) - 8;
      final course = objects(
        selected(data)['courses'],
      ).firstWhere((c) => c['id'] == e['sourceID']);
      final lines = height >= 100
          ? 3
          : height >= 64
          ? 2
          : 1;
      result.add(
        Positioned(
          top: top(ps.first - 1) + 3,
          left: laneWidth * e['lane'] + 2,
          width: laneWidth - 4,
          height: height,
          child: Semantics(
            label: '${e['title']} ${course['location']}',
            button: true,
            child: Material(
              color: color.withValues(alpha: dark ? 0.24 : 0.16),
              borderRadius: BorderRadius.circular(9),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => openItem(e),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: (laneWidth - 8) * .78,
                        height: 2.7,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 5, 3, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e['title'],
                            maxLines: lines,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.18,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: Text(
                              course['location'],
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.2,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: .48),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
    final items = timeline(data, date),
        startDay = day(date),
        endDay = DateTime(date.year, date.month, date.day + 1);
    final clipped = items.map((e) {
      final v = copy(e);
      if (DateTime.parse(v['start']).isBefore(startDay)) {
        v['start'] = startDay.toIso8601String();
      }
      if (DateTime.parse(v['end']).isAfter(endDay)) {
        v['end'] = at(date, 1439).toIso8601String();
      }
      return v;
    }).toList();
    final allocated = lanes(clipped);
    final now = DateTime.now();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...objects(data['todos'])
              .where(
                (t) =>
                    t['deadline'] != null &&
                    dateText(DateTime.parse(t['deadline'])) == dateText(date),
              )
              .map(
                (t) => Card(
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.flag_outlined),
                    title: Text('今日截止 · ${t['title']}'),
                    onTap: () => editTodo(context, widget.store, t),
                  ),
                ),
              ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('今天还没有安排，添加课程或把待办安排到日程。'),
            ),
          LayoutBuilder(
            builder: (context, box) {
              const unit = 1.1;
              const left = 48.0;
              final available = box.maxWidth - left;
              return SizedBox(
                height: 1440 * unit,
                child: Stack(
                  children: [
                    ...List.generate(
                      24,
                      (h) => Positioned(
                        top: h * 60 * unit,
                        left: 0,
                        right: 0,
                        child: Row(
                          children: [
                            SizedBox(
                              width: left,
                              child: Text(
                                '${h.toString().padLeft(2, '0')}:00',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Theme.of(
                                  context,
                                ).dividerColor.withValues(alpha: .16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ...allocated.map((e) {
                      final a = minute(DateTime.parse(e['start'])),
                          b = minute(DateTime.parse(e['end']));
                      final width = available / e['lanes'];
                      return Positioned(
                        top: a * unit,
                        left: left + e['lane'] * width + 2,
                        width: width - 4,
                        height: ((b - a) < 35 ? 35 : b - a) * unit,
                        child: Material(
                          color: Color(e['color']).withValues(alpha: .2),
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => openItem(e),
                            child: Padding(
                              padding: const EdgeInsets.all(7),
                              child: Text(
                                '${e['title']}\n${clock(a)}–${clock(b)}  ${e['subtitle']}',
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    if (dateText(now) == dateText(date))
                      Positioned(
                        top: minute(now) * unit,
                        left: left,
                        right: 0,
                        child: Container(
                          height: 1.5,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget courseList() {
    final courses = objects(selected(data)['courses']),
        unplanned = courses
            .where((c) => objects(c['schedules']).isEmpty)
            .toList();
    final events = lessons(data, date);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
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
      return Card(
        color: color.withValues(alpha: .14),
        child: ListTile(
          onTap: () => editTodo(context, widget.store, t),
          leading: Checkbox(
            value: t['completedAt'] != null,
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
            '${urgency(t, now)}${t['importance'] == 'high' ? ' · 重要' : ''}${t['deadline'] == null ? '' : ' · ${dateText(DateTime.parse(t['deadline']))} ${clock(minute(DateTime.parse(t['deadline'])))}'}',
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '待办',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
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
              IconButton(
                tooltip: '添加待办',
                onPressed: () => editTodo(context, widget.store),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Text(
                  '待完成',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
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
