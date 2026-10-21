import 'dart:convert';
import 'package:http/http.dart' as http;

/// OpenAI Chat Completions compatible endpoints (including DeepSeek).
/// Native Anthropic/Gemini protocols are not advertised as compatible.
class AITransport {
  static Uri endpoint(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('请输入 HTTPS API 地址，不要在地址中包含密钥');
    }
    var path = uri.path.replaceAll(RegExp(r'/+$'), '');
    if (!path.endsWith('/chat/completions')) {
      path = '${path.isEmpty ? '/v1' : path}/chat/completions';
    }
    return uri.replace(path: path);
  }

  static Future<String> complete({
    required String url,
    required String apiKey,
    required Map<String, dynamic> body,
    http.Client? client,
  }) async {
    final transport = client ?? http.Client();
    final uri = endpoint(url);
    final payload = Map<String, dynamic>.from(body);
    // Flash enables high-effort reasoning by default; structured extraction
    // needs the token budget for JSON output rather than an empty final answer.
    if (uri.host == 'api.deepseek.com') {
      payload.putIfAbsent('thinking', () => {'type': 'disabled'});
    }
    try {
      final response = await transport
          .post(uri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${apiKey.trim()}',
              },
              body: jsonEncode(payload))
          .timeout(const Duration(seconds: 90));
      if (response.statusCode != 200) {
        final hint = switch (response.statusCode) {
          401 || 403 => '密钥无效或没有模型权限',
          404 => '请检查接口地址和模型名称',
          429 => '请求限流或余额不足，请稍后重试',
          _ => '服务暂时不可用',
        };
        // Never expose raw gateway bodies: they can echo credentials/inputs.
        throw Exception('AI 请求失败 (${response.statusCode})：$hint');
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final message = data['choices'][0]['message'];
      final content = message['content'];
      if (content is! String || content.trim().isEmpty) {
        throw const FormatException('AI 返回了空内容或不兼容的响应');
      }
      return content;
    } finally {
      if (client == null) transport.close();
    }
  }

  static Map<String, dynamic> object(String text) {
    var content = text.trim();
    if (content.startsWith('```')) {
      content = content
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '');
    }
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('AI 需要返回 JSON 对象');
    }
    return decoded;
  }
}
