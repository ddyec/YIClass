import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yiclass/data/timetable.dart';
import 'package:yiclass/services/file_service.dart';
import 'package:yiclass/services/ai/planning_engine.dart';
import 'package:yiclass/states/timetable_state.dart';
import 'package:yiclass/views/ai/planning_page.dart';
import 'package:yiclass/views/settings_view/time_settings_page.dart';
import 'package:yiclass/components/inputs/components.dart';
import 'planning_engine_test.dart' as f;

class StateFixture extends TimetableState {
  Timetable value = FileService.fromMap(f.fixture());
  int saves = 0;
  @override
  Timetable? get current => value;
  @override
  Future<bool> put(Timetable t) async {
    value = t;
    saves++;
    notifyListeners();
    return true;
  }
}

void main() {
  testWidgets(
    'preview applies with one tap and undo restores the original timetable',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = StateFixture();
      final edited = PlanningEngine.clone(FileService.toMap(state.value))
        ..remove('exportTime');
      edited['events'] = [
        {
          'id': 'e',
          'name': '自习',
          'location': '',
          'start': '2026-09-26T13:13:00',
          'end': '2026-09-26T14:07:00',
        },
      ];
      final proposal = {
        'summary': '已安排自习',
        'questions': [],
        'timetable': edited,
      };
      await tester.pumpWidget(
        ChangeNotifierProvider<TimetableState>.value(
          value: state,
          child: MaterialApp(
            home: PlanningPage(
              planRequest: (t, r, {imageBase64}) async => proposal,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '周六下午安排自习');
      await tester.tap(find.text('生成方案'));
      await tester.pumpAndSettle();
      expect(state.saves, 0);
      expect(find.textContaining('13:13'), findsOneWidget);
      await tester.ensureVisible(find.text('应用方案'));
      await tester.tap(find.text('应用方案'));
      await tester.pumpAndSettle();
      expect(state.saves, 1);
      expect(state.current!.events.single['start'], '2026-09-26T13:13:00');
      expect(find.byType(AlertDialog), findsNothing);
      await tester.ensureVisible(find.text('撤销上次应用'));
      await tester.tap(find.text('撤销上次应用'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(state.current!.events, isEmpty);
      expect(state.saves, 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'time settings use original controls and configurable school blocks',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider<TimetableState>.value(
          value: StateFixture(),
          child: const MaterialApp(home: TimeSettingsPage()),
        ),
      );
      expect(find.text('每日总节数'), findsOneWidget);
      expect(find.text('上午'), findsWidgets);
      expect(find.byType(YicoreSlider), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
