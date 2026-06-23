import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/ai/ai_provider_config.dart';

void main() {
  group('AiConfig', () {
    test('fromMap reads all fields', () {
      final c = AiConfig.fromMap({
        AiConfig.keyProvider: 'bedrock',
        AiConfig.keyApiKey: 'secret',
        AiConfig.keyModel: 'eu.anthropic.claude-sonnet-4-6',
        AiConfig.keyRegion: 'eu-central-1',
        AiConfig.keyEndpoint: 'https://gw.example.com/aws',
      });
      expect(c.provider, AiProvider.bedrock);
      expect(c.apiKey, 'secret');
      expect(c.model, 'eu.anthropic.claude-sonnet-4-6');
      expect(c.region, 'eu-central-1');
      expect(c.endpoint, 'https://gw.example.com/aws');
      expect(c.hasEndpoint, isTrue);
      expect(c.isConfigured, isTrue);
    });

    test('blank endpoint becomes null', () {
      final c = AiConfig.fromMap({
        AiConfig.keyApiKey: 'k',
        AiConfig.keyModel: 'm',
        AiConfig.keyRegion: 'r',
        AiConfig.keyEndpoint: '   ',
      });
      expect(c.endpoint, isNull);
      expect(c.hasEndpoint, isFalse);
    });

    test('unknown provider name defaults to bedrock', () {
      expect(AiConfig.fromMap({AiConfig.keyProvider: 'nope'}).provider, AiProvider.bedrock);
      expect(AiConfig.fromMap({}).provider, AiProvider.bedrock);
    });

    test('isConfigured needs key + model + (region or endpoint)', () {
      expect(AiConfig.fromMap({}).isConfigured, isFalse);
      expect(AiConfig.fromMap({AiConfig.keyApiKey: 'k', AiConfig.keyModel: 'm'}).isConfigured, isFalse, reason: 'no region/endpoint');
      expect(
        AiConfig.fromMap({AiConfig.keyApiKey: 'k', AiConfig.keyModel: 'm', AiConfig.keyRegion: 'eu-central-1'}).isConfigured,
        isTrue,
      );
      expect(
        AiConfig.fromMap({AiConfig.keyApiKey: 'k', AiConfig.keyModel: 'm', AiConfig.keyEndpoint: 'https://x/y'}).isConfigured,
        isTrue,
        reason: 'endpoint alone satisfies the host requirement',
      );
    });
  });
}
