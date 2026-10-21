import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yiclass/services/ai/ai_transport.dart';

void main() {
  test('normalize base URL and preserve full compatible endpoint', () {
    expect(AITransport.endpoint('https://api.example.com').path,
        '/v1/chat/completions');
    expect(AITransport.endpoint('https://api.example.com/v1/').path,
        '/v1/chat/completions');
    expect(
        AITransport.endpoint('https://api.deepseek.com/chat/completions').path,
        '/chat/completions');
    expect(() => AITransport.endpoint('http://api.example.com'),
        throwsFormatException);
    expect(() => AITransport.endpoint('https://api.example.com/?key=secret'),
        throwsFormatException);
  });
  test('UTF8 payload, authorization and UTF8 Chinese response', () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer test-key');
      expect(jsonDecode(request.body)['model'], 'test-model');
      expect(request.url.path, '/v1/chat/completions');
      return http.Response.bytes(
          utf8.encode(jsonEncode({
            'choices': [
              {
                'message': {'content': '中文课表'}
              }
            ]
          })),
          200);
    });
    expect(
        await AITransport.complete(
            url: 'https://test.example/v1',
            apiKey: 'test-key',
            body: {'model': 'test-model'},
            client: client),
        '中文课表');
    client.close();
  });
  test('error messages do not echo credential or upstream body', () async {
    final client =
        MockClient((_) async => http.Response('secret upstream body', 401));
    try {
      await AITransport.complete(
          url: 'https://test.example/v1',
          apiKey: 'secret',
          body: {},
          client: client);
      fail('Expected error');
    } catch (e) {
      expect('$e', contains('401'));
      expect('$e', isNot(contains('secret')));
    }
    client.close();
  });
  test('strict JSON and fenced JSON accepted; malformed output rejected', () {
    expect(AITransport.object('```json\n{"name":"测试"}\n```')['name'], '测试');
    expect(() => AITransport.object('说明 {"name":"测试"}'), throwsFormatException);
  });
}
