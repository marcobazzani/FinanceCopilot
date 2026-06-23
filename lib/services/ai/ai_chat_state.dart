import 'llm_agent.dart';

/// One rendered chat message in the assistant panel.
class AiChatMessage {
  final bool fromUser;
  final String text;
  final List<ToolInvocation> tools;
  final bool isError;

  const AiChatMessage({
    required this.fromUser,
    required this.text,
    this.tools = const [],
    this.isError = false,
  });

  factory AiChatMessage.user(String text) => AiChatMessage(fromUser: true, text: text);
  factory AiChatMessage.assistant(String text, List<ToolInvocation> tools) => AiChatMessage(fromUser: false, text: text, tools: tools);
  factory AiChatMessage.error(String text) => AiChatMessage(fromUser: false, text: text, isError: true);
}

/// Conversation state held in a Notifier so it persists across navigation and
/// while the overlay panel is hidden (in-memory only — cleared on app restart).
class AiChatState {
  final List<AiChatMessage> messages;
  final bool sending;

  const AiChatState({this.messages = const [], this.sending = false});

  AiChatState copyWith({List<AiChatMessage>? messages, bool? sending}) =>
      AiChatState(messages: messages ?? this.messages, sending: sending ?? this.sending);
}
