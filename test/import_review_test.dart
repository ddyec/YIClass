import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yiclass/services/file_service.dart';
import 'package:yiclass/views/ai/import_review_page.dart';
import 'package:yiclass/components/inputs/components.dart';
import 'planning_engine_test.dart' as fixtures;

void main() {
  testWidgets('import review requires confirmation on a small phone viewport',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: ImportReviewPage(
            timetable: FileService.fromMap(fixtures.fixture()))));
    expect(find.text('确认导入'), findsOneWidget);
    final confirm =
        find.byWidgetPredicate((w) => w is YicoreButton && w.text == '导入为新课表');
    await tester.scrollUntilVisible(confirm, 400);
    expect(tester.widget<YicoreButton>(confirm).onPressed, isNull);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(tester.widget<YicoreButton>(confirm).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
