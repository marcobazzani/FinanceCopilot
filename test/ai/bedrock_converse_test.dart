import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/ai/ai_provider_config.dart';
import 'package:finance_copilot/services/ai/bedrock_converse_client.dart';
import 'package:finance_copilot/services/ai/llm_agent.dart';

/// Returns queued JSON bodies in order, recording each request.
class _FakeAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> responses;
  final int status;
  final List<RequestOptions> requests = [];
  int _i = 0;

  _FakeAdapter(this.responses, {this.status = 200});

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final body = _i < responses.length ? responses[_i] : responses.last;
    _i++;
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(body)));
    return ResponseBody.fromBytes(
      bytes,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_FakeAdapter a) => Dio()..httpClientAdapter = a;

Map<String, dynamic> _textTurn(String text) => {
  'output': {
    'message': {
      'role': 'assistant',
      'content': [
        {'text': text},
      ],
    },
  },
  'stopReason': 'end_turn',
};

void main() {
  group('BedrockConverseAgent', () {
    test('runs the tool-use loop and assembles the final answer', () async {
      final adapter = _FakeAdapter([
        {
          'output': {
            'message': {
              'role': 'assistant',
              'content': [
                {
                  'toolUse': {
                    'toolUseId': 't1',
                    'name': 'query_database',
                    'input': {'sql': 'SELECT 1'},
                  },
                },
              ],
            },
          },
          'stopReason': 'tool_use',
        },
        _textTurn('You spent 25 EUR on coffee.'),
      ]);
      final config = AiConfig(provider: AiProvider.bedrock, apiKey: 'KEY', model: 'm1', region: 'eu-central-1');
      final agent = BedrockConverseAgent(config, dio: _dio(adapter));

      var toolRan = false;
      final tool = ToolSpec(
        name: 'query_database',
        description: 'q',
        inputSchema: const {'type': 'object'},
        run: (input) async {
          toolRan = true;
          expect(input['sql'], 'SELECT 1');
          return {
            'sql': input['sql'],
            'rowCount': 1,
            'rows': [
              {'n': 1},
            ],
          };
        },
      );

      final answer = await agent.run('how much on coffee', systemPrompt: 'sys', tools: [tool]);

      expect(toolRan, isTrue);
      expect(answer.text, 'You spent 25 EUR on coffee.');
      expect(answer.toolCalls.length, 1);
      expect(answer.toolCalls.first.name, 'query_database');
      expect(answer.toolCalls.first.result, isA<Map>());
      expect(adapter.requests.length, 2, reason: 'one call to request the tool, one to get the answer');
      expect(adapter.requests.first.headers['Authorization'], 'Bearer KEY');
    });

    test('resolves the regional endpoint when none is set', () async {
      final adapter = _FakeAdapter([_textTurn('ok')]);
      final config = AiConfig(
        provider: AiProvider.bedrock,
        apiKey: 'k',
        model: 'eu.anthropic.claude-sonnet-4-6',
        region: 'eu-central-1',
      );
      await BedrockConverseAgent(config, dio: _dio(adapter)).run('hi', systemPrompt: 's', tools: const []);
      expect(
        adapter.requests.first.uri.toString(),
        'https://bedrock-runtime.eu-central-1.amazonaws.com/model/eu.anthropic.claude-sonnet-4-6/converse',
      );
    });

    test('uses the custom endpoint (gateway) and appends the converse path', () async {
      final adapter = _FakeAdapter([_textTurn('ok')]);
      final config = AiConfig(
        provider: AiProvider.bedrock,
        apiKey: 'k',
        model: 'm1',
        region: 'eu-central-1',
        endpoint: 'https://gw.example.com/aws/', // trailing slash must be trimmed
      );
      await BedrockConverseAgent(config, dio: _dio(adapter)).run('hi', systemPrompt: 's', tools: const []);
      expect(adapter.requests.first.uri.toString(), 'https://gw.example.com/aws/model/m1/converse');
    });

    test('maps a provider HTTP error to AiException', () async {
      final adapter = _FakeAdapter([
        {'message': 'forbidden'},
      ], status: 403);
      final config = AiConfig(provider: AiProvider.bedrock, apiKey: 'k', model: 'm', region: 'r');
      final agent = BedrockConverseAgent(config, dio: _dio(adapter));
      await expectLater(
        () => agent.run('hi', systemPrompt: 's', tools: const []),
        throwsA(isA<AiException>()),
      );
    });
  });
}
