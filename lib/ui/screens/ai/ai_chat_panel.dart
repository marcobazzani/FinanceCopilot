import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance_copilot/app_shell/app_navigator.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/ai/ai_chat_state.dart';
import 'package:finance_copilot/services/ai/llm_agent.dart';
import 'package:finance_copilot/services/app_actions_controller.dart';
import 'package:finance_copilot/services/providers/providers.dart';

/// Bottom-right floating AI assistant panel. Rendered by the app shell so it
/// stays open and keeps its history while the user navigates between tabs. Its
/// conversation state lives in [aiChatControllerProvider]; visibility in
/// [aiChatVisibleProvider].
class AiChatPanel extends ConsumerStatefulWidget {
  const AiChatPanel({super.key});

  @override
  ConsumerState<AiChatPanel> createState() => _AiChatPanelState();
}

class _AiChatPanelState extends ConsumerState<AiChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    ref.read(aiChatControllerProvider.notifier).send(text);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final chat = ref.watch(aiChatControllerProvider);
    final isConfigured = ref.watch(aiConfigProvider).maybeWhen(data: (c) => c.isConfigured, orElse: () => false);

    // Auto-scroll when a message is added or the sending state flips.
    ref.listen<AiChatState>(aiChatControllerProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length || prev?.sending != next.sending) {
        _scrollToBottom();
      }
    });

    final scheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 10,
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            color: scheme.surfaceContainerHighest,
            padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
            child: Row(
              children: [
                Icon(Icons.psychology_outlined, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(s.aiChatTitle, style: Theme.of(context).textTheme.titleSmall)),
                if (chat.messages.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: s.aiClearChat,
                    onPressed: () => ref.read(aiChatControllerProvider.notifier).clear(),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: s.aiCloseChat,
                  onPressed: () => ref.read(aiChatVisibleProvider.notifier).state = false,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: !isConfigured && chat.messages.isEmpty
                ? _NotConfigured(s: s)
                : chat.messages.isEmpty
                ? _EmptyHint(s: s)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: chat.messages.length + (chat.sending ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == chat.messages.length) return _ThinkingBubble(s: s);
                      return _MessageBubble(message: chat.messages[i], s: s);
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: isConfigured && !chat.sending,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: s.aiChatHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                chat.sending
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton.filled(
                        tooltip: s.aiSend,
                        onPressed: isConfigured ? _send : null,
                        icon: const Icon(Icons.send),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotConfigured extends ConsumerWidget {
  final AppStrings s;
  const _NotConfigured({required this.s});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology_outlined, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(s.aiNotConfigured, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.settings),
              label: Text(s.aiOpenSettings),
              onPressed: () async {
                // Close the floating panel so it doesn't cover the dialog, then
                // open Settings via a Navigator context (the panel floats above
                // the Navigator and has none of its own).
                ref.read(aiChatVisibleProvider.notifier).state = false;
                final reg = ref.read(globalActionsRegistryProvider);
                final navCtx = rootNavigatorKey.currentContext;
                if (reg != null && navCtx != null) await reg.showSettingsDialog(navCtx);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final AppStrings s;
  const _EmptyHint({required this.s});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          s.aiChatEmpty,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  final AppStrings s;
  const _ThinkingBubble({required this.s});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Text(s.aiThinking),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final AiChatMessage message;
  final AppStrings s;
  const _MessageBubble({required this.message, required this.s});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = message.isError
        ? scheme.errorContainer
        : message.fromUser
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final fg = message.isError
        ? scheme.onErrorContainer
        : message.fromUser
        ? scheme.onPrimaryContainer
        : scheme.onSurface;

    return Align(
      alignment: message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(message.text.isEmpty ? '—' : message.text, style: TextStyle(color: fg)),
            if (message.tools.isNotEmpty) _ToolDetails(tools: message.tools, s: s),
          ],
        ),
      ),
    );
  }
}

class _ToolDetails extends StatelessWidget {
  final List<ToolInvocation> tools;
  final AppStrings s;
  const _ToolDetails({required this.tools, required this.s});

  @override
  Widget build(BuildContext context) {
    const encoder = JsonEncoder.withIndent('  ');
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        dense: true,
        title: Text(s.aiShowSql, style: Theme.of(context).textTheme.labelMedium),
        children: [
          for (final t in tools)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _format(t, encoder),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  String _format(ToolInvocation t, JsonEncoder encoder) {
    final sql = (t.result is Map && (t.result as Map)['sql'] != null) ? (t.result as Map)['sql'] : t.input['sql'];
    final buf = StringBuffer();
    if (sql != null) buf.writeln('$sql\n');
    if (t.error != null) {
      buf.writeln('Error: ${t.error}');
    } else if (t.result is Map) {
      final m = (t.result as Map).cast<String, dynamic>();
      final count = m['rowCount'];
      if (count is int) buf.writeln(s.aiRowCount(count));
      final rows = m['rows'];
      if (rows != null) buf.write(encoder.convert(rows));
    } else if (t.result != null) {
      buf.write(encoder.convert(t.result));
    }
    return buf.toString().trim();
  }
}
