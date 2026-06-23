/// Provider-agnostic chat agent abstraction for the in-app AI assistant.
///
/// v1 ships a single implementation (Bedrock Converse). Phase 2 adds a
/// dartantic-backed implementation for OpenAI/Anthropic/Gemini/etc. behind this
/// same interface, so the UI and [AiChatService] never change.
library;

/// A tool the model may call during a turn. [run] executes it with the
/// model-supplied (already JSON-decoded) [input] and returns a JSON-encodable
/// result that is fed back to the model.
class ToolSpec {
  final String name;
  final String description;

  /// JSON Schema (an `object`) describing the tool's input.
  final Map<String, dynamic> inputSchema;
  final Future<Object?> Function(Map<String, dynamic> input) run;

  const ToolSpec({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.run,
  });
}

enum ChatRole { user, assistant }

/// A prior conversation turn passed back in for multi-turn context.
class ChatTurn {
  final ChatRole role;
  final String text;
  const ChatTurn(this.role, this.text);
}

/// One executed tool call, surfaced to the UI ("Show SQL / rows").
class ToolInvocation {
  final String name;
  final Map<String, dynamic> input;
  final Object? result;
  final String? error;
  const ToolInvocation({required this.name, required this.input, this.result, this.error});
}

/// Final result of one user turn: the natural-language answer plus the tool
/// calls the model made to produce it.
class AiAnswer {
  final String text;
  final List<ToolInvocation> toolCalls;
  const AiAnswer({required this.text, this.toolCalls = const []});
}

/// Thrown for any AI transport/provider error (network, auth, bad response).
class AiException implements Exception {
  final String message;
  final int? statusCode;
  AiException(this.message, {this.statusCode});
  @override
  String toString() => 'AiException${statusCode != null ? ' ($statusCode)' : ''}: $message';
}

/// Thrown when the AI provider is not configured (no key/model/endpoint).
class AiNotConfiguredException implements Exception {
  const AiNotConfiguredException();
  @override
  String toString() => 'AiNotConfiguredException';
}

/// Runs a single user turn, allowing the model to call [tools] (multi-step),
/// and returns the final answer plus the tool calls it made.
abstract class LlmAgent {
  Future<AiAnswer> run(
    String question, {
    required String systemPrompt,
    required List<ToolSpec> tools,
    List<ChatTurn> history = const [],
  });
}
