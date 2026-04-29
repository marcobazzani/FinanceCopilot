import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/investing_com_service.dart';
import '../../services/providers/providers.dart';

/// Shared empty-state recovery affordance shown when an ISIN/ticker lookup
/// against the market data provider returns no results.
///
/// Renders an info banner explaining the situation and a TextField where the
/// user can paste a page address they found via any external search engine.
/// On a successful paste, [onResolved] is called with the resolved
/// [InvestingSearchResult]; the caller then proceeds with its existing
/// "I picked a result" flow.
///
/// Layout follows Apple Human Interface Guidelines and Material 3 empty-state
/// guidance: single illustrative icon, concise headline, plain-language
/// explanation, single primary action.
class IsinUrlPasteRecovery extends ConsumerStatefulWidget {
  /// The query the user typed in the search field. Used to suggest the
  /// search-engine query string in the explanation copy.
  final String userQuery;

  /// Cache key under which the resolved cid will be stored. Should be the
  /// asset's ISIN if available, otherwise the ticker. Read by syncPrices.
  final String cacheKey;

  /// Internal exchange code (e.g. `MIL`, `XETRA`). Used to write the cid
  /// cache row so subsequent searches short-circuit.
  final String defaultExchange;

  /// Invoked after a successful resolution.
  final void Function(InvestingSearchResult) onResolved;

  /// Outer padding around the card content.
  final EdgeInsets padding;

  const IsinUrlPasteRecovery({
    super.key,
    required this.userQuery,
    required this.cacheKey,
    required this.defaultExchange,
    required this.onResolved,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  ConsumerState<IsinUrlPasteRecovery> createState() => _IsinUrlPasteRecoveryState();
}

class _IsinUrlPasteRecoveryState extends ConsumerState<IsinUrlPasteRecovery> {
  final _ctrl = TextEditingController();
  bool _resolving = false;
  String? _urlError;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    final s = ref.read(appStringsProvider);
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _urlError = s.urlInvalidFormat);
      return;
    }
    setState(() {
      _resolving = true;
      _urlError = null;
    });
    try {
      final svc = ref.read(marketPriceServiceProvider);
      if (svc is! InvestingComService) {
        setState(() => _urlError = s.urlFetchFailed);
        return;
      }
      final r = await svc.resolveFromInstrumentUrlString(
        raw,
        cacheKey: widget.cacheKey,
        exchange: widget.defaultExchange,
      );
      if (!mounted) return;
      switch (r) {
        case UrlResolveOk(:final result):
          widget.onResolved(result);
        case UrlResolveInvalidFormat():
          setState(() => _urlError = s.urlInvalidFormat);
        case UrlResolveWrongHost():
          setState(() => _urlError = s.urlWrongHost);
        case UrlResolveUnsupportedCategory():
          setState(() => _urlError = s.urlUnsupportedCategory);
        case UrlResolveFetchFailed():
          setState(() => _urlError = s.urlFetchFailed);
        case UrlResolveParseFailed():
          setState(() => _urlError = s.urlParseFailed);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _urlError = s.urlFetchFailed);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      key: const Key('instrumentNotFoundCard'),
      color: cs.surfaceContainerHighest,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: widget.padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.search_off_outlined, size: 28, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.instrumentNotFoundHeadline,
                    key: const Key('instrumentNotFoundHeadline'),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              s.instrumentNotFoundExplanation(widget.userQuery),
              key: const Key('instrumentNotFoundExplanation'),
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('pasteUrlField'),
              controller: _ctrl,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: s.pasteInstrumentUrlLabel,
                hintText: 'https://www.investing.com/...',
                prefixIcon: const Icon(Icons.link),
                errorText: _urlError,
              ),
              onChanged: (_) {
                if (_urlError != null) setState(() => _urlError = null);
              },
              onSubmitted: (_) => _resolve(),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_resolving) ...[
                  const SizedBox(
                    height: 16, width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                ],
                FilledButton.icon(
                  key: const Key('verifyUrlButton'),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(s.verifyButton),
                  onPressed: _resolving ? null : _resolve,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
