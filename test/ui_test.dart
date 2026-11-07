import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yiclass/main.dart';
import 'package:yiclass/src/store.dart';
import 'package:yiclass/src/model.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('NotoSansSC')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/NotoSansSC.ttf').readAsBytesSync(),
          ),
        ),
      );
    await loader.load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  Future<Store> launch(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    bool dark = false,
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory.systemTemp.createTempSync('yiclass-ui');
    addTearDown(() => dir.deleteSync(recursive: true));
    final s = Store(dir);
    s.data['theme'] = dark ? 'dark' : 'light';
    final now = DateTime.now(), table = s.data['timetables'][0];
    table['name'] = '青大';
    table['startDate'] = dateText(
      now.subtract(Duration(days: now.weekday - 1 + 63)),
    );
    final starts = [510, 565, 650, 705, 840, 895, 960, 1015, 1140, 1195];
    s.data['timeProfile']['periods'] = starts
        .asMap()
        .entries
        .map(
          (e) => {'period': e.key + 1, 'start': e.value, 'end': e.value + 45},
        )
        .toList();
    final samples = <List<dynamic>>[
      [
        '普通化学Ⅱ',
        '致明楼_507',
        1,
        [1, 2],
        0xffd36d71,
      ],
      [
        '大学英语（一）',
        '致明楼_501',
        2,
        [1, 2],
        0xffd36d71,
      ],
      [
        '生物学基础Ⅱ',
        '启真楼_503',
        3,
        [1, 2],
        0xffd36d71,
      ],
      [
        '高等数学',
        '蘭格楼_2号多媒体教室',
        5,
        [1, 2],
        0xffae65a3,
      ],
      [
        '实验室安全通识教育',
        '蘭格楼_2号多媒体教室',
        7,
        [1, 2, 3, 4],
        0xff637eea,
      ],
      [
        '普通化学实验',
        '化工学院楼（盐湖大楼）普通实验室',
        2,
        [3, 4],
        0xffb77938,
      ],
      [
        '人工智能通识',
        '致明楼二微机室',
        3,
        [3, 4],
        0xffae65a3,
      ],
      [
        '大学英语（一）',
        '致明楼_501',
        4,
        [3, 4],
        0xffd36d71,
      ],
      [
        '普通化学Ⅱ',
        '致明楼_501',
        5,
        [3, 4],
        0xffd36d71,
      ],
      [
        '高等数学',
        '蘭格楼_2号多媒体教室',
        2,
        [5, 6],
        0xffae65a3,
      ],
      [
        '大学体育（篮球1）',
        '未排地点',
        3,
        [5, 6],
        0xff298f84,
      ],
      [
        '大学语文',
        '启真楼_203',
        4,
        [5, 6],
        0xff637eea,
      ],
      [
        '习近平新时代中国特色社会主义思想概论',
        '蘭格楼_2号多媒体教室',
        5,
        [5, 6],
        0xff298f84,
      ],
      [
        '习近平新时代中国特色社会主义思想概论',
        '蘭格楼_3号多媒体教室',
        4,
        [7, 8],
        0xff298f84,
      ],
    ];
    table['courses'] = samples
        .asMap()
        .entries
        .map(
          (e) => {
            'id': 'course-${e.key}',
            'name': e.value[0],
            'location': e.value[1],
            'teacher': '',
            'color': e.value[4],
            'schedules': [
              {
                'weekday': e.value[2],
                'periods': e.value[3],
                'weekPattern': [10],
              },
            ],
          },
        )
        .toList();
    s.data['todos'] = [
      {
        'id': 't',
        'title': '完成动物生理学实验报告',
        'notes': '',
        'importance': 'high',
        'deadline': at(now, 1439).toIso8601String(),
        'createdAt': now.toIso8601String(),
        'completedAt': null,
      },
    ];
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(
          key: const Key('capture'),
          child: YIClassApp(store: s),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return s;
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('/tmp/yiclass-review').create(recursive: true);
      await File(
        '/tmp/yiclass-review/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('real pages render and course save updates timetable', (
    tester,
  ) async {
    final s = await launch(tester);
    expect(tester.takeException(), isNull);
    await capture(tester, 'schedule-light');
    await tester.tap(find.byTooltip('添加课程'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '新增课程');
    await tester.tap(find.text('保存'));
    await tester.pump();
    for (
      var i = 0;
      i < 20 &&
          !objects(selected(s.data)['courses']).any((c) => c['name'] == '新增课程');
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await capture(tester, 'after-course-save');
    expect(find.text('请设置课程安排或未排课周次'), findsNothing);
    expect(
      objects(selected(s.data)['courses']).any((c) => c['name'] == '新增课程'),
      isTrue,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .join(' | '),
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('todo calendar, collapsed completion and assistant drawer', (
    tester,
  ) async {
    await launch(tester);
    await tester.tap(find.text('待办').last);
    await tester.pumpAndSettle();
    expect(find.text('待完成'), findsOneWidget);
    await capture(tester, 'todos-light');
    await tester.tap(find.byTooltip('AI 助手'));
    await tester.pumpAndSettle();
    expect(find.text('我们应该安排什么？'), findsOneWidget);
    await capture(tester, 'assistant-light');
    await tester.tap(find.byTooltip('新对话'));
    await tester.pumpAndSettle();
    expect(find.text('我们应该安排什么？'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('small screen dark mode, day timeline and settings', (
    tester,
  ) async {
    await launch(tester, size: const Size(320, 680), dark: true);
    expect(tester.takeException(), isNull);
    await capture(tester, 'schedule-dark-small');
    await tester.tap(find.text('日'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, 'day-dark');
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();
    expect(find.text('统一课节时间'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'settings-dark');
    await tester.pumpWidget(const SizedBox());
  });
}
