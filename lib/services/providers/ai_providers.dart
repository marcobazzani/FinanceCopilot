part of 'providers.dart';

// ── AI assistant providers ──

/// Active AI provider configuration, reactive from AppConfigs.
final aiConfigProvider = StreamProvider<AiConfig>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.appConfigs,
  )..where((c) => c.key.isIn(AiConfig.allKeys))).watch().map((rows) => AiConfig.fromMap({for (final r in rows) r.key: r.value}));
});

/// Dedicated read-only (`query_only`) connection used exclusively for
/// AI-generated SELECTs. Opened lazily; closed on dispose.
final readOnlyDbProvider = FutureProvider<ReadOnlyDb>((ref) async {
  final file = await AppDatabase.dbFile();
  final roDb = ReadOnlyDb.openFile(file.path);
  ref.onDispose(roDb.dispose);
  return roDb;
});

/// Chat service for the configured provider. Throws [AiNotConfiguredException]
/// until the user sets a key/model in Settings. Rebuilds when the config
/// changes.
final aiChatServiceProvider = FutureProvider<AiChatService>((ref) async {
  final config = await ref.watch(aiConfigProvider.future);
  if (!config.isConfigured) throw const AiNotConfiguredException();
  final roDb = await ref.watch(readOnlyDbProvider.future);
  final baseCurrency = await ref.watch(baseCurrencyProvider.future);
  return AiChatService(
    agent: BedrockConverseAgent(config),
    readOnlyDb: roDb,
    schemaDdl: roDb.schemaDdl(),
    baseCurrency: baseCurrency,
  );
});

/// Whether the bottom-right chat overlay is visible. Toggled from the global
/// app-bar action; the panel lives in the app shell so it persists across tabs.
final aiChatVisibleProvider = StateProvider<bool>((ref) => false);

/// Stable (English) name of the currently-selected top-level view, fed to the
/// model as navigation context. Kept in sync by the app shell.
final currentViewProvider = StateProvider<String>((ref) => 'Dashboard');

/// Extra context describing a pushed DETAIL screen (a specific pillar / account
/// / asset). Null when only a top-level tab is shown. Set and restored (LIFO)
/// by detail screens via the AiViewContextState mixin. Read by the chat
/// controller at send time only — nothing watches it, so writes never rebuild.
final aiDetailContextProvider = StateProvider<String?>((ref) => null);

/// Conversation state + send logic. A [Notifier] so history survives tab
/// navigation and hiding the panel (in-memory only — reset on app restart).
final aiChatControllerProvider = NotifierProvider<AiChatController, AiChatState>(AiChatController.new);

class AiChatController extends Notifier<AiChatState> {
  @override
  AiChatState build() => const AiChatState();

  void clear() => state = const AiChatState();

  Future<void> send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || state.sending) return;
    final s = ref.read(appStringsProvider);

    // History = the conversation so far (excluding errors), before this turn.
    final history = <ChatTurn>[
      for (final m in state.messages)
        if (!m.isError) ChatTurn(m.fromUser ? ChatRole.user : ChatRole.assistant, m.text),
    ];

    state = state.copyWith(messages: [...state.messages, AiChatMessage.user(text)], sending: true);

    try {
      final service = await ref.read(aiChatServiceProvider.future);
      final answer = await service.ask(text, history: history, contextNote: _contextNote());
      state = state.copyWith(
        messages: [...state.messages, AiChatMessage.assistant(answer.text, answer.toolCalls)],
        sending: false,
      );
    } on AiNotConfiguredException {
      state = state.copyWith(messages: [...state.messages, AiChatMessage.error(s.aiNotConfigured)], sending: false);
    } catch (e) {
      state = state.copyWith(messages: [...state.messages, AiChatMessage.error('$e')], sending: false);
    }
  }

  /// Navigation/view context the model should be aware of.
  String _contextNote() {
    final view = ref.read(currentViewProvider);
    final detail = ref.read(aiDetailContextProvider);
    final wayback = ref.read(waybackDateProvider);
    final buf = StringBuffer('The user is currently in the "$view" area.');
    // A pushed detail screen describes itself precisely; prefer it over the
    // generic top-level view description.
    if (detail != null && detail.isNotEmpty) {
      buf.write(' $detail');
    } else {
      final desc = aiViewContext(view);
      if (desc.isNotEmpty) buf.write(' $desc');
    }
    if (wayback != null) {
      buf.write(' The app is in wayback mode — figures are shown as of ${wayback.toIso8601String().substring(0, 10)}.');
    }
    return buf.toString();
  }
}
