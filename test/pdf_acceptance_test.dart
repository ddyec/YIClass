import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:yiclass/services/ai/ai_service.dart';
import 'package:yiclass/services/ai/ai_config_service.dart';
import 'package:yiclass/services/ai/planning_engine.dart';
import 'package:yiclass/services/file_service.dart';

String name(String v) => v
    .replaceAll('Ⅱ', 'II')
    .replaceAll('Ⅰ', 'I')
    .replaceAll('（', '(')
    .replaceAll('）', ')')
    .replaceAll(RegExp(r'\s+'), '');
Set<String> slots(Map data) => {
      for (final c in data['courses'])
        for (final s in c['schedules'])
          for (final w in s['weekPattern'])
            for (final p in s['periods'])
              '${name(c['name'])}|${s['weekday']}|$w|$p'
    };
void main() {
  final root = Platform.environment['YICLASS_PDF_ACCEPTANCE_DIR'];
  final key = Platform.environment['YICLASS_TEST_API_KEY'];
  test(
      'actual PDF column import matches all manually verified weekdays, periods and weeks',
      () async {
    final dir = Directory(root!);
    final expected =
        jsonDecode(await File('${dir.path}/2026秋季课表.json').readAsString())
            as Map;
    final text = await File('${dir.path}/pdf-columns.txt').readAsString();
    final result = await AIService.analyzePdf(text,
        configuration: AIConfig(
            enabled: true,
            apiKey: key!,
            endpoint: 'https://api.deepseek.com',
            textModel: 'deepseek-flash',
            visionModel: 'deepseek-flash'));
    await File('${dir.path}/pdf-actual-result.json')
        .writeAsString(jsonEncode(result));
    final want = slots(expected), actual = slots(result);
    expect(actual.difference(want), isEmpty,
        reason: 'Unexpected weekday/period/week');
    expect(want.difference(actual), isEmpty,
        reason: 'Missing weekday/period/week');
    expect(
        result['courses']
            .where((c) => (c['schedules'] as List).isEmpty)
            .map((c) => name(c['name']))
            .toSet(),
        expected['courses']
            .where((c) => (c['schedules'] as List).isEmpty)
            .map((c) => name(c['name']))
            .toSet());
    final imported = FileService.toMap(FileService.fromMap(result));
    expect(PlanningEngine.conflicts(imported), isEmpty);
  },
      skip: root == null || key == null
          ? 'Local private PDF fixture and test API required'
          : false,
      timeout: const Timeout(Duration(minutes: 5)));
}
