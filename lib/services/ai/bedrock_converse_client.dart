import 'package:dio/dio.dart';

import 'ai_provider_config.dart';
import 'llm_agent.dart';

/// [LlmAgent] backed by the AWS Bedrock **Converse** API using a bearer-token
/// (Bedrock API key) — the exact mechanism opencode uses here. No SigV4, no AWS
/// SDK. Endpoint is `<endpoint || regional default>/model/<model>/converse`
/// with `Authorization: Bearer <apiKey>`.
class BedrockConverseAgent implements LlmAgent {
  final AiConfig config;
  final Dio _dio;

  /// Safety cap on the agentic tool-call loop.
  static const int maxToolIterations = 6;

  BedrockConverseAgent(this.config, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 90),
              sendTimeout: const Duration(seconds: 30),
            ),
          );

  String get _url {
    final base = config.hasEndpoint
        ? config.endpoint!.trim().replaceAll(RegExp(r'/+$'), '')
        : 'https://bedrock-runtime.${config.region}.amazonaws.com';
    return '$base/model/${config.model}/converse';
  }

  @override
  Future<AiAnswer> run(
    String question, {
    required String systemPrompt,
    required List<ToolSpec> tools,
    List<ChatTurn> history = const [],
  }) async {
    final messages = <Map<String, dynamic>>[
      for (final turn in history)
        {
          'role': turn.role == ChatRole.user ? 'user' : 'assistant',
          'content': [
            {'text': turn.text},
          ],
        },
      {
        'role': 'user',
        'content': [
          {'text': question},
        ],
      },
    ];

    final toolsByName = {for (final t in tools) t.name: t};
    final invocations = <ToolInvocation>[];

    for (var iteration = 0; iteration < maxToolIterations; iteration++) {
      final body = <String, dynamic>{
        'system': [
          {'text': systemPrompt},
        ],
        'messages': messages,
        'inferenceConfig': {'maxTokens': 2048, 'temperature': 0},
        if (tools.isNotEmpty)
          'toolConfig': {
            'tools': [
              for (final t in tools)
                {
                  'toolSpec': {
                    'name': t.name,
                    'description': t.description,
                    'inputSchema': {'json': t.inputSchema},
                  },
                },
            ],
          },
      };

      final data = await _post(body);
      final message = (data['output']?['message']) as Map<String, dynamic>?;
      final content = (message?['content'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final stopReason = data['stopReason'] as String?;

      // Echo the assistant message back into the running transcript.
      messages.add({'role': 'assistant', 'content': content});

      if (stopReason == 'tool_use') {
        final toolResults = <Map<String, dynamic>>[];
        for (final block in content) {
          final toolUse = block['toolUse'] as Map<String, dynamic>?;
          if (toolUse == null) continue;
          final id = toolUse['toolUseId'] as String?;
          final name = toolUse['name'] as String? ?? '';
          final input = (toolUse['input'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
          final spec = toolsByName[name];
          if (spec == null) {
            invocations.add(ToolInvocation(name: name, input: input, error: 'unknown tool'));
            toolResults.add(_toolResult(id, error: 'Unknown tool: $name'));
            continue;
          }
          try {
            final result = await spec.run(input);
            invocations.add(ToolInvocation(name: name, input: input, result: result));
            toolResults.add(_toolResult(id, json: result));
          } catch (e) {
            invocations.add(ToolInvocation(name: name, input: input, error: '$e'));
            toolResults.add(_toolResult(id, error: '$e'));
          }
        }
        messages.add({'role': 'user', 'content': toolResults});
        continue;
      }

      // Terminal turn — assemble the text answer.
      final text = content.map((b) => b['text'] as String?).whereType<String>().join('\n').trim();
      return AiAnswer(text: text, toolCalls: invocations);
    }

    return AiAnswer(
      text: 'Stopped after $maxToolIterations tool calls without a final answer.',
      toolCalls: invocations,
    );
  }

  Map<String, dynamic> _toolResult(String? toolUseId, {Object? json, String? error}) => {
    'toolResult': {
      'toolUseId': ?toolUseId,
      'content': [
        if (error != null) {'text': 'Error: $error'} else {'json': json},
      ],
      'status': error != null ? 'error' : 'success',
    },
  };

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    try {
      final resp = await _dio.post<Object?>(
        _url,
        data: body,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${config.apiKey}',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.json,
        ),
      );
      final data = resp.data;
      if (data is Map) return data.cast<String, dynamic>();
      throw AiException('Unexpected response shape from the model endpoint.');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      String detail = e.message ?? 'request failed';
      if (body is Map && body['message'] is String) {
        detail = body['message'] as String;
      } else if (body is String && body.isNotEmpty) {
        detail = body;
      }
      throw AiException(detail, statusCode: status);
    }
  }
}
