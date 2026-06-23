/// Configuration for the in-app AI assistant provider.
///
/// v1 supports AWS Bedrock (Converse API + bearer token), reachable directly or
/// through a gateway via the optional [endpoint] override — mirroring how
/// opencode is configured (`provider.amazon-bedrock.options.{baseURL,apiKey,region}`).
/// Stored as key/value rows in `AppConfigs`.
enum AiProvider {
  bedrock;

  static AiProvider fromName(String? name) => AiProvider.values.firstWhere((p) => p.name == name, orElse: () => AiProvider.bedrock);
}

class AiConfig {
  final AiProvider provider;

  /// Bearer token / API key sent as `Authorization: Bearer <apiKey>`.
  final String apiKey;

  /// Model or cross-region inference profile id, e.g. `eu.anthropic.claude-sonnet-4-6`.
  final String model;

  /// AWS region used to derive the default endpoint when [endpoint] is blank.
  final String region;

  /// Optional base-URL override (gateway/FIPS/VPC). When set, the Converse path
  /// `/model/<model>/converse` is appended to it.
  final String? endpoint;

  const AiConfig({
    required this.provider,
    required this.apiKey,
    required this.model,
    required this.region,
    this.endpoint,
  });

  // AppConfigs keys.
  static const keyProvider = 'AI_PROVIDER';
  static const keyApiKey = 'AI_API_KEY';
  static const keyModel = 'AI_MODEL';
  static const keyRegion = 'AI_BEDROCK_REGION';
  static const keyEndpoint = 'AI_ENDPOINT';

  static const allKeys = [keyProvider, keyApiKey, keyModel, keyRegion, keyEndpoint];

  bool get hasEndpoint => (endpoint?.trim().isNotEmpty) ?? false;

  /// True when enough is set to make a request: a key, a model, and either a
  /// region (for the default endpoint) or an explicit endpoint.
  bool get isConfigured => apiKey.trim().isNotEmpty && model.trim().isNotEmpty && (region.trim().isNotEmpty || hasEndpoint);

  /// Builds a config from a key→value map (as read from AppConfigs).
  factory AiConfig.fromMap(Map<String, String?> m) {
    final endpoint = m[keyEndpoint]?.trim();
    return AiConfig(
      provider: AiProvider.fromName(m[keyProvider]),
      apiKey: m[keyApiKey] ?? '',
      model: m[keyModel] ?? '',
      region: m[keyRegion] ?? '',
      endpoint: (endpoint?.isNotEmpty ?? false) ? endpoint : null,
    );
  }

  AiConfig copyWith({String? apiKey, String? model, String? region, String? endpoint}) => AiConfig(
    provider: provider,
    apiKey: apiKey ?? this.apiKey,
    model: model ?? this.model,
    region: region ?? this.region,
    endpoint: endpoint ?? this.endpoint,
  );
}
