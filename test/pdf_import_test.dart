import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yiclass/services/ai/ai_service.dart';
import 'package:yiclass/services/ai/ai_config_service.dart';

const config = AIConfig(
  enabled: true,
  endpoint: 'https://example.test',
  apiKey: 'test',
  textModel: 'text',
  visionModel: 'vision',
);

void main() {
  test(
    'geometry columns force weekday without mixing adjacent courses',
    () async {
      var requests = 0;
      final result = await http.runWithClient(
        () => AIService.analyzePdf(
          '[YICLASS_COLUMN weekday=2]\n普通化学实验 (3-4节)4-11周\n[/YICLASS_COLUMN]',
          configuration: config,
        ),
        () => MockClient((request) async {
          requests++;
          expect(jsonDecode(request.body)['model'], 'text');
          return _reply({
            'name': '测试',
            'courses': [
              {
                'name': '普通化学实验',
                'location': '实验室',
                'teacher': '',
                'schedules': [
                  {
                    'weekday': 1,
                    'periods': [3, 4],
                    'weekPattern': [4, 5, 6, 7, 8, 9, 10, 11],
                  },
                ],
              },
            ],
          });
        }),
      );
      expect(requests, 1);
      expect(result['courses'][0]['schedules'][0]['weekday'], 2);
    },
  );

  test(
    'unrecognized PDF layout automatically renders all pages for vision',
    () async {
      var rendered = false;
      final result = await http.runWithClient(
        () => AIService.analyzePdf(
          '星期⼀ 星期⼆ 星期三 星期四 星期五 星期六 星期⽇',
          configuration: config,
          renderPages: () async {
            rendered = true;
            return ['page1', 'page2'];
          },
        ),
        () => MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['model'], 'vision');
          final content = body['messages'][0]['content'] as List;
          expect(content.where((c) => c['type'] == 'image_url'), hasLength(2));
          return _reply({'name': '测试', 'courses': []});
        }),
      );
      expect(rendered, isTrue);
      expect(result['name'], '测试');
    },
  );
}

http.Response _reply(Map<String, dynamic> data) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'choices': [
        {
          'message': {'content': jsonEncode(data)},
        },
      ],
    }),
  ),
  200,
);
